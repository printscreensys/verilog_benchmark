import subprocess
import os
import json
import sys

def evaluate_task(llm_generated_file, testbench_file, output_executable="sim.vvp"):
    """
    Evaluates LLM generated Verilog code using Icarus Verilog.
    """
    result_metrics = {
        "syntax_correct": False,
        "functionally_correct": False,
        "error_message": ""
    }

    # Step 1: Compile the Verilog code using Icarus Verilog (iverilog)
    compile_cmd = ["iverilog", "-o", output_executable, llm_generated_file, testbench_file]
    
    try:
        compile_process = subprocess.run(compile_cmd, capture_output=True, text=True, timeout=10)
        
        if compile_process.returncode != 0:
            result_metrics["error_message"] = "Compilation Failed:\n" + compile_process.stderr
            return result_metrics
        
        result_metrics["syntax_correct"] = True

    except Exception as e:
        result_metrics["error_message"] = f"Compilation execution error: {str(e)}"
        return result_metrics

    # Step 2: Run the simulation using vvp
    sim_cmd = ["vvp", output_executable]
    
    try:
        sim_process = subprocess.run(sim_cmd, capture_output=True, text=True, timeout=10)
        sim_output = sim_process.stdout
        
        if "TEST_PASSED" in sim_output:
            result_metrics["functionally_correct"] = True
        elif "TEST_FAILED" in sim_output:
            result_metrics["error_message"] = "Testbench Functional Failure."
        else:
            result_metrics["error_message"] = "Unknown Simulation State (No PASS/FAIL token)."
            
    except subprocess.TimeoutExpired:
        result_metrics["error_message"] = "Simulation timed out (possible infinite loop)."
    except Exception as e:
        result_metrics["error_message"] = f"Simulation execution error: {str(e)}"

    # Cleanup generated executable
    if os.path.exists(output_executable):
        os.remove(output_executable)

    return result_metrics

if __name__ == "__main__":
    # Example usage:
    # Assuming the LLM output was saved to 'task_01_llm_output.v'
    # For testing this script, you can point it at the golden reference first!
    
    llm_file = sys.argv[1] # Replace with LLM's generated file in production
    tb_file = sys.argv[2]

    print(f"Evaluating LLM generation")
    results = evaluate_task(llm_file, tb_file)
    
    print(json.dumps(results, indent=4))
