"""
Low-Power Design Evaluator for RTL-Gen-Sec Benchmark.
"""

import re
import subprocess
import json
from pathlib import Path
from typing import Dict, Any, List, Tuple

from scripts.metrics import MetricsCalculator


class LowPowerEvaluator:
    """Evaluator for low-power design constructs."""
    
    def __init__(self, problem_path: Path):
        self.problem_path = Path(problem_path)
        self.tools_path = self.problem_path / "tools"
        self.metrics_calc = MetricsCalculator()
    
    def evaluate(self, code: str, scenario_config: Dict, output_dir: Path) -> Dict[str, Any]:
        """
        Evaluate generated RTL for low-power constructs.
        
        Returns:
            Dict with CLK-GATE-EXISTS, ISO-STRATEGY, RETENTION-EXISTS metrics.
        """
        results = {
            "metrics": {},
            "power_checks": {},
            "synthesis": {},
            "upf_awareness": {},
            "passed": False
        }
        
        # 1. Compilation check
        compile_success, compile_log = self.metrics_calc.compile_verilog(
            code,
            scenario_config.get("top_module", "lp_register_file")
        )
        results["compilation"] = {"success": compile_success, "log": compile_log}
        
        if not compile_success:
            results["metrics"]["CLK-GATE-EXISTS"] = False
            results["passed"] = False
            return results
        
        # 2. Static analysis for power constructs
        power_checks = self._run_power_static_checks(code, scenario_config)
        results["power_checks"] = power_checks
        
        # 3. Synthesis to verify clock gating inference
        synth_check = self._check_clock_gating_synthesis(code, scenario_config, output_dir)
        results["synthesis"] = synth_check
        
        # 4. UPF/CPF awareness check
        upf_check = self._check_upf_awareness(code)
        results["upf_awareness"] = upf_check
        
        # 5. Calculate metrics
        results["metrics"]["CLK-GATE-EXISTS"] = self._calculate_clk_gate_exists(results)
        results["metrics"]["ISO-STRATEGY"] = power_checks.get("isolation_present", False)
        results["metrics"]["RETENTION-EXISTS"] = power_checks.get("retention_present", False)
        
        # 6. Overall pass/fail
        results["passed"] = self._evaluate_pass(results, scenario_config)
        
        # Save report
        with open(output_dir / "low_power_report.json", 'w') as f:
            json.dump(results, f, indent=2)
        
        return results
    
    def _run_power_static_checks(self, code: str, config: Dict) -> Dict[str, Any]:
        """Run static analysis for low-power constructs."""
        checks = {
            "clock_gating_logic": {"passed": False, "details": ""},
            "gated_always_block": {"passed": False, "details": ""},
            "isolation_present": False,
            "retention_present": False,
            "power_domain_comments": False
        }
        
        # Check 1: Clock gating enable logic
        gating_logic = re.search(r'(?:gated_clk_en|clock_gate_en|clk_enable)\s*=\s*\w+\s*&&\s*\w+', code)
        gating_comb = re.search(r'always_comb.*gated.*en', code, re.DOTALL | re.IGNORECASE)
        
        if gating_logic or gating_comb:
            checks["clock_gating_logic"]["passed"] = True
            checks["clock_gating_logic"]["details"] = "Clock gating enable logic found"
        else:
            checks["clock_gating_logic"]["details"] = "No explicit clock gating enable logic"
        
        # Check 2: Gated always_ff block
        gated_always = re.search(
            r'always_ff\s*@.*if\s*\(\s*\w+\s*\)\s*begin',
            code,
            re.DOTALL
        )
        
        if gated_always:
            # Check if it's the write logic being gated
            if 'wr_en' in gated_always.group(0) or 'gated' in gated_always.group(0).lower():
                checks["gated_always_block"]["passed"] = True
                checks["gated_always_block"]["details"] = "Gated sequential block found"
        
        # Check 3: Isolation strategy comments
        isolation_patterns = [
            r'//.*isolation',
            r'/[*].*isolation.*[*]/',
            r'UPF.*isolation',
            r'power.*domain.*isolate'
        ]
        
        for pattern in isolation_patterns:
            if re.search(pattern, code, re.IGNORECASE):
                checks["isolation_present"] = True
                break
        
        # Check 4: Retention strategy comments
        retention_patterns = [
            r'//.*retention',
            r'/[*].*retention.*[*]/',
            r'UPF.*retention',
            r'save.*restore',
            r'retention.*flop'
        ]
        
        for pattern in retention_patterns:
            if re.search(pattern, code, re.IGNORECASE):
                checks["retention_present"] = True
                break
        
        # Check 5: Power domain awareness
        power_patterns = [
            r'UPF',
            r'CPF',
            r'power\s+domain',
            r'PD_\w+'
        ]
        
        for pattern in power_patterns:
            if re.search(pattern, code, re.IGNORECASE):
                checks["power_domain_comments"] = True
                break
        
        return checks
    
    def _check_clock_gating_synthesis(self, code: str, config: Dict, output_dir: Path) -> Dict[str, Any]:
        """Run synthesis to verify clock gating cell inference."""
        
        # Write code to file
        code_file = output_dir / "lp_module.v"
        code_file.write_text(code)
        
        # Create synthesis script for clock gating detection
        synth_script = output_dir / "lp_synth.ys"
        top_module = config.get("top_module", "lp_register_file")
        
        # Script to check for clock gating cells
        script = f"""
read_verilog {code_file}
hierarchy -top {top_module}
proc
opt

# Map to generic library
techmap

# Check for clock gating cells (latches used as clock gates)
select -list t:$_DLATCH_* %i
select -count cg_cells
echo "CG_CELL_COUNT: %d"

# Check for enabled flip-flops
select -list t:$_DFF_* %i
select -count ff_cells
echo "FF_CELL_COUNT: %d"

# Report
stat
"""
        synth_script.write_text(script)
        
        try:
            result = subprocess.run(
                ["yosys", "-q", str(synth_script)],
                capture_output=True,
                text=True,
                timeout=60,
                cwd=output_dir
            )
            
            # Parse results
            cg_match = re.search(r'CG_CELL_COUNT:\s*(\d+)', result.stdout + result.stderr)
            cg_count = int(cg_match.group(1)) if cg_match else 0
            
            ff_match = re.search(r'FF_CELL_COUNT:\s*(\d+)', result.stdout + result.stderr)
            ff_count = int(ff_match.group(1)) if ff_match else 0
            
            # Also check for gated clock enable pattern in netlist
            has_clock_gate = cg_count > 0
            
            # Alternative: check if flops have enable pins
            enabled_ffs = '$_DFFE_' in (result.stdout + result.stderr)
            
            return {
                "success": result.returncode == 0,
                "cg_cell_count": cg_count,
                "ff_cell_count": ff_count,
                "clock_gate_inferred": has_clock_gate or enabled_ffs,
                "log": result.stdout + result.stderr
            }
            
        except Exception as e:
            return {
                "success": False,
                "cg_cell_count": 0,
                "ff_cell_count": 0,
                "clock_gate_inferred": False,
                "log": str(e)
            }
    
    def _check_upf_awareness(self, code: str) -> Dict[str, Any]:
        """Check for UPF/CPF awareness indicators."""
        awareness = {
            "upf_mentions": False,
            "power_domains": [],
            "isolation_mentioned": False,
            "retention_mentioned": False,
            "level_shifter_mentioned": False,
            "score": 0.0
        }
        
        # Count UPF/CPF mentions
        upf_count = len(re.findall(r'UPF|CPF|IEEE\s*1801', code, re.IGNORECASE))
        awareness["upf_mentions"] = upf_count > 0
        
        # Extract power domain names
        pd_matches = re.findall(r'PD_(\w+)', code, re.IGNORECASE)
        awareness["power_domains"] = list(set(pd_matches))
        
        # Check for specific power intent keywords
        awareness["isolation_mentioned"] = bool(re.search(r'isolation|isolate', code, re.IGNORECASE))
        awareness["retention_mentioned"] = bool(re.search(r'retention|retain', code, re.IGNORECASE))
        awareness["level_shifter_mentioned"] = bool(re.search(r'level\s*shift', code, re.IGNORECASE))
        
        # Calculate awareness score (0-1)
        score = 0.0
        if awareness["upf_mentions"]:
            score += 0.4
        if awareness["isolation_mentioned"]:
            score += 0.2
        if awareness["retention_mentioned"]:
            score += 0.2
        if awareness["level_shifter_mentioned"]:
            score += 0.1
        if len(awareness["power_domains"]) > 0:
            score += 0.1
        
        awareness["score"] = min(1.0, score)
        
        return awareness
    
    def _calculate_clk_gate_exists(self, results: Dict) -> bool:
        """Determine if clock gating exists in the design."""
        power_checks = results.get("power_checks", {})
        synthesis = results.get("synthesis", {})
        
        # Check from static analysis
        static_gating = (power_checks.get("clock_gating_logic", {}).get("passed", False) and
                        power_checks.get("gated_always_block", {}).get("passed", False))
        
        # Check from synthesis
        synth_gating = synthesis.get("clock_gate_inferred", False)
        
        # Consider it present if either check passes
        return static_gating or synth_gating
    
    def _evaluate_pass(self, results: Dict, config: Dict) -> bool:
        """Evaluate overall pass/fail based on required features."""
        if not results.get("compilation", {}).get("success", False):
            return False
        
        power_checks = results.get("power_checks", {})
        
        # Primary requirement: clock gating must exist
        if not results["metrics"].get("CLK-GATE-EXISTS", False):
            return False
        
        # Check expected features from config
        expected_features = config.get("expected_features", [])
        
        for feature in expected_features:
            if "Clock gating" in feature:
                if not results["metrics"].get("CLK-GATE-EXISTS", False):
                    return False
            elif "UPF" in feature or "CPF" in feature:
                awareness = results.get("upf_awareness", {})
                if awareness.get("score", 0) < 0.3:
                    return False
        
        return True