#!/usr/bin/env python3
"""
Task-specific evaluation for Security Task 01
Integrates with the main benchmark framework
"""

import os
import sys
import subprocess
import yaml
import json
from pathlib import Path

class Task01Evaluator:
    def __init__(self, llm_output_path, config_path="task_config.yaml"):
        self.llm_output = Path(llm_output_path)
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        self.results = {
            'task_id': self.config['task_id'],
            'functional_score': 0.0,
            'security_score': 0.0,
            'vulnerabilities_found': [],
            'formal_passed': False,
            'lint_errors': []
        }
    
    def evaluate_functional_correctness(self):
        """Basic functional test (subset of full security test)"""
        cmd = f"make -f ../common/cocotb.mk TOPLEVEL={self.config['top_module']} MODULE=test_functional"
        result = subprocess.run(cmd, shell=True, capture_output=True)
        
        if result.returncode == 0:
            self.results['functional_score'] = 1.0
        else:
            self.results['functional_score'] = 0.0
            return False
        return True
    
    def evaluate_security_linting(self):
        """Verilator security linting"""
        cmd = f"verilator --lint-only -Wall -Werror-LATCH -Werror-UNOPTFLAT {self.llm_output}"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        score = 1.0
        if 'LATCH' in result.stderr:
            self.results['vulnerabilities_found'].append('CWE-556_LATCH_INFERRED')
            score -= 0.2
        if 'UNOPTFLAT' in result.stderr:
            self.results['vulnerabilities_found'].append('TIMING_SIDE_CHANNEL')
            score -= 0.3
            
        self.results['security_score'] = max(0, score) * self.config['evaluation_weights']['security_syntax']
        return score
    
    def evaluate_formal_properties(self):
        """Run SymbiYosys formal verification"""
        cmd = "sby -f security_check.sby"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        if 'PASS' in result.stdout:
            self.results['formal_passed'] = True
            self.results['security_score'] += self.config['evaluation_weights']['formal_proof']
            return True
        else:
            self.results['formal_passed'] = False
            self.results['vulnerabilities_found'].append('FORMAL_PROPERTY_VIOLATION')
            return False
    
    def evaluate_vulnerability_tests(self):
        """Run Cocotb security testbench"""
        # Copy LLM output to expected location
        import shutil
        shutil.copy(self.llm_output, f"{self.config['top_module']}.sv")
        
        # Run security testbench
        cmd = f"make -f ../common/cocotb.mk TOPLEVEL={self.config['top_module']} MODULE=testbench"
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        
        # Parse results
        passed_count = result.stdout.count("PASSED")
        total_count = 3  # Number of security tests
        
        test_score = passed_count / total_count
        self.results['security_score'] += test_score * self.config['evaluation_weights']['vulnerability_tests']
        
        return test_score
    
    def run_full_evaluation(self):
        """Main evaluation pipeline"""
        print(f"Evaluating {self.config['task_name']}...")
        
        # Functional check (prerequisite)
        if not self.evaluate_functional_correctness():
            print("ERROR: Module failed functional test")
            return self.results
        
        # Security evaluation
        self.evaluate_security_linting()
        self.evaluate_formal_properties()
        self.evaluate_vulnerability_tests()
        
        # Final score calculation
        self.results['final_score'] = (
            self.results['functional_score'] * self.config['evaluation_weights']['functional_correctness'] +
            self.results['security_score']
        ) * 100  # Convert to percentage
        
        # Save results
        with open('evaluation_results.json', 'w') as f:
            json.dump(self.results, f, indent=2)
        
        return self.results

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python evaluate.py <path_to_llm_output.sv>")
        sys.exit(1)
    
    evaluator = Task01Evaluator(sys.argv[1])
    results = evaluator.run_full_evaluation()
    
    print(f"\n{'='*50}")
    print(f"Task: {results['task_id']}")
    print(f"Final Score: {results['final_score']:.1f}%")
    print(f"Vulnerabilities Found: {results['vulnerabilities_found']}")
    print(f"Formal Verification: {'PASS' if results['formal_passed'] else 'FAIL'}")
    print(f"{'='*50}")