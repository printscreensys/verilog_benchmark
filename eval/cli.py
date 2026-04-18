import argparse
import json
import os

from .clarification import evaluate_clarification_questions
from .common import resolve_task_paths, write_text_file
from .rtl import evaluate_task


def build_parser():
    parser = argparse.ArgumentParser(
        description="Evaluate generated Verilog and optionally score clarification or timing phases."
    )
    parser.add_argument(
        "llm_file",
        nargs="?",
        help="Path to the generated Verilog file.",
    )
    parser.add_argument(
        "tb_file",
        nargs="?",
        help="Path to the Verilog testbench.",
    )
    parser.add_argument(
        "--task-dir",
        help="Task directory containing tb.v and optional benchmark metadata.",
    )
    parser.add_argument(
        "--questions-file",
        help="Text file containing the model's clarifying questions.",
    )
    parser.add_argument(
        "--clarification-spec",
        help="JSON file with clarification intents, matching rules, and deterministic answers.",
    )
    parser.add_argument(
        "--timing-spec",
        help="Optional JSON file with real area/timing evaluation metadata for the task.",
    )
    parser.add_argument(
        "--reference-verilog",
        help="Reference Verilog used to derive hidden area/timing targets, typically ref.v.",
    )
    parser.add_argument(
        "--answers-output",
        help="Optional path for writing the benchmark's clarification answers.",
    )
    parser.add_argument(
        "--answers-only",
        action="store_true",
        help="Only score clarifying questions and emit answers. Skip RTL compilation and simulation.",
    )
    parser.add_argument(
        "--skip-lint",
        action="store_true",
        help="Skip the optional Verilator lint pass.",
    )
    parser.add_argument(
        "--skip-synth-check",
        action="store_true",
        help="Skip the optional Yosys synthesis sanity check.",
    )
    parser.add_argument(
        "--skip-timing-check",
        action="store_true",
        help="Skip the optional real area/timing check.",
    )
    parser.add_argument(
        "--sim-output",
        help="Temporary Icarus output executable path. Defaults to a unique temp file.",
    )
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)

    task_paths = resolve_task_paths(args.task_dir)
    tb_file = args.tb_file
    clarification_spec_file = args.clarification_spec
    timing_spec_file = args.timing_spec
    reference_verilog_file = args.reference_verilog

    if tb_file is None and task_paths.get("tb_file") and os.path.exists(task_paths["tb_file"]):
        tb_file = task_paths["tb_file"]

    if (
        clarification_spec_file is None
        and task_paths.get("clarification_spec_file")
        and os.path.exists(task_paths["clarification_spec_file"])
    ):
        clarification_spec_file = task_paths["clarification_spec_file"]

    if (
        timing_spec_file is None
        and task_paths.get("timing_spec_file")
        and os.path.exists(task_paths["timing_spec_file"])
    ):
        timing_spec_file = task_paths["timing_spec_file"]

    if (
        reference_verilog_file is None
        and task_paths.get("reference_verilog_file")
        and os.path.exists(task_paths["reference_verilog_file"])
    ):
        reference_verilog_file = task_paths["reference_verilog_file"]

    if args.answers_only and not args.questions_file:
        parser.error("--answers-only requires --questions-file.")

    if args.questions_file and clarification_spec_file is None:
        parser.error(
            "--questions-file requires --clarification-spec or --task-dir with clarifications.json."
        )

    if not args.answers_only and (args.llm_file is None or tb_file is None):
        parser.error("llm_file and tb_file are required unless --answers-only is used.")

    results = {}
    if args.questions_file:
        clarification_results = evaluate_clarification_questions(
            args.questions_file,
            clarification_spec_file,
        )
        results["clarification"] = clarification_results
        if args.answers_output:
            write_text_file(args.answers_output, clarification_results["answer_bundle"] + "\n")

    if not args.answers_only:
        print("Evaluating LLM generation")
        results.update(
            evaluate_task(
                args.llm_file,
                tb_file,
                output_executable=args.sim_output,
                run_lint=not args.skip_lint,
                run_synth_check=not args.skip_synth_check,
                timing_spec_file=timing_spec_file,
                reference_verilog_file=reference_verilog_file,
                run_timing_check=not args.skip_timing_check,
            )
        )

    print(json.dumps(results, indent=4))
