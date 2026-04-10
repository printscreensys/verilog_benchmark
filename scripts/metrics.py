"""
Metrics calculation utilities for RTL evaluation.
"""

import re
import json
import subprocess
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple


class MetricsCalculator:
    """Base class for metric calculations."""
    
    @staticmethod
    def extract_verilog_from_response(response: str) -> str:
        """
        Extract Verilog code block from LLM response.
        
        Looks for ```verilog ... ``` or ```systemverilog ... ``` blocks.
        Falls back to entire response if no code block found.
        """
        patterns = [
            r'```(?:verilog|systemverilog|sv)\s*\n(.*?)```',
            r'```\s*\n(.*?)```',
        ]
        
        for pattern in patterns:
            match = re.search(pattern, response, re.DOTALL | re.IGNORECASE)
            if match:
                return match.group(1).strip()
        
        # Fallback: return entire response
        return response.strip()
    
    @staticmethod
    def compile_verilog(code: str, 
                        top_module: str,
                        include_dirs: List[str] = None,
                        additional_files: List[str] = None) -> Tuple[bool, str]:
        """
        Check if Verilog code compiles with Verilator.
        
        Returns:
            (success, log_output)
        """
        import tempfile
        import os
        
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            
            # Write main code
            main_file = tmp_path / f"{top_module}.v"
            main_file.write_text(code)
            
            # Copy additional files if provided
            if additional_files:
                for f in additional_files:
                    src = Path(f)
                    dst = tmp_path / src.name
                    dst.write_text(src.read_text())
            
            # Build verilator command
            cmd = ["verilator", "--lint-only", "-Wall", "-Wno-DECLFILENAME"]
            
            if include_dirs:
                for d in include_dirs:
                    cmd.extend(["-I", d])
            
            cmd.extend([str(main_file)])
            if additional_files:
                for f in additional_files:
                    cmd.append(str(Path(f).name))
            
            try:
                result = subprocess.run(
                    cmd,
                    cwd=tmpdir,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                success = result.returncode == 0
                log_output = result.stdout + result.stderr
                return success, log_output
            except subprocess.TimeoutExpired:
                return False, "Verilator compilation timed out"
            except FileNotFoundError:
                return False, "Verilator not found in PATH"
    
    @staticmethod
    def count_lines_of_code(code: str, exclude_comments: bool = True) -> int:
        """
        Count non-empty, non-comment lines in Verilog code.
        """
        lines = code.split('\n')
        count = 0
        in_block_comment = False
        
        for line in lines:
            stripped = line.strip()
            
            if not stripped:
                continue
            
            if exclude_comments:
                if in_block_comment:
                    if '*/' in stripped:
                        in_block_comment = False
                    continue
                
                if stripped.startswith('//'):
                    continue
                
                if '/*' in stripped:
                    in_block_comment = True
                    if '*/' in stripped:
                        in_block_comment = False
                    continue
            
            count += 1
        
        return count
    
    @staticmethod
    def run_yosys_synthesis(verilog_files: List[str], 
                            top_module: str,
                            script_template: str = None) -> Dict[str, Any]:
        """
        Run Yosys synthesis and extract area/stats.
        
        Returns:
            Dict with keys: 'success', 'cell_count', 'area_estimate', 'log'
        """
        import tempfile
        
        default_script = f"""
        read_verilog {' '.join(verilog_files)}
        hierarchy -top {top_module}
        proc
        opt
        techmap
        stat
        """
        
        script = script_template or default_script
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.ys', delete=False) as f:
            f.write(script)
            script_path = f.name
        
        try:
            result = subprocess.run(
                ["yosys", "-q", script_path],
                capture_output=True,
                text=True,
                timeout=60
            )
            
            # Parse cell count from stat output
            cell_match = re.search(r'Number of cells:\s*(\d+)', result.stdout + result.stderr)
            cell_count = int(cell_match.group(1)) if cell_match else 0
            
            return {
                "success": result.returncode == 0,
                "cell_count": cell_count,
                "log": result.stdout + result.stderr
            }
        except Exception as e:
            return {
                "success": False,
                "cell_count": 0,
                "log": str(e)
            }
        finally:
            Path(script_path).unlink(missing_ok=True)
    
    @staticmethod
    def calculate_pass_at_k(results: List[bool], k: int = 1) -> float:
        """
        Calculate pass@k metric from multiple samples.
        
        Args:
            results: List of boolean pass/fail for n samples
            k: Number of samples to consider
        
        Returns:
            Estimated probability that at least one of k samples passes
        """
        n = len(results)
        if n < k:
            return 0.0
        
        c = sum(results)
        if c == 0:
            return 0.0
        
        # pass@k = 1 - ( (n-c choose k) / (n choose k) )
        # For k=1: pass@1 = c/n
        if k == 1:
            return c / n
        
        # Use iterative calculation to avoid large factorials
        from math import comb
        return 1.0 - comb(n - c, k) / comb(n, k) if n - c >= k else 1.0