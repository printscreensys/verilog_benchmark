import os
import shlex
import shutil
import subprocess
import tempfile

from .common import clean_tool_output
from .timing import run_optional_timing_check


def run_optional_lint(verilog_file):
    result_metrics = {
        "lint_ran": False,
        "lint_clean": None,
        "lint_message": "",
    }

    if shutil.which("verilator") is None:
        result_metrics["lint_message"] = "Skipped: verilator is not installed."
        return result_metrics

    lint_cmd = [
        "verilator",
        "--lint-only",
        "-Wall",
        "-Wno-DECLFILENAME",
        "-Wno-UNUSEDSIGNAL",
        "-Wno-PINCONNECTEMPTY",
        verilog_file,
    ]

    try:
        lint_process = subprocess.run(lint_cmd, capture_output=True, text=True, timeout=10)
        lint_output = clean_tool_output(lint_process.stdout + lint_process.stderr)

        result_metrics["lint_ran"] = True
        result_metrics["lint_clean"] = (
            lint_process.returncode == 0
            and "%Warning" not in lint_output
            and "%Error" not in lint_output
        )
        result_metrics["lint_message"] = lint_output
    except Exception as exc:
        result_metrics["lint_ran"] = True
        result_metrics["lint_clean"] = False
        result_metrics["lint_message"] = f"Lint execution error: {str(exc)}"

    return result_metrics


def run_optional_synth_check(verilog_file):
    result_metrics = {
        "synth_check_ran": False,
        "synth_check_passed": None,
        "synth_message": "",
    }

    if shutil.which("yosys") is None:
        result_metrics["synth_message"] = "Skipped: yosys is not installed."
        return result_metrics

    yosys_script = (
        "read_verilog {file}; hierarchy -check -auto-top; proc; check -assert"
    ).format(file=shlex.quote(verilog_file))
    synth_cmd = ["yosys", "-q", "-p", yosys_script]

    try:
        synth_process = subprocess.run(synth_cmd, capture_output=True, text=True, timeout=10)
        synth_output = clean_tool_output(synth_process.stdout + synth_process.stderr)

        result_metrics["synth_check_ran"] = True
        result_metrics["synth_check_passed"] = synth_process.returncode == 0
        result_metrics["synth_message"] = synth_output
    except Exception as exc:
        result_metrics["synth_check_ran"] = True
        result_metrics["synth_check_passed"] = False
        result_metrics["synth_message"] = f"Synthesis check execution error: {str(exc)}"

    return result_metrics


def evaluate_task(
    llm_generated_file,
    testbench_file,
    output_executable=None,
    run_lint=True,
    run_synth_check=True,
    timing_spec_file=None,
    run_timing_check=True,
):
    result_metrics = {
        "syntax_correct": False,
        "functionally_correct": False,
        "benchmark_pass": False,
        "error_message": "",
        "lint_ran": False,
        "lint_clean": None,
        "lint_message": "",
        "synth_check_ran": False,
        "synth_check_passed": None,
        "synth_message": "",
        "timing_check_ran": False,
        "timing_constraints_met": None,
        "timing_message": "",
    }

    if run_lint:
        result_metrics.update(run_optional_lint(llm_generated_file))

    if run_synth_check:
        result_metrics.update(run_optional_synth_check(llm_generated_file))

    if output_executable is None:
        temp_handle = tempfile.NamedTemporaryFile(
            suffix=".vvp",
            prefix="verilog_eval_",
            delete=False,
        )
        output_executable = temp_handle.name
        temp_handle.close()

    compile_cmd = ["iverilog", "-o", output_executable, llm_generated_file, testbench_file]

    try:
        compile_process = subprocess.run(compile_cmd, capture_output=True, text=True, timeout=10)

        if compile_process.returncode != 0:
            result_metrics["error_message"] = "Compilation Failed:\n" + compile_process.stderr
            return result_metrics

        result_metrics["syntax_correct"] = True

        if run_timing_check:
            result_metrics.update(run_optional_timing_check(llm_generated_file, timing_spec_file))

        sim_cmd = ["vvp", output_executable]
        sim_process = subprocess.run(sim_cmd, capture_output=True, text=True, timeout=10)
        sim_output = sim_process.stdout

        if "TEST_PASSED" in sim_output:
            result_metrics["functionally_correct"] = True
            result_metrics["benchmark_pass"] = (
                result_metrics["timing_constraints_met"] is not False
            )
        elif "TEST_FAILED" in sim_output:
            result_metrics["error_message"] = "Testbench Functional Failure."
        else:
            result_metrics["error_message"] = "Unknown Simulation State (No PASS/FAIL token)."
    except subprocess.TimeoutExpired:
        result_metrics["error_message"] = "Simulation timed out (possible infinite loop)."
    except Exception as exc:
        result_metrics["error_message"] = f"Simulation execution error: {str(exc)}"
    finally:
        if os.path.exists(output_executable):
            os.remove(output_executable)

    return result_metrics
