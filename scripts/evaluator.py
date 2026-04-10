#!/usr/bin/env python3
"""
Main benchmark evaluation orchestrator.
"""

import os
import sys
import json
import time
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed

import yaml
from tqdm import tqdm
from colorama import init, Fore, Style

from .llm_client import LLMClient, OfflineClient
from .metrics import MetricsCalculator
from .report_generator import ReportGenerator

# Initialize colorama for cross-platform colored output
init(autoreset=True)


class BenchmarkEvaluator:
    """Main evaluation orchestrator."""
    
    PROBLEM_CATEGORIES = ["security", "ip_integrate", "cdc", "low_power"]
    
    def __init__(self, 
                 config_path: str = "config/benchmark_config.yaml",
                 models_config_path: str = "config/models.yaml"):
        
        self.config = self._load_yaml(config_path)
        self.models_config = self._load_yaml(models_config_path)
        self.llm_client = LLMClient(models_config_path)
        self.metrics_calc = MetricsCalculator()
        self.report_gen = ReportGenerator()
        
        self.problems_dir = Path("problems")
        self.results_dir = Path("results")
        
        # Load problem evaluators dynamically
        self.evaluators = {}
        self._load_evaluators()
    
    def _load_yaml(self, path: str) -> Dict:
        with open(path, 'r') as f:
            return yaml.safe_load(f)
    
    def _load_evaluators(self):
        """Dynamically import problem-specific evaluators."""
        for category in self.PROBLEM_CATEGORIES:
            evaluator_path = self.problems_dir / category / "evaluator.py"
            if evaluator_path.exists():
                # In practice, use importlib to load module
                # For now, create a dummy placeholder
                self.evaluators[category] = None
                print(f"{Fore.YELLOW}Warning: {category} evaluator not yet implemented")
    
    def run_evaluation(self,
                       model_name: str,
                       problems: List[str],
                       scenarios: Optional[List[str]] = None,
                       num_samples: int = 1) -> Dict[str, Any]:
        """
        Run full evaluation for specified model and problems.
        
        Args:
            model_name: Name of model from config/models.yaml
            problems: List of problem categories to evaluate
            scenarios: Specific scenarios to run (default: all)
            num_samples: Number of samples per prompt (for pass@k)
        
        Returns:
            Full results dictionary
        """
        # Create results directory
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        model_safe_name = model_name.replace("/", "_")
        run_dir = self.results_dir / f"{model_safe_name}_{timestamp}"
        run_dir.mkdir(parents=True, exist_ok=True)
        
        print(f"{Fore.CYAN}=== RTL-Gen-Sec Benchmark ===")
        print(f"Model: {model_name}")
        print(f"Problems: {', '.join(problems)}")
        print(f"Samples per prompt: {num_samples}")
        print(f"Results directory: {run_dir}")
        print()
        
        all_results = {
            "metadata": {
                "model": model_name,
                "timestamp": timestamp,
                "num_samples": num_samples,
                "config": self.config
            },
            "problems": {}
        }
        
        # Check if using offline mode
        is_offline = model_name.startswith("offline/")
        if is_offline:
            for m in self.models_config.get("models", []):
                if m["name"] == model_name:
                    self.llm_client = OfflineClient(m.get("input_dir", "pre_generated_outputs/"))
                    break
        
        # Evaluate each problem category
        for problem in problems:
            if problem not in self.PROBLEM_CATEGORIES:
                print(f"{Fore.RED}Unknown problem category: {problem}")
                continue
            
            print(f"{Fore.GREEN}Evaluating: {problem}")
            problem_dir = self.problems_dir / problem
            problem_run_dir = run_dir / problem
            problem_run_dir.mkdir(exist_ok=True)
            
            # Load problem prompts/scenarios
            prompts_dir = problem_dir / "prompts" / "scenarios"
            if not prompts_dir.exists():
                print(f"{Fore.RED}  No scenarios found for {problem}")
                continue
            
            scenario_files = list(prompts_dir.glob("*.yaml"))
            if scenarios:
                scenario_files = [f for f in scenario_files if f.stem in scenarios]
            
            problem_results = []
            
            for scenario_file in tqdm(scenario_files, desc=f"  Scenarios"):
                scenario_name = scenario_file.stem
                scenario_config = self._load_yaml(scenario_file)
                
                scenario_dir = problem_run_dir / scenario_name
                scenario_dir.mkdir(exist_ok=True)
                
                # Generate prompt from template
                prompt = self._generate_prompt(problem, scenario_config)
                
                # Collect multiple samples
                samples = []
                for sample_idx in range(num_samples):
                    sample_result = self._evaluate_single_sample(
                        problem=problem,
                        model_name=model_name,
                        prompt=prompt,
                        scenario_config=scenario_config,
                        output_dir=scenario_dir,
                        sample_idx=sample_idx
                    )
                    samples.append(sample_result)
                
                # Aggregate samples
                aggregated = self._aggregate_samples(samples, scenario_config)
                aggregated["scenario"] = scenario_name
                problem_results.append(aggregated)
                
                # Save scenario results
                with open(scenario_dir / "results.json", 'w') as f:
                    json.dump(aggregated, f, indent=2)
            
            # Save problem-level summary
            all_results["problems"][problem] = {
                "scenarios": problem_results,
                "summary": self._calculate_problem_summary(problem_results)
            }
            
            with open(problem_run_dir / "summary.json", 'w') as f:
                json.dump(all_results["problems"][problem], f, indent=2)
        
        # Generate overall summary
        all_results["overall"] = self._calculate_overall_summary(all_results["problems"])
        
        with open(run_dir / "summary.json", 'w') as f:
            json.dump(all_results, f, indent=2)
        
        # Generate HTML report
        self.report_gen.generate_html_report(all_results, run_dir / "report.html")
        
        # Print summary
        self._print_summary(all_results)
        
        return all_results
    
    def _generate_prompt(self, problem: str, scenario_config: Dict) -> str:
        """Generate prompt from scenario configuration."""
        # This should use Jinja2 templating in production
        # For now, return a simple concatenation
        template = scenario_config.get("prompt_template", "")
        
        # Basic variable substitution
        for key, value in scenario_config.get("variables", {}).items():
            template = template.replace(f"{{{{{key}}}}}", str(value))
        
        return template
    
    def _evaluate_single_sample(self,
                                problem: str,
                                model_name: str,
                                prompt: str,
                                scenario_config: Dict,
                                output_dir: Path,
                                sample_idx: int) -> Dict[str, Any]:
        """Evaluate a single sample from the LLM."""
        
        sample_dir = output_dir / f"sample_{sample_idx}"
        sample_dir.mkdir(exist_ok=True)
        
        # Call LLM
        system_prompt = scenario_config.get("system_prompt", 
            "You are an expert RTL designer. Generate only valid SystemVerilog code.")
        
        llm_response = self.llm_client.generate(
            model_name=model_name,
            prompt=prompt,
            system_prompt=system_prompt,
            temperature=scenario_config.get("temperature", 0.1)
        )
        
        # Extract Verilog code
        verilog_code = ""
        if llm_response.get("response"):
            verilog_code = self.metrics_calc.extract_verilog_from_response(llm_response["response"])
        
        # Save LLM output
        with open(sample_dir / "prompt.txt", 'w') as f:
            f.write(prompt)
        with open(sample_dir / "response_raw.txt", 'w') as f:
            f.write(llm_response.get("response", ""))
        with open(sample_dir / "generated.v", 'w') as f:
            f.write(verilog_code)
        
        # Run problem-specific evaluation
        metrics = {}
        
        if problem == "security":
            metrics = self._evaluate_security(verilog_code, scenario_config, sample_dir)
        elif problem == "ip_integrate":
            metrics = self._evaluate_ip_integrate(verilog_code, scenario_config, sample_dir)
        elif problem == "cdc":
            metrics = self._evaluate_cdc(verilog_code, scenario_config, sample_dir)
        elif problem == "low_power":
            metrics = self._evaluate_low_power(verilog_code, scenario_config, sample_dir)
        
        # Compilation check (common to all)
        compile_success, compile_log = self.metrics_calc.compile_verilog(
            verilog_code, 
            scenario_config.get("top_module", "top")
        )
        metrics["compilation_pass"] = compile_success
        
        with open(sample_dir / "compile.log", 'w') as f:
            f.write(compile_log)
        
        result = {
            "sample_idx": sample_idx,
            "llm_response": {
                "latency_ms": llm_response.get("latency_ms"),
                "usage": llm_response.get("usage"),
                "error": llm_response.get("error")
            },
            "metrics": metrics,
            "passed": metrics.get("passed", False)
        }
        
        with open(sample_dir / "metrics.json", 'w') as f:
            json.dump(result, f, indent=2)
        
        return result
    
    def _evaluate_security(self, code: str, config: Dict, output_dir: Path) -> Dict:
        """Security vulnerability evaluation (placeholder)."""
        # Actual implementation would call cwe_detector.py
        return {"passed": True, "vulnerabilities": []}
    
    def _evaluate_ip_integrate(self, code: str, config: Dict, output_dir: Path) -> Dict:
        """IP integration evaluation (placeholder)."""
        return {"passed": True, "latency_overhead": 0}
    
    def _evaluate_cdc(self, code: str, config: Dict, output_dir: Path) -> Dict:
        """CDC evaluation (placeholder)."""
        return {"passed": True, "sync_stages": 2}
    
    def _evaluate_low_power(self, code: str, config: Dict, output_dir: Path) -> Dict:
        """Low-power evaluation (placeholder)."""
        return {"passed": True, "clk_gate_inferred": False}
    
    def _aggregate_samples(self, samples: List[Dict], config: Dict) -> Dict:
        """Aggregate multiple samples for pass@k calculation."""
        passes = [s["passed"] for s in samples]
        
        aggregated = {
            "num_samples": len(samples),
            "pass_count": sum(passes),
            "pass_rate": sum(passes) / len(samples) if samples else 0,
            "pass_at_1": self.metrics_calc.calculate_pass_at_k(passes, k=1),
            "pass_at_5": self.metrics_calc.calculate_pass_at_k(passes, k=5),
            "samples": samples
        }
        
        # Aggregate numeric metrics (mean)
        numeric_metrics = {}
        for sample in samples:
            for key, value in sample.get("metrics", {}).items():
                if isinstance(value, (int, float)):
                    if key not in numeric_metrics:
                        numeric_metrics[key] = []
                    numeric_metrics[key].append(value)
        
        for key, values in numeric_metrics.items():
            aggregated[f"mean_{key}"] = sum(values) / len(values)
        
        return aggregated
    
    def _calculate_problem_summary(self, results: List[Dict]) -> Dict:
        """Calculate summary statistics for a problem category."""
        if not results:
            return {}
        
        num_scenarios = len(results)
        scenarios_passed = sum(1 for r in results if r.get("pass_rate", 0) > 0)
        
        return {
            "num_scenarios": num_scenarios,
            "scenarios_passed": scenarios_passed,
            "overall_pass_rate": scenarios_passed / num_scenarios if num_scenarios > 0 else 0,
            "mean_pass_at_1": sum(r.get("pass_at_1", 0) for r in results) / num_scenarios
        }
    
    def _calculate_overall_summary(self, problem_results: Dict) -> Dict:
        """Calculate overall benchmark summary."""
        summaries = [v.get("summary", {}) for v in problem_results.values()]
        
        total_scenarios = sum(s.get("num_scenarios", 0) for s in summaries)
        total_passed = sum(s.get("scenarios_passed", 0) for s in summaries)
        
        return {
            "total_scenarios": total_scenarios,
            "total_passed": total_passed,
            "overall_pass_rate": total_passed / total_scenarios if total_scenarios > 0 else 0,
            "problem_summaries": problem_results
        }
    
    def _print_summary(self, results: Dict):
        """Print formatted summary to console."""
        print(f"\n{Fore.CYAN}{'='*50}")
        print(f"{Fore.CYAN}BENCHMARK RESULTS SUMMARY")
        print(f"{Fore.CYAN}{'='*50}\n")
        
        print(f"Model: {results['metadata']['model']}")
        print(f"Timestamp: {results['metadata']['timestamp']}")
        print()
        
        overall = results.get("overall", {})
        print(f"{Fore.WHITE}Overall:")
        print(f"  Total Scenarios: {overall.get('total_scenarios', 0)}")
        print(f"  Passed: {overall.get('total_passed', 0)}")