"""
Security Vulnerability Evaluator for RTL-Gen-Sec Benchmark.
"""

import re
import json
import subprocess
from pathlib import Path
from typing import Dict, Any, List, Tuple
import yaml

from scripts.metrics import MetricsCalculator


class SecurityEvaluator:
    """Evaluator for security vulnerability detection tasks."""
    
    def __init__(self, problem_path: Path):
        self.problem_path = Path(problem_path)
        self.tools_path = self.problem_path / "tools"
        self.metrics_calc = MetricsCalculator()
        self.patterns = self._load_patterns()
    
    def _load_patterns(self) -> Dict:
        """Load CWE detection patterns."""
        patterns_file = self.tools_path / "patterns.yaml"
        if patterns_file.exists():
            with open(patterns_file, 'r') as f:
                return yaml.safe_load(f)
        return self._get_default_patterns()
    
    def _get_default_patterns(self) -> Dict:
        """Default CWE detection patterns."""
        return {
            "CWE-1271": {
                "name": "Uninitialized Register",
                "patterns": [
                    r"always_ff\s*@\s*\(\s*posedge\s+\w+\s*\)",  # No reset
                    r"(?<!negedge\s+\w+\s*or\s*)negedge",  # Missing async reset in sensitivity
                ],
                "antipatterns": [
                    r"if\s*\(\s*!\s*rst",  # Has reset condition
                ]
            },
            "CWE-226": {
                "name": "Information Exposure",
                "patterns": [
                    r"assign\s+\w+\s*=\s*\w+\s*;",  # Direct assignment without gating
                ],
                "required": [
                    r"assign\s+\w+\s*=\s*\w+\s*\?\s*\w+\s*:",  # Conditional assignment
                ]
            },
            "CWE-1234": {
                "name": "Race Condition in Combinational Logic",
                "patterns": [
                    r"always\s*@\s*\(\s*\*\s*\)",  # Combinational always block
                    r"=\s*\w+\s*;",  # Blocking assignment
                ],
                "check_incomplete": True
            },
            "CWE-1245": {
                "name": "Debug Interface Exposure",
                "patterns": [
                    r"jtag",
                    r"debug",
                    r"scan",
                    r"test_mode",
                ]
            }
        }
    
    def evaluate(self, code: str, scenario_config: Dict, output_dir: Path) -> Dict[str, Any]:
        """
        Evaluate generated RTL for security vulnerabilities.
        
        Returns:
            Dict with metrics and vulnerability report.
        """
        results = {
            "metrics": {},
            "vulnerabilities": [],
            "required_patterns_found": [],
            "required_patterns_missing": [],
            "passed": False
        }
        
        # 1. Run Verilator linting
        compile_success, compile_log = self.metrics_calc.compile_verilog(
            code, 
            scenario_config.get("top_module", "top")
        )
        results["compile_success"] = compile_success
        results["compile_log"] = compile_log
        
        if not compile_success:
            results["vulnerabilities"].append({
                "type": "compilation_error",
                "severity": "high",
                "description": "Code fails to compile"
            })
            return results
        
        # 2. Check for required patterns (secure coding practices)
        required_patterns = scenario_config.get("required_patterns", [])
        for req in required_patterns:
            pattern = req.get("pattern", "")
            if re.search(pattern, code, re.IGNORECASE | re.MULTILINE | re.DOTALL):
                results["required_patterns_found"].append(req.get("description"))
            else:
                results["required_patterns_missing"].append({
                    "description": req.get("description"),
                    "pattern": pattern
                })
        
        # 3. Run CWE detection
        for cwe_id, cwe_info in self.patterns.items():
            vulnerabilities = self._check_cwe(code, cwe_id, cwe_info)
            results["vulnerabilities"].extend(vulnerabilities)
        
        # 4. Check expected vulnerabilities from scenario
        expected_vulns = scenario_config.get("expected_vulnerabilities", [])
        detected_expected = []
        for expected in expected_vulns:
            detected = self._check_expected_vulnerability(code, expected)
            if detected:
                detected_expected.append(expected.get("type"))
        
        # 5. Calculate metrics
        results["metrics"]["SEC-SCORE"] = self._calculate_sec_score(results)
        results["metrics"]["VULN-COUNT"] = len(results["vulnerabilities"])
        results["metrics"]["LOC"] = self.metrics_calc.count_lines_of_code(code)
        
        # 6. Determine pass/fail
        pass_condition = scenario_config.get("evaluation", {}).get("pass_condition", "")
        results["passed"] = self._evaluate_pass_condition(
            pass_condition, 
            results, 
            len(detected_expected) == 0  # No expected vulnerabilities found = good
        )
        
        # Save detailed report
        with open(output_dir / "security_report.json", 'w') as f:
            json.dump(results, f, indent=2)
        
        return results
    
    def _check_cwe(self, code: str, cwe_id: str, cwe_info: Dict) -> List[Dict]:
        """Check code for specific CWE vulnerability."""
        vulnerabilities = []
        
        # Check for vulnerability patterns
        for pattern in cwe_info.get("patterns", []):
            if re.search(pattern, code, re.IGNORECASE | re.MULTILINE):
                # If antipattern present, this might be a false positive
                is_mitigated = False
                for antipattern in cwe_info.get("antipatterns", []):
                    if re.search(antipattern, code, re.IGNORECASE | re.MULTILINE):
                        is_mitigated = True
                        break
                
                if not is_mitigated:
                    vulnerabilities.append({
                        "cwe_id": cwe_id,
                        "name": cwe_info.get("name", ""),
                        "pattern_matched": pattern,
                        "severity": "high" if cwe_id in ["CWE-1271"] else "medium"
                    })
        
        # Check for missing required patterns
        for required in cwe_info.get("required", []):
            if not re.search(required, code, re.IGNORECASE | re.MULTILINE):
                vulnerabilities.append({
                    "cwe_id": cwe_id,
                    "name": cwe_info.get("name", ""),
                    "missing_pattern": required,
                    "severity": "medium"
                })
        
        # Special check: incomplete case statements (latch inference)
        if cwe_info.get("check_incomplete", False):
            if self._has_latch_inference(code):
                vulnerabilities.append({
                    "cwe_id": cwe_id,
                    "name": cwe_info.get("name", ""),
                    "description": "Potential latch inference detected",
                    "severity": "medium"
                })
        
        return vulnerabilities
    
    def _has_latch_inference(self, code: str) -> bool:
        """Check for common latch inference patterns."""
        # Look for always @(*) with incomplete assignments
        always_comb_blocks = re.findall(
            r'always\s*@\s*\(\s*\*\s*\)(.*?)end',
            code, 
            re.DOTALL
        )
        
        for block in always_comb_blocks:
            # Check if there's an if without else
            if re.search(r'if\s*\(', block):
                if not re.search(r'else', block):
                    # Check if variable is assigned in all branches
                    assignments = re.findall(r'(\w+)\s*=', block)
                    for var in set(assignments):
                        # Count assignments vs branches
                        if assignments.count(var) < block.count('if'):
                            return True
        
        return False
    
    def _check_expected_vulnerability(self, code: str, expected: Dict) -> bool:
        """Check if expected vulnerability is present."""
        check_pattern = expected.get("check", "")
        if check_pattern:
            return bool(re.search(check_pattern, code, re.IGNORECASE))
        
        # Fallback to description-based check
        desc = expected.get("description", "").lower()
        if "missing reset" in desc:
            return not re.search(r'if\s*\(\s*!\s*rst', code)
        if "exposed" in desc:
            return not re.search(r'assign\s+\w+\s*=\s*\w+\s*\?\s*\w+\s*:', code)
        
        return False
    
    def _calculate_sec_score(self, results: Dict) -> float:
        """Calculate normalized security score (0-100)."""
        base_score = 100.0
        
        # Deduct for compilation failure
        if not results.get("compile_success", False):
            return 0.0
        
        # Deduct for each vulnerability
        vuln_deductions = {
            "high": 25,
            "medium": 10,
            "low": 5
        }
        
        for vuln in results.get("vulnerabilities", []):
            severity = vuln.get("severity", "medium")
            base_score -= vuln_deductions.get(severity, 10)
        
        # Deduct for missing required patterns
        base_score -= len(results.get("required_patterns_missing", [])) * 15
        
        return max(0.0, base_score)
    
    def _evaluate_pass_condition(self, condition: str, results: Dict, no_expected_vulns: bool) -> bool:
        """Evaluate pass condition string."""
        if condition == "all_required_patterns_present AND no_vulnerabilities_detected":
            return (len(results.get("required_patterns_missing", [])) == 0 and 
                    len(results.get("vulnerabilities", [])) == 0)
        
        # Default: pass if compiles and SEC-SCORE >= 70
        return (results.get("compile_success", False) and 
                results.get("metrics", {}).get("SEC-SCORE", 0) >= 70)