import os
import shlex
import shutil
import subprocess
import tempfile
from functools import lru_cache

from .common import clean_tool_output
from .timing import run_optional_timing_check


def _run_optional_tool(
    command,
    *,
    executable,
    result_template,
    ran_key,
    passed_key,
    message_key,
    evaluator,
    label,
):
    result_metrics = dict(result_template)
    if shutil.which(executable) is None:
        result_metrics[message_key] = f"Skipped: {executable} is not installed."
        return result_metrics

    try:
        process = subprocess.run(command, capture_output=True, text=True, timeout=10)
        output = clean_tool_output(process.stdout + process.stderr)
        result_metrics[ran_key] = True
        result_metrics[passed_key] = evaluator(process, output)
        result_metrics[message_key] = output
    except Exception as exc:
        result_metrics[ran_key] = True
        result_metrics[passed_key] = False
        result_metrics[message_key] = f"{label} execution error: {str(exc)}"

    return result_metrics


@lru_cache(maxsize=1)
def _supported_verilator_warning_flags():
    if shutil.which("verilator") is None:
        return ()

    warning_flags = (
        "-Wno-DECLFILENAME",
        "-Wno-UNUSEDSIGNAL",
        "-Wno-PINCONNECTEMPTY",
    )
    supported_flags = []

    with tempfile.NamedTemporaryFile("w", suffix=".v", delete=False) as handle:
        handle.write("module lint_probe; endmodule\n")
        probe_file = handle.name

    try:
        for warning_flag in warning_flags:
            probe = subprocess.run(
                ["verilator", "--lint-only", warning_flag, probe_file],
                capture_output=True,
                text=True,
                timeout=10,
            )
            output = clean_tool_output(probe.stdout + probe.stderr)
            if "Unknown warning specified" not in output:
                supported_flags.append(warning_flag)
    finally:
        if os.path.exists(probe_file):
            os.remove(probe_file)

    return tuple(supported_flags)


def run_optional_lint(verilog_file):
    lint_cmd = [
        "verilator",
        "--lint-only",
        "-Wall",
        *_supported_verilator_warning_flags(),
        verilog_file,
    ]
    return _run_optional_tool(
        lint_cmd,
        executable="verilator",
        result_template={
            "lint_ran": False,
            "lint_clean": None,
            "lint_message": "",
        },
        ran_key="lint_ran",
        passed_key="lint_clean",
        message_key="lint_message",
        evaluator=lambda process, output: (
            process.returncode == 0
            and "%Warning" not in output
            and "%Error" not in output
        ),
        label="Lint",
    )


def run_optional_synth_check(verilog_file):
    yosys_script = (
        "read_verilog {file}; hierarchy -check -auto-top; proc; check -assert"
    ).format(file=shlex.quote(verilog_file))
    return _run_optional_tool(
        ["yosys", "-q", "-p", yosys_script],
        executable="yosys",
        result_template={
            "synth_check_ran": False,
            "synth_check_passed": None,
            "synth_message": "",
        },
        ran_key="synth_check_ran",
        passed_key="synth_check_passed",
        message_key="synth_message",
        evaluator=lambda process, _output: process.returncode == 0,
        label="Synthesis check",
    )


def evaluate_task(
    llm_generated_file,
    testbench_file,
    output_executable=None,
    run_lint=True,
    run_synth_check=True,
    timing_spec_file=None,
    reference_verilog_file=None,
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
        "area_constraints_met": None,
        "timing_message": "",
        "area_and_timings": {
            "check_ran": False,
            "message": "",
            "analysis_method": "",
            "constraints_source": None,
            "liberty_file": None,
            "opensta_image": None,
            "opensta_image_available": None,
            "top_module": None,
            "timing_ns": None,
            "timing_target_ns": None,
            "timing_margin_ns": None,
            "timing_met": None,
            "area_um2": None,
            "area_target_um2": None,
            "area_margin_um2": None,
            "area_met": None,
            "instance_count": None,
            "instance_count_target": None,
            "constraints_met": None,
        },
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
            result_metrics.update(
                run_optional_timing_check(
                    llm_generated_file,
                    timing_spec_file,
                    reference_verilog_file=reference_verilog_file,
                )
            )

        sim_cmd = ["vvp", output_executable]
        sim_process = subprocess.run(sim_cmd, capture_output=True, text=True, timeout=10)
        sim_output = sim_process.stdout

        if "TEST_PASSED" in sim_output:
            result_metrics["functionally_correct"] = True
            result_metrics["benchmark_pass"] = True
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
