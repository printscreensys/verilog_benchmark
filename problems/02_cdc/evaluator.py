"""
CDC (Clock Domain Crossing) Evaluator for RTL-Gen-Sec Benchmark.
"""

import re
import subprocess
import json
from pathlib import Path
from typing import Dict, Any, List, Tuple, Optional

from scripts.metrics import MetricsCalculator


class CDCEvaluator:
    """Evaluator for clock domain crossing tasks."""
    
    def __init__(self, problem_path: Path):
        self.problem_path = Path(problem_path)
        self.tools_path = self.problem_path / "tools"
        self.metrics_calc = MetricsCalculator()
    
    def evaluate(self, code: str, scenario_config: Dict, output_dir: Path) -> Dict[str, Any]:
        """
        Evaluate generated CDC synchronizer.
        
        Returns:
            Dict with CDC-SAFE, BUS-SYNC-SCORE, DIVERGENCE-FREE metrics.
        """
        results = {
            "metrics": {},
            "cdc_checks": {},
            "synthesis": {},
            "violations": [],
            "passed": False
        }
        
        # 1. Compilation check
        compile_success, compile_log = self.metrics_calc.compile_verilog(
            code,
            scenario_config.get("top_module", "cdc_single_bit_sync")
        )
        results["compilation"] = {"success": compile_success, "log": compile_log}
        
        if not compile_success:
            results["metrics"]["CDC-SAFE"] = False
            results["passed"] = False
            return results
        
        # 2. CDC static checks
        cdc_checks = self._run_cdc_static_checks(code, scenario_config)
        results["cdc_checks"] = cdc_checks
        
        # 3. Yosys-based synchronizer detection
        synth_check = self._check_synchronizer_synthesis(code, scenario_config, output_dir)
        results["synthesis"] = synth_check
        
        # 4. Calculate metrics
        results["metrics"]["CDC-SAFE"] = self._calculate_cdc_safe(results)
        results["metrics"]["BUS-SYNC-SCORE"] = 1.0  # Single-bit case
        results["metrics"]["DIVERGENCE-FREE"] = self._check_divergence_free(code)
        
        # 5. Overall pass/fail
        expected_checks = scenario_config.get("cdc_checks", [])
        results["passed"] = self._evaluate_pass(results, expected_checks)
        
        # Save report
        with open(output_dir / "cdc_report.json", 'w') as f:
            json.dump(results, f, indent=2)
        
        return results
    
    def _run_cdc_static_checks(self, code: str, config: Dict) -> Dict[str, Any]:
        """Run static CDC analysis checks."""
        checks = {
            "sync_stages_check": {"passed": False, "details": ""},
            "no_combinational_check": {"passed": False, "details": ""},
            "attributes_check": {"passed": False, "details": ""},
            "reset_check": {"passed": False, "details": ""}
        }
        
        # Check 1: Number of synchronization stages
        sync_stages = self._count_sync_stages(code)
        min_stages = config.get("variables", {}).get("sync_stages", 2)
        
        if sync_stages >= min_stages:
            checks["sync_stages_check"]["passed"] = True
            checks["sync_stages_check"]["details"] = f"Found {sync_stages} sync stages"
        else:
            checks["sync_stages_check"]["details"] = f"Only {sync_stages} sync stages found, need {min_stages}"
            results["violations"].append({
                "type": "insufficient_sync_stages",
                "found": sync_stages,
                "required": min_stages
            })
        
        # Check 2: No combinational logic between flops
        has_combinational = self._has_combinational_between_flops(code)
        checks["no_combinational_check"]["passed"] = not has_combinational
        checks["no_combinational_check"]["details"] = "No combinational logic found" if not has_combinational else "Combinational logic detected between sync flops"
        
        if has_combinational:
            results["violations"].append({
                "type": "combinational_in_sync_chain",
                "description": "Combinational logic between synchronizer stages"
            })
        
        # Check 3: Synthesis attributes present
        has_attributes = self._has_synthesis_attributes(code)
        checks["attributes_check"]["passed"] = has_attributes
        checks["attributes_check"]["details"] = "ASYNC_REG attribute found" if has_attributes else "Missing ASYNC_REG attribute"
        
        # Check 4: Proper reset handling
        has_reset = self._has_proper_reset(code)
        checks["reset_check"]["passed"] = has_reset
        checks["reset_check"]["details"] = "Proper reset handling found" if has_reset else "Missing or improper reset"
        
        return checks
    
    def _count_sync_stages(self, code: str) -> int:
        """Count number of flip-flop stages in synchronizer."""
        # Look for shift register pattern
        shift_pattern = r'sync_reg\s*<=\s*\{[^,]+,\s*signal_in\s*\}'
        if re.search(shift_pattern, code):
            # Extract width from declaration
            width_match = re.search(r'(?:logic|reg)\s*\[(\d+):0\]\s*sync_reg', code)
            if width_match:
                return int(width_match.group(1)) + 1
        
        # Alternative: count individual flops
        flop_count = len(re.findall(r'always_ff.*posedge.*signal_in', code, re.DOTALL))
        return max(1, flop_count)
    
    def _has_combinational_between_flops(self, code: str) -> bool:
        """Check for combinational logic between synchronizer flops."""
        # Look for assign statements or gates between flop outputs and inputs
        sync_assign = re.search(r'assign\s+sync_reg.*=', code)
        if sync_assign:
            return True
        
        # Look for combinational always blocks affecting sync_reg
        comb_always = re.search(r'always_\w*\s*@\s*\(\s*\*\s*\).*sync_reg', code, re.DOTALL)
        if comb_always:
            return True
        
        return False
    
    def _has_synthesis_attributes(self, code: str) -> bool:
        """Check for ASYNC_REG or equivalent synthesis attributes."""
        patterns = [
            r'\(\*\s*ASYNC_REG\s*=\s*"TRUE"\s*\*\)',
            r'\(\*\s*async_reg\s*=\s*"true"\s*\*\)',
            r'//\s*synthesis\s+attribute\s+ASYNC_REG',
            r'`ifdef\s+SYNTHESIS.*ASYNC_REG'
        ]
        
        for pattern in patterns:
            if re.search(pattern, code, re.IGNORECASE):
                return True
        
        return False
    
    def _has_proper_reset(self, code: str) -> bool:
        """Check for proper reset handling in synchronizer."""
        # Check for asynchronous reset in sensitivity list
        has_async_reset = re.search(r'always_ff\s*@\s*\(\s*posedge\s+\w+\s+or\s+negedge', code)
        
        # Check for reset condition
        has_reset_condition = re.search(r'if\s*\(\s*!\s*rst', code)
        
        return has_async_reset and has_reset_condition
    
    def _check_synchronizer_synthesis(self, code: str, config: Dict, output_dir: Path) -> Dict[str, Any]:
        """Run Yosys synthesis to verify synchronizer structure."""
        
        # Write code to file
        code_file = output_dir / "cdc_module.v"
        code_file.write_text(code)
        
        # Create synthesis script
        synth_script = output_dir / "cdc_synth.ys"
        top_module = config.get("top_module", "cdc_single_bit_sync")
        
        script = f"""
read_verilog {code_file}
hierarchy -top {top_module}
proc
opt
techmap
opt

# Check for flip-flops
select -list t:*_DFF* %i
select -count cdc_ffs
echo "CDC_FF_COUNT: %d"

# Check for direct connections (should be minimal)
select -list w:* %i
"""
        synth_script.write_text(script)
        
        try:
            result = subprocess.run(
                ["yosys", "-q", str(synth_script)],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=output_dir
            )
            
            # Parse FF count
            ff_match = re.search(r'CDC_FF_COUNT:\s*(\d+)', result.stdout + result.stderr)
            ff_count = int(ff_match.group(1)) if ff_match else 0
            
            return {
                "success": result.returncode == 0,
                "ff_count": ff_count,
                "has_synchronizer": ff_count >= 2,
                "log": result.stdout + result.stderr
            }
            
        except Exception as e:
            return {
                "success": False,
                "ff_count": 0,
                "has_synchronizer": False,
                "log": str(e)
            }
    
    def _check_divergence_free(self, code: str) -> bool:
        """Check for reconvergence divergence issues."""
        # Look for sync_reg output fanning out to multiple destinations
        # before reaching the final synchronized signal
        
        # Simple heuristic: check if output is assigned directly from last flop
        direct_output = re.search(r'assign\s+signal_out\s*=\s*sync_reg\[\w+\]', code)
        
        if not direct_output:
            # Check for buffered output
            buffered = re.search(r'always_ff.*signal_out\s*<=\s*sync_reg', code, re.DOTALL)
            return buffered is not None
        
        return True
    
    def _calculate_cdc_safe(self, results: Dict) -> bool:
        """Calculate overall CDC safety metric."""
        checks = results.get("cdc_checks", {})
        synthesis = results.get("synthesis", {})
        
        # All checks must pass
        sync_stages_ok = checks.get("sync_stages_check", {}).get("passed", False)
        no_combo_ok = checks.get("no_combinational_check", {}).get("passed", False)
        synth_ok = synthesis.get("has_synchronizer", False)
        
        return sync_stages_ok and no_combo_ok and synth_ok
    
    def _evaluate_pass(self, results: Dict, expected_checks: List[Dict]) -> bool:
        """Evaluate overall pass/fail based on expected checks."""
        if not results.get("compilation", {}).get("success", False):
            return False
        
        # All expected CDC checks must pass
        for check in expected_checks:
            metric = check.get("metric", "")
            if metric == "CDC-SAFE":
                if not results["metrics"].get("CDC-SAFE", False):
                    return False
        
        return results["metrics"].get("CDC-SAFE", False)