"""
IP Integration Evaluator for RTL-Gen-Sec Benchmark.
"""

import subprocess
import re
import json
from pathlib import Path
from typing import Dict, Any, List, Tuple

from scripts.metrics import MetricsCalculator


class IPIntegrateEvaluator:
    """Evaluator for IP integration tasks."""
    
    def __init__(self, problem_path: Path):
        self.problem_path = Path(problem_path)
        self.golden_ips_path = self.problem_path / "golden_ips"
        self.testbenches_path = self.problem_path / "testbenches"
        self.metrics_calc = MetricsCalculator()
    
    def evaluate(self, code: str, scenario_config: Dict, output_dir: Path) -> Dict[str, Any]:
        """Evaluate generated wrapper for IP integration."""
        
        results = {
            "metrics": {},
            "compilation": {},
            "simulation": {},
            "synthesis": {},
            "passed": False
        }
        
        # Save generated code
        wrapper_file = output_dir / "wrapper.v"
        wrapper_file.write_text(code)
        
        # Compile with golden IPs
        compile_success, compile_log = self._compile_wrapper(code, scenario_config, output_dir)
        results["compilation"] = {"success": compile_success, "log": compile_log}
        
        if not compile_success:
            results["metrics"]["INTEG-PASS"] = False
            return results
        
        # Run simulation
        sim_success, sim_metrics, sim_log = self._run_simulation(scenario_config, output_dir)
        results["simulation"] = {"success": sim_success, "log": sim_log, "metrics": sim_metrics}
        
        # Run synthesis
        synth_results = self._run_synthesis(code, scenario_config, output_dir)
        results["synthesis"] = synth_results
        
        # Calculate metrics
        results["metrics"]["INTEG-PASS"] = sim_success
        results["metrics"]["LATENCY-OVERHEAD"] = sim_metrics.get("arbitration_latency", 0)
        results["metrics"]["FAIRNESS-SCORE"] = sim_metrics.get("fairness_score", 0.0)
        results["metrics"]["AREA-EFF"] = self._calculate_area_efficiency(synth_results)
        
        # Check pass condition
        results["passed"] = self._evaluate_pass_condition(results, scenario_config)
        
        # Save report
        with open(output_dir / "integration_report.json", 'w') as f:
            json.dump(results, f, indent=2)
        
        return results
    
    def _compile_wrapper(self, code: str, config: Dict, output_dir: Path) -> Tuple[bool, str]:
        """Compile wrapper with golden IPs using Verilator."""
        
        wrapper_file = output_dir / "wrapper.v"
        wrapper_file.write_text(code)
        
        verilog_files = [str(wrapper_file)]
        
        # Add golden IPs
        for ip in config.get("golden_ips", []):
            ip_file = self.golden_ips_path / ip["file"]
            if ip_file.exists():
                verilog_files.append(str(ip_file))
        
        cmd = ["verilator", "--lint-only", "-Wall", "--Wno-DECLFILENAME"]
        cmd.extend(verilog_files)
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            success = result.returncode == 0
            return success, result.stdout + result.stderr
        except subprocess.TimeoutExpired:
            return False, "Compilation timeout"
        except Exception as e:
            return False, str(e)
    
    def _run_simulation(self, config: Dict, output_dir: Path) -> Tuple[bool, Dict, str]:
        """Run testbench simulation."""
        
        tb_file = self.testbenches_path / config.get("testbench", "tb_axi_arbiter.sv")
        
        if not tb_file.exists():
            return False, {}, "Testbench not found"
        
        vvp_file = output_dir / "sim.vvp"
        
        # Compile simulation
        compile_cmd = [
            "iverilog", "-g2012", "-o", str(vvp_file),
            str(tb_file), str(output_dir / "wrapper.v")
        ]
        
        # Add golden IPs
        for ip in config.get("golden_ips", []):
            ip_file = self.golden_ips_path / ip["file"]
            if ip_file.exists():
                compile_cmd.append(str(ip_file))
        
        try:
            subprocess.run(compile_cmd, capture_output=True, text=True, timeout=30, check=True)
            sim_result = subprocess.run(["vvp", str(vvp_file)], capture_output=True, text=True, timeout=60)
            
            metrics = self._parse_simulation_output(sim_result.stdout)
            success = metrics.get("test_passed", False)
            
            return success, metrics, sim_result.stdout + sim_result.stderr
            
        except Exception as e:
            return False, {}, str(e)
    
    def _parse_simulation_output(self, output: str) -> Dict[str, Any]:
        """Parse testbench output for metrics."""
        
        metrics = {
            "test_passed": False,
            "arbitration_latency": 0,
            "fairness_score": 0.0,
            "packets_transmitted": 0
        }
        
        if "TEST PASSED" in output:
            metrics["test_passed"] = True
        
        # Parse latency
        latency_match = re.search(r'Average arbitration latency:\s*(\d+)', output)
        if latency_match:
            metrics["arbitration_latency"] = int(latency_match.group(1))
        
        # Parse fairness
        fairness_match = re.search(r'Fairness score:\s*([\d.]+)', output)
        if fairness_match:
            metrics["fairness_score"] = float(fairness_match.group(1))
        
        # Parse packet count
        packet_match = re.search(r'Packets transmitted:\s*(\d+)', output)
        if packet_match:
            metrics["packets_transmitted"] = int(packet_match.group(1))
        
        return metrics
    
    def _run_synthesis(self, code: str, config: Dict, output_dir: Path) -> Dict[str, Any]:
        """Run Yosys synthesis for area estimation."""
        
        code_file = output_dir / "wrapper.v"
        synth_script = output_dir / "synth.ys"
        
        script = f"""
read_verilog {code_file}
hierarchy -top {config.get('top_module', 'axi_arbiter_wrapper')}
proc
opt
techmap
opt
stat
"""
        synth_script.write_text(script)
        
        try:
            result = subprocess.run(["yosys", "-q", str(synth_script)], 
                                   capture_output=True, text=True, timeout=60)
            
            cell_match = re.search(r'Number of cells:\s*(\d+)', result.stdout + result.stderr)
            cell_count = int(cell_match.group(1)) if cell_match else 0
            
            return {"success": result.returncode == 0, "cell_count": cell_count}
            
        except Exception as e:
            return {"success": False, "cell_count": 0}
    
    def _calculate_area_efficiency(self, synth_results: Dict) -> float:
        """Calculate area efficiency score."""
        if not synth_results.get("success", False):
            return 0.0
        
        cell_count = synth_results.get("cell_count", 0)
        if cell_count == 0:
            return 0.0
        
        # Normalized score: 100 cells is baseline
        baseline_cells = 100
        return min(1.0, baseline_cells / cell_count) if cell_count > baseline_cells else 1.0
    
    def _evaluate_pass_condition(self, results: Dict, config: Dict) -> bool:
        """Evaluate pass condition from config."""
        
        integ_pass = results["metrics"].get("INTEG-PASS", False)
        fairness = results["metrics"].get("FAIRNESS-SCORE", 0.0)
        
        condition = config.get("evaluation", {}).get("pass_condition", "")
        
        if "FAIRNESS-SCORE >= 0.9" in condition:
            return integ_pass and fairness >= 0.9
        
        return integ_pass