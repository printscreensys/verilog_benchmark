#!/usr/bin/env python3
"""
CWE Vulnerability Detector for RTL Code.
Performs AST-based and pattern-based vulnerability detection.
"""

import re
import sys
import json
import argparse
from pathlib import Path
from typing import List, Dict, Any, Set, Tuple
from dataclasses import dataclass, field

# Optional: Use pyverilog for AST parsing if available
try:
    import pyverilog.vparser.ast as vast
    from pyverilog.vparser.parser import parse
    PYVERILOG_AVAILABLE = True
except ImportError:
    PYVERILOG_AVAILABLE = False


@dataclass
class Vulnerability:
    """Represents a detected security vulnerability."""
    cwe_id: str
    name: str
    description: str
    line_number: int = 0
    severity: str = "medium"
    code_snippet: str = ""
    mitigation: str = ""


class CWEDetector:
    """Main CWE detector for RTL code."""
    
    def __init__(self, patterns_file: str = None):
        self.patterns = self._load_patterns(patterns_file)
        self.vulnerabilities: List[Vulnerability] = []
    
    def _load_patterns(self, patterns_file: str) -> Dict:
        """Load CWE detection patterns."""
        if patterns_file and Path(patterns_file).exists():
            import yaml
            with open(patterns_file, 'r') as f:
                return yaml.safe_load(f)
        
        # Default patterns
        return self._get_default_patterns()
    
    def _get_default_patterns(self) -> Dict:
        """Return default detection patterns."""
        return {
            "CWE-1271": {
                "name": "Uninitialized Register",
                "patterns": [r"always_ff\s*@\s*\(\s*posedge\s+\w+\s*\)"],
                "severity": "high"
            }
        }
    
    def analyze(self, code: str, file_path: str = None) -> List[Vulnerability]:
        """
        Analyze RTL code for security vulnerabilities.
        
        Args:
            code: Verilog/SystemVerilog source code
            file_path: Optional path to source file for context
        
        Returns:
            List of detected vulnerabilities
        """
        self.vulnerabilities = []
        lines = code.split('\n')
        
        # 1. Pattern-based detection
        self._pattern_scan(code, lines)
        
        # 2. AST-based detection (if pyverilog available)
        if PYVERILOG_AVAILABLE and file_path:
            try:
                self._ast_scan(file_path)
            except Exception as e:
                print(f"AST scan failed: {e}", file=sys.stderr)
        
        # 3. Structural checks
        self._structural_checks(code, lines)
        
        return self.vulnerabilities
    
    def _pattern_scan(self, code: str, lines: List[str]):
        """Scan code using regex patterns."""
        for cwe_id, cwe_info in self.patterns.items():
            for pattern in cwe_info.get("patterns", []):
                for match in re.finditer(pattern, code, re.IGNORECASE | re.MULTILINE):
                    line_num = code[:match.start()].count('\n') + 1
                    
                    # Check if antipattern mitigates this
                    mitigated = False
                    for antipattern in cwe_info.get("antipatterns", []):
                        if re.search(antipattern, code, re.IGNORECASE):
                            mitigated = True
                            break
                    
                    if not mitigated:
                        self.vulnerabilities.append(Vulnerability(
                            cwe_id=cwe_id,
                            name=cwe_info.get("name", ""),
                            description=f"Pattern match for {cwe_id}",
                            line_number=line_num,
                            severity=cwe_info.get("severity", "medium"),
                            code_snippet=lines[line_num-1].strip() if line_num <= len(lines) else "",
                            mitigation=cwe_info.get("mitigation", "Review and apply secure coding guidelines")
                        ))
            
            # Check for missing required patterns
            for required in cwe_info.get("required", []):
                if not re.search(required, code, re.IGNORECASE):
                    self.vulnerabilities.append(Vulnerability(
                        cwe_id=cwe_id,
                        name=cwe_info.get("name", ""),
                        description=f"Missing required secure pattern: {required[:50]}...",
                        severity=cwe_info.get("severity", "medium"),
                        mitigation=f"Add required pattern: {required}"
                    ))
    
    def _ast_scan(self, file_path: str):
        """Perform AST-based vulnerability detection."""
        ast, _ = parse([file_path])
        
        # Walk AST to find security issues
        # This is a placeholder - full implementation would traverse AST
        # to detect things like:
        # - Uninitialized registers in always_ff blocks
        # - Incomplete case statements
        # - Latches in combinational logic
        pass
    
    def _structural_checks(self, code: str, lines: List[str]):
        """Perform structural security checks."""
        
        # Check 1: Debug ports without ifdef guards
        debug_signals = re.findall(r'(?:input|output|inout)\s+(?:logic\s+)?(?:\[\d+:\d+\]\s+)?(\w*debug\w*)', code, re.IGNORECASE)
        if debug_signals:
            has_ifdef = re.search(r'`ifdef\s+(?:DEBUG|SIMULATION)', code)
            if not has_ifdef:
                for signal in debug_signals[:3]:  # Limit reporting
                    line_num = self._find_line(signal, lines)
                    self.vulnerabilities.append(Vulnerability(
                        cwe_id="CWE-1245",
                        name="Debug Interface Exposure",
                        description=f"Debug signal '{signal}' not protected by compile-time guard",
                        line_number=line_num,
                        severity="medium",
                        mitigation="Wrap debug signals in `ifdef DEBUG ... `endif"
                    ))
        
        # Check 2: Incomplete sensitivity lists
        always_blocks = re.findall(r'always\s*@\s*\(\s*([^)]+)\s*\)', code)
        for sensitivity in always_blocks:
            if sensitivity != '*' and 'or' in sensitivity:
                # Count signals in sensitivity list
                sigs = [s.strip() for s in sensitivity.split('or')]
                # This is a heuristic - full check requires AST
                if len(sigs) < 3:
                    self.vulnerabilities.append(Vulnerability(
                        cwe_id="CWE-1234",
                        name="Incomplete Sensitivity List",
                        description="Potential incomplete sensitivity list in always block",
                        severity="low",
                        mitigation="Use always @(*) or always_comb for combinational logic"
                    ))
        
        # Check 3: Reset domain crossing issues
        async_reset = re.search(r'always_ff\s*@\s*\(\s*posedge\s+\w+\s+or\s+negedge\s+(\w+)', code)
        sync_reset = re.search(r'if\s*\(\s*!\s*(\w+)\s*\)', code)
        if async_reset and sync_reset:
            if async_reset.group(1) != sync_reset.group(1):
                self.vulnerabilities.append(Vulnerability(
                    cwe_id="CWE-1290",
                    name="Reset Domain Crossing",
                    description="Mismatch between asynchronous reset signal and synchronous reset condition",
                    severity="medium",
                    mitigation="Use consistent reset signal naming"
                ))
    
    def _find_line(self, pattern: str, lines: List[str]) -> int:
        """Find line number containing pattern."""
        for i, line in enumerate(lines, 1):
            if pattern in line:
                return i
        return 0
    
    def generate_report(self, format: str = "json") -> str:
        """Generate vulnerability report."""
        if format == "json":
            return json.dumps([vars(v) for v in self.vulnerabilities], indent=2)
        elif format == "text":
            report = []
            report.append("=" * 60)
            report.append("SECURITY VULNERABILITY REPORT")
            report.append("=" * 60)
            
            by_severity = {"high": [], "medium": [], "low": []}
            for v in self.vulnerabilities:
                by_severity[v.severity].append(v)
            
            for severity in ["high", "medium", "low"]:
                if by_severity[severity]:
                    report.append(f"\n[{severity.upper()} Severity]")
                    for v in by_severity[severity]:
                        report.append(f"  • {v.cwe_id}: {v.name}")
                        report.append(f"    Line {v.line_number}: {v.description}")
                        report.append(f"    Mitigation: {v.mitigation}")
            
            if not self.vulnerabilities:
                report.append("\n✓ No security vulnerabilities detected.")
            
            return "\n".join(report)
        
        return ""


def main():
    parser = argparse.ArgumentParser(description="CWE Vulnerability Detector for RTL")
    parser.add_argument("input_file", help="Verilog/SystemVerilog file to analyze")
    parser.add_argument("--patterns", help="YAML file with CWE patterns")
    parser.add_argument("--format", choices=["json", "text"], default="text")
    parser.add_argument("--output", help="Output report file")
    
    args = parser.parse_args()
    
    # Read input file
    code = Path(args.input_file).read_text()
    
    # Run detection
    detector = CWEDetector(args.patterns)
    vulnerabilities = detector.analyze(code, args.input_file)
    
    # Generate report
    report = detector.generate_report(args.format)
    
    if args.output:
        Path(args.output).write_text(report)
    else:
        print(report)
    
    # Return exit code based on findings
    high_severity = sum(1 for v in vulnerabilities if v.severity == "high")
    sys.exit(1 if high_severity > 0 else 0)


if __name__ == "__main__":
    main()