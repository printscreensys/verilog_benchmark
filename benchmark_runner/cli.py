from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

from .tasks import list_tasks


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run RTL benchmark tasks through an OpenAI-compatible LLM."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List available tasks.")
    list_parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON.")

    run_parser = subparsers.add_parser("run", help="Execute one benchmark task.")
    run_parser.add_argument("task", help="Task name or path.")
    run_parser.add_argument("--model", required=True, help="Model name for the OpenAI-compatible API.")
    run_parser.add_argument("--api-key", help="API key. Defaults to env vars.")
    run_parser.add_argument("--base-url", help="OpenAI-compatible base URL. Defaults to env vars.")
    run_parser.add_argument(
        "--temperature",
        type=float,
        default=0.0,
        help="Sampling temperature. Defaults to 0.0.",
    )
    run_parser.add_argument(
        "--max-output-tokens",
        type=int,
        help="Optional maximum number of output tokens.",
    )
    run_parser.add_argument(
        "--artifacts-root",
        default="tmp/llm_runs",
        help="Directory for prompts, responses, generated files, and reports.",
    )
    run_parser.add_argument(
        "--max-agent-iterations",
        type=int,
        help="Optional cap for agentic iterations. Applies to CDV tasks.",
    )
    run_parser.add_argument(
        "--json-output",
        help="Optional file path for writing the final result JSON.",
    )

    return parser


def _handle_list(json_output: bool) -> int:
    tasks = list_tasks()
    payload = [
        {
            "task_id": task.task_id,
            "task_kind": task.task_kind,
            "domain": task.domain,
            "task_dir": task.relative_dir,
            "title": task.title,
        }
        for task in tasks
    ]

    if json_output:
        print(json.dumps(payload, indent=4))
        return 0

    for item in payload:
        title = f" - {item['title']}" if item.get("title") else ""
        print(f"{item['task_id']} [{item['task_kind']}] ({item['task_dir']}){title}")
    return 0


def _handle_run(args: argparse.Namespace) -> int:
    from .client import LLMConfig, OpenAICompatibleLLM
    from .runner import BenchmarkRunner, RunOptions

    llm = OpenAICompatibleLLM(
        LLMConfig(
            model=args.model,
            api_key=args.api_key,
            base_url=args.base_url,
            temperature=args.temperature,
            max_output_tokens=args.max_output_tokens,
        )
    )
    runner = BenchmarkRunner(
        llm=llm,
        options=RunOptions(
            artifacts_root=Path(args.artifacts_root),
            max_agent_iterations=args.max_agent_iterations,
        ),
    )
    results = runner.run(args.task)
    print(json.dumps(results, indent=4))

    if args.json_output:
        output_path = Path(args.json_output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(results, indent=4) + "\n", encoding="utf-8")

    return 0


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        if args.command == "list":
            return _handle_list(args.json)
        if args.command == "run":
            return _handle_run(args)
        parser.error(f"Unknown command: {args.command}")
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1

    return 0
