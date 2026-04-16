from __future__ import annotations

import argparse
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from benchmark_runner.client import LLMConfig, OpenAICompatibleLLM
from benchmark_runner.runner import BenchmarkRunner, RunOptions
from benchmark_runner.tasks import list_tasks


DEFAULT_PAUSE_SECONDS = 3.0


class PausedOpenAICompatibleLLM(OpenAICompatibleLLM):
    def __init__(self, config: LLMConfig, *, pause_seconds: float = DEFAULT_PAUSE_SECONDS):
        super().__init__(config)
        self.pause_seconds = max(0.0, pause_seconds)
        self._last_request_monotonic: float | None = None

    def chat(
        self,
        messages: list[dict[str, str]],
        *,
        temperature: float | None = None,
        max_output_tokens: int | None = None,
    ) -> dict[str, Any]:
        if self._last_request_monotonic is not None and self.pause_seconds > 0:
            elapsed = time.monotonic() - self._last_request_monotonic
            remaining = self.pause_seconds - elapsed
            if remaining > 0:
                time.sleep(remaining)

        try:
            return super().chat(
                messages,
                temperature=temperature,
                max_output_tokens=max_output_tokens,
            )
        finally:
            self._last_request_monotonic = time.monotonic()


def _utc_timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=4) + "\n", encoding="utf-8")


def run_all_tasks_sequentially(
    *,
    model: str,
    api_key: str | None = None,
    base_url: str | None = None,
    temperature: float = 0.0,
    max_output_tokens: int | None = None,
    artifacts_root: str | Path = "tmp/llm_runs",
    max_agent_iterations: int | None = None,
    pause_seconds: float = DEFAULT_PAUSE_SECONDS,
    json_output: str | Path | None = None,
) -> dict[str, Any]:
    tasks = list_tasks()
    llm = PausedOpenAICompatibleLLM(
        LLMConfig(
            model=model,
            api_key=api_key,
            base_url=base_url,
            temperature=temperature,
            max_output_tokens=max_output_tokens,
        ),
        pause_seconds=pause_seconds,
    )
    runner = BenchmarkRunner(
        llm=llm,
        options=RunOptions(
            artifacts_root=Path(artifacts_root),
            max_agent_iterations=max_agent_iterations,
        ),
    )

    started_at = _utc_timestamp()
    task_results: list[dict[str, Any]] = []
    passed = 0
    failed = 0
    errored = 0

    for task in tasks:
        try:
            result = runner.run(task.task_id)
            benchmark_pass = bool(result.get("benchmark_pass"))
            task_results.append(
                {
                    "task_id": task.task_id,
                    "task_kind": task.task_kind,
                    "benchmark_pass": benchmark_pass,
                    "result": result,
                }
            )
            if benchmark_pass:
                passed += 1
                status = "PASS"
            else:
                failed += 1
                status = "FAIL"
            print(f"{task.task_id}: {status}")
        except Exception as exc:
            errored += 1
            task_results.append(
                {
                    "task_id": task.task_id,
                    "task_kind": task.task_kind,
                    "benchmark_pass": False,
                    "error": str(exc),
                }
            )
            print(f"{task.task_id}: ERROR - {exc}", file=sys.stderr)

    summary = {
        "model": model,
        "started_at": started_at,
        "finished_at": _utc_timestamp(),
        "pause_seconds": max(0.0, pause_seconds),
        "artifacts_root": str(artifacts_root),
        "task_count": len(tasks),
        "passed": passed,
        "failed": failed,
        "errored": errored,
        "results": task_results,
    }

    if json_output is not None:
        _write_json(Path(json_output), summary)

    return summary


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run all benchmark tasks through an OpenAI-compatible LLM sequentially."
    )
    parser.add_argument("--model", required=True, help="Model name for the OpenAI-compatible API.")
    parser.add_argument("--api-key", help="API key. Defaults to env vars.")
    parser.add_argument("--base-url", help="OpenAI-compatible base URL. Defaults to env vars.")
    parser.add_argument(
        "--temperature",
        type=float,
        default=0.0,
        help="Sampling temperature. Defaults to 0.0.",
    )
    parser.add_argument(
        "--max-output-tokens",
        type=int,
        help="Optional maximum number of output tokens.",
    )
    parser.add_argument(
        "--artifacts-root",
        default="tmp/llm_runs",
        help="Directory for prompts, responses, generated files, and reports.",
    )
    parser.add_argument(
        "--max-agent-iterations",
        type=int,
        help="Optional cap for agentic iterations. Applies to CDV tasks.",
    )
    parser.add_argument(
        "--pause-seconds",
        type=float,
        default=DEFAULT_PAUSE_SECONDS,
        help="Minimum pause between LLM API requests. Defaults to 3.0 seconds.",
    )
    parser.add_argument(
        "--json-output",
        help="Optional file path for writing the aggregate result JSON.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        summary = run_all_tasks_sequentially(
            model=args.model,
            api_key=args.api_key,
            base_url=args.base_url,
            temperature=args.temperature,
            max_output_tokens=args.max_output_tokens,
            artifacts_root=args.artifacts_root,
            max_agent_iterations=args.max_agent_iterations,
            pause_seconds=args.pause_seconds,
            json_output=args.json_output,
        )
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(json.dumps(summary, indent=4))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
