from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys
from typing import Any

from eval.clarification import evaluate_clarification_questions
from eval.rtl import evaluate_task

from .client import LLMConfig, OpenAICompatibleLLM
from .tasks import BenchmarkTask, REPO_ROOT, resolve_task


RTL_SYSTEM_PROMPT = (
    "You are an expert RTL engineer. Return only synthesizable Verilog-2001 "
    "source code. Do not include explanations."
)
CLARIFICATION_SYSTEM_PROMPT = (
    "You are reviewing an RTL specification for ambiguity. Ask only the minimum "
    "clarifying questions whose answers would change the implementation. Output "
    "only the questions, one per line. Do not generate RTL."
)
CDV_AGENT_SYSTEM_PROMPT = (
    "You are a coverage-closure agent for a hardware verification benchmark. "
    "You may edit only the explicitly allowed files. Return JSON only."
)
DEFAULT_ARTIFACTS_ROOT = REPO_ROOT / "tmp" / "llm_runs"


@dataclass(frozen=True)
class RunOptions:
    artifacts_root: Path = DEFAULT_ARTIFACTS_ROOT
    max_agent_iterations: int | None = None


def _utc_run_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _write_text(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(contents, encoding="utf-8")


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=4, sort_keys=True)
        handle.write("\n")


def _display_path(path: Path) -> str:
    resolved = path.resolve()
    repo_root_resolved = REPO_ROOT.resolve()
    try:
        return resolved.relative_to(repo_root_resolved).as_posix()
    except ValueError:
        return str(resolved)


def _safe_artifact_name(rel_path: str) -> str:
    return rel_path.replace("/", "__")


def _safe_path_component(value: str) -> str:
    sanitized = value.strip().replace("\\", "__").replace("/", "__")
    sanitized = re.sub(r"\s+", "_", sanitized)
    sanitized = sanitized.replace("..", "_")
    return sanitized or "unknown_model"


def _truncate(text: str, limit: int = 2000) -> str:
    stripped = text.strip()
    if len(stripped) <= limit:
        return stripped
    return stripped[:limit].rstrip() + "\n...[truncated]"


def _task_reference_file(task: BenchmarkTask) -> str | None:
    reference_file = task.task_dir / "ref.v"
    if reference_file.exists():
        return str(reference_file)
    return None


def _extract_code_blocks(text: str) -> list[tuple[str, str]]:
    pattern = re.compile(r"```([^\n`]*)\n(.*?)```", re.S)
    blocks = []
    for match in pattern.finditer(text):
        label = match.group(1).strip().lower()
        body = match.group(2).strip()
        blocks.append((label, body))
    return blocks


def extract_verilog_source(text: str) -> str:
    blocks = _extract_code_blocks(text)
    for label, body in blocks:
        if label in {"verilog", "systemverilog", "sv", "v"}:
            return body
    if blocks:
        return blocks[0][1]
    return text.strip()


def _extract_python_source(text: str) -> str:
    blocks = _extract_code_blocks(text)
    for label, body in blocks:
        if label in {"python", "py"}:
            return body
    if blocks:
        return blocks[0][1]
    return text.strip()


def _extract_json_candidate(text: str) -> str | None:
    stripped = text.strip()
    if stripped.startswith("{") and stripped.endswith("}"):
        return stripped

    for label, body in _extract_code_blocks(text):
        if label in {"json", ""}:
            body = body.strip()
            if body.startswith("{") and body.endswith("}"):
                return body

    start = text.find("{")
    while start != -1:
        depth = 0
        in_string = False
        escaped = False
        for index in range(start, len(text)):
            char = text[index]
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
                continue

            if char == '"':
                in_string = True
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return text[start:index + 1]
        start = text.find("{", start + 1)

    return None


def _load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} does not contain a JSON object.")
    return data


def _summarize_cdv_report(report: dict[str, Any]) -> str:
    lines = [
        f"Coverage: {float(report.get('coverage_percent', 0.0)):.2f}%",
        f"Target met: {'yes' if report.get('goal_met') else 'no'}",
        f"Tests passed: {'yes' if report.get('tests_passed') else 'no'}",
        f"Stable replay: {'yes' if report.get('stable') else 'no'}",
    ]

    uncovered_bins = report.get("coverage", {}).get("uncovered_bins", {})
    if uncovered_bins:
        lines.append("Uncovered bins:")
        for item_name, bins in uncovered_bins.items():
            lines.append(f"- {item_name}: {', '.join(bins)}")
    else:
        lines.append("Uncovered bins: none")

    failing_outputs = []
    for run_detail in report.get("runs", []):
        if run_detail.get("passed"):
            continue
        stderr = _truncate(str(run_detail.get("stderr", "")), limit=1000)
        stdout = _truncate(str(run_detail.get("stdout", "")), limit=1000)
        if stdout:
            failing_outputs.append(f"Run {run_detail.get('run_index')} stdout:\n{stdout}")
        if stderr:
            failing_outputs.append(f"Run {run_detail.get('run_index')} stderr:\n{stderr}")

    if failing_outputs:
        lines.append("Recent failures:")
        lines.extend(failing_outputs)

    return "\n".join(lines)


class BenchmarkRunner:
    def __init__(
        self,
        llm: OpenAICompatibleLLM,
        options: RunOptions | None = None,
    ):
        self.llm = llm
        self.options = options or RunOptions()

    def run(self, task_ref: str) -> dict[str, Any]:
        task = resolve_task(task_ref)
        run_dir = self._create_run_dir(task)

        if task.task_kind == "cdv":
            results = self._run_cdv_task(task, run_dir)
        elif task.task_kind == "spec_clarification":
            results = self._run_spec_clarification_task(task, run_dir)
        else:
            results = self._run_single_shot_rtl_task(task, run_dir)

        final_results = {
            "task_id": task.task_id,
            "task_kind": task.task_kind,
            "task_dir": task.relative_dir,
            "run_dir": _display_path(run_dir),
            "model": self.llm.config.model,
            **results,
        }
        _write_json(run_dir / "results.json", final_results)
        return final_results

    def _create_run_dir(self, task: BenchmarkTask) -> Path:
        model_dir = _safe_path_component(self.llm.config.model)
        base_dir = self.options.artifacts_root / model_dir / task.task_id
        run_dir = base_dir / _utc_run_id()
        counter = 1
        while run_dir.exists():
            counter += 1
            run_dir = base_dir / f"{_utc_run_id()}_{counter:02d}"
        run_dir.mkdir(parents=True, exist_ok=False)
        return run_dir

    def _run_single_shot_rtl_task(self, task: BenchmarkTask, run_dir: Path) -> dict[str, Any]:
        if task.tb_file is None:
            raise ValueError(f"RTL task {task.task_id} is missing tb.v.")

        prompt_text = task.input_file.read_text(encoding="utf-8")
        _write_text(run_dir / "prompt.txt", prompt_text)

        completion = self.llm.chat(
            [
                {"role": "system", "content": RTL_SYSTEM_PROMPT},
                {"role": "user", "content": prompt_text},
            ]
        )
        _write_text(run_dir / "response.txt", completion["text"])
        _write_json(run_dir / "response.json", completion["response"])

        solution_text = extract_verilog_source(completion["text"])
        solution_path = run_dir / "solution.v"
        _write_text(solution_path, solution_text + "\n")

        evaluation = evaluate_task(
            str(solution_path),
            str(task.tb_file),
            timing_spec_file=(
                str(task.timing_spec_file)
                if task.timing_spec_file is not None and task.timing_spec_file.exists()
                else None
            ),
            reference_verilog_file=_task_reference_file(task),
        )

        return {
            "benchmark_pass": bool(evaluation.get("benchmark_pass")),
            "evaluation": evaluation,
            "artifacts": {
                "prompt": _display_path(run_dir / "prompt.txt"),
                "response_text": _display_path(run_dir / "response.txt"),
                "response_json": _display_path(run_dir / "response.json"),
                "solution": _display_path(solution_path),
            },
        }

    def _run_spec_clarification_task(self, task: BenchmarkTask, run_dir: Path) -> dict[str, Any]:
        if task.tb_file is None or task.clarification_spec_file is None:
            raise ValueError(f"Clarification task {task.task_id} is missing required files.")

        original_prompt = task.input_file.read_text(encoding="utf-8")
        _write_text(run_dir / "prompt_original.txt", original_prompt)

        question_completion = self.llm.chat(
            [
                {"role": "system", "content": CLARIFICATION_SYSTEM_PROMPT},
                {"role": "user", "content": original_prompt},
            ]
        )
        _write_text(run_dir / "clarification_questions.txt", question_completion["text"])
        _write_json(run_dir / "clarification_response.json", question_completion["response"])

        clarification_results = evaluate_clarification_questions(
            str(run_dir / "clarification_questions.txt"),
            str(task.clarification_spec_file),
        )
        _write_text(run_dir / "clarification_answers.txt", clarification_results["answer_bundle"] + "\n")

        augmented_prompt = (
            original_prompt.rstrip()
            + "\n\n"
            + clarification_results["answer_bundle"].strip()
            + "\n"
        )
        _write_text(run_dir / "prompt_augmented.txt", augmented_prompt)

        rtl_completion = self.llm.chat(
            [
                {"role": "system", "content": RTL_SYSTEM_PROMPT},
                {"role": "user", "content": augmented_prompt},
            ]
        )
        _write_text(run_dir / "response.txt", rtl_completion["text"])
        _write_json(run_dir / "response.json", rtl_completion["response"])

        solution_text = extract_verilog_source(rtl_completion["text"])
        solution_path = run_dir / "solution.v"
        _write_text(solution_path, solution_text + "\n")

        evaluation = evaluate_task(
            str(solution_path),
            str(task.tb_file),
            reference_verilog_file=_task_reference_file(task),
            timing_spec_file=(
                str(task.timing_spec_file)
                if task.timing_spec_file is not None and task.timing_spec_file.exists()
                else None
            ),
        )

        return {
            "benchmark_pass": bool(evaluation.get("benchmark_pass")),
            "clarification": clarification_results,
            "evaluation": evaluation,
            "artifacts": {
                "prompt_original": _display_path(run_dir / "prompt_original.txt"),
                "clarification_questions": _display_path(run_dir / "clarification_questions.txt"),
                "clarification_answers": _display_path(run_dir / "clarification_answers.txt"),
                "prompt_augmented": _display_path(run_dir / "prompt_augmented.txt"),
                "response_text": _display_path(run_dir / "response.txt"),
                "response_json": _display_path(run_dir / "response.json"),
                "solution": _display_path(solution_path),
            },
        }

    def _run_cdv_task(self, task: BenchmarkTask, run_dir: Path) -> dict[str, Any]:
        workspace = run_dir / "workspace"
        prepare_process = self._run_subprocess(
            [
                sys.executable,
                str(REPO_ROOT / "domains" / "12_cdv" / "runner.py"),
                "prepare",
                task.task_id,
                str(workspace),
            ]
        )
        _write_text(run_dir / "prepare_stdout.txt", prepare_process["stdout"])
        _write_text(run_dir / "prepare_stderr.txt", prepare_process["stderr"])
        if prepare_process["returncode"] != 0:
            raise RuntimeError(
                "Failed to prepare CDV workspace:\n" + _truncate(prepare_process["stderr"], limit=2000)
            )

        editable_paths = [str(path) for path in task.metadata.get("editable_paths", [])]
        if not editable_paths:
            raise ValueError(f"CDV task {task.task_id} does not define editable_paths.")

        iteration_budget = int(task.metadata.get("iteration_budget", 0))
        if self.options.max_agent_iterations is not None:
            iteration_budget = min(iteration_budget, self.options.max_agent_iterations)

        if iteration_budget <= 0:
            raise ValueError("Iteration budget must be positive.")

        task_prompt = task.input_file.read_text(encoding="utf-8")
        history: list[dict[str, Any]] = []
        latest_report: dict[str, Any] | None = None

        for iteration in range(1, iteration_budget + 1):
            iteration_dir = run_dir / f"iteration_{iteration:02d}"
            iteration_dir.mkdir(parents=True, exist_ok=True)

            current_files = {
                rel_path: (workspace / rel_path).read_text(encoding="utf-8")
                for rel_path in editable_paths
            }
            prompt_text = self._build_cdv_prompt(
                task_prompt=task_prompt,
                editable_paths=editable_paths,
                current_files=current_files,
                latest_report=latest_report,
                iteration=iteration,
                iteration_budget=iteration_budget,
            )
            _write_text(iteration_dir / "prompt.txt", prompt_text)

            completion = self.llm.chat(
                [
                    {"role": "system", "content": CDV_AGENT_SYSTEM_PROMPT},
                    {"role": "user", "content": prompt_text},
                ]
            )
            _write_text(iteration_dir / "response.txt", completion["text"])
            _write_json(iteration_dir / "response.json", completion["response"])

            file_updates = self._parse_cdv_updates(
                completion["text"],
                editable_paths=editable_paths,
                current_files=current_files,
            )
            for rel_path, contents in file_updates.items():
                target_path = workspace / rel_path
                _write_text(target_path, contents.rstrip() + "\n")
                _write_text(
                    iteration_dir / f"{_safe_artifact_name(rel_path)}.txt",
                    contents.rstrip() + "\n",
                )

            run_process = self._run_subprocess(
                [
                    sys.executable,
                    str(REPO_ROOT / "domains" / "12_cdv" / "runner.py"),
                    "run",
                    str(workspace),
                ]
            )
            _write_text(iteration_dir / "runner_stdout.txt", run_process["stdout"])
            _write_text(iteration_dir / "runner_stderr.txt", run_process["stderr"])

            latest_report = self._load_latest_cdv_report(workspace)
            _write_json(iteration_dir / "report.json", latest_report)

            history.append(
                {
                    "iteration": iteration,
                    "runner_returncode": run_process["returncode"],
                    "goal_met": bool(latest_report.get("goal_met")),
                    "coverage_percent": float(latest_report.get("coverage_percent", 0.0)),
                    "tests_passed": bool(latest_report.get("tests_passed")),
                    "stable": bool(latest_report.get("stable")),
                    "artifacts": {
                        "prompt": _display_path(iteration_dir / "prompt.txt"),
                        "response_text": _display_path(iteration_dir / "response.txt"),
                        "response_json": _display_path(iteration_dir / "response.json"),
                        "runner_stdout": _display_path(iteration_dir / "runner_stdout.txt"),
                        "runner_stderr": _display_path(iteration_dir / "runner_stderr.txt"),
                        "report": _display_path(iteration_dir / "report.json"),
                    },
                }
            )

            if latest_report.get("goal_met"):
                break

        return {
            "benchmark_pass": bool(latest_report and latest_report.get("goal_met")),
            "workspace": _display_path(workspace),
            "iteration_budget": iteration_budget,
            "iterations_run": len(history),
            "goal_met": bool(latest_report and latest_report.get("goal_met")),
            "final_report": latest_report or {},
            "history": history,
        }

    def _build_cdv_prompt(
        self,
        *,
        task_prompt: str,
        editable_paths: list[str],
        current_files: dict[str, str],
        latest_report: dict[str, Any] | None,
        iteration: int,
        iteration_budget: int,
    ) -> str:
        sections = [
            f"Iteration {iteration} of {iteration_budget}.",
            "Task specification:",
            task_prompt.strip(),
            "",
            "Allowed editable files:",
            "\n".join(f"- {path}" for path in editable_paths),
            "",
            "Return JSON only with this schema:",
            '{"files": [{"path": "relative/path.py", "content": "full file contents"}], "summary": "optional"}',
            "",
            "Current editable file contents:",
        ]

        for rel_path, contents in current_files.items():
            sections.extend(
                [
                    f"File: {rel_path}",
                    "```python",
                    contents.rstrip(),
                    "```",
                ]
            )

        if latest_report is None:
            sections.extend(
                [
                    "",
                    "No prior run report is available yet. Improve the editable files to increase coverage without violating the benchmark rules.",
                ]
            )
        else:
            sections.extend(
                [
                    "",
                    "Latest run report:",
                    _summarize_cdv_report(latest_report),
                    "",
                    "Use the report to target uncovered behavior and keep the tests deterministic.",
                ]
            )

        return "\n".join(sections).strip() + "\n"

    def _parse_cdv_updates(
        self,
        raw_text: str,
        *,
        editable_paths: list[str],
        current_files: dict[str, str],
    ) -> dict[str, str]:
        json_candidate = _extract_json_candidate(raw_text)
        if json_candidate:
            try:
                payload = json.loads(json_candidate)
            except json.JSONDecodeError:
                payload = None
            if isinstance(payload, dict):
                if isinstance(payload.get("files"), list):
                    updates = {}
                    for item in payload["files"]:
                        if not isinstance(item, dict):
                            continue
                        path = item.get("path")
                        content = item.get("content")
                        if not isinstance(path, str) or not isinstance(content, str):
                            continue
                        if path not in editable_paths:
                            raise ValueError(
                                f"Model attempted to edit disallowed path '{path}'. "
                                f"Allowed paths: {', '.join(editable_paths)}"
                            )
                        updates[path] = content
                    if updates:
                        return updates

                direct_path = payload.get("path")
                direct_content = payload.get("content")
                if (
                    isinstance(direct_path, str)
                    and isinstance(direct_content, str)
                    and direct_path in editable_paths
                ):
                    return {direct_path: direct_content}

                if len(editable_paths) == 1:
                    implicit_content = payload.get("content")
                    if isinstance(implicit_content, str):
                        return {editable_paths[0]: implicit_content}
                    return {editable_paths[0]: current_files[editable_paths[0]]}

        if len(editable_paths) == 1:
            return {editable_paths[0]: _extract_python_source(raw_text) or current_files[editable_paths[0]]}

        raise ValueError("Could not parse editable file updates from the model response.")

    def _load_latest_cdv_report(self, workspace: Path) -> dict[str, Any]:
        state = _load_json(workspace / ".cdv" / "state.json")
        last_report = state.get("last_report")
        if not isinstance(last_report, str) or not last_report:
            raise FileNotFoundError(f"No CDV report was recorded in {workspace / '.cdv' / 'state.json'}.")
        report_path = workspace / last_report
        return _load_json(report_path)

    def _run_subprocess(self, command: list[str]) -> dict[str, Any]:
        process = subprocess.run(
            command,
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
        )
        return {
            "command": command,
            "returncode": process.returncode,
            "stdout": process.stdout,
            "stderr": process.stderr,
        }


def run_task(
    task_ref: str,
    *,
    model: str,
    api_key: str | None = None,
    base_url: str | None = None,
    temperature: float = 0.0,
    max_output_tokens: int | None = None,
    artifacts_root: str | Path | None = None,
    max_agent_iterations: int | None = None,
) -> dict[str, Any]:
    llm = OpenAICompatibleLLM(
        LLMConfig(
            model=model,
            api_key=api_key,
            base_url=base_url,
            temperature=temperature,
            max_output_tokens=max_output_tokens,
        )
    )
    options = RunOptions(
        artifacts_root=Path(artifacts_root) if artifacts_root is not None else DEFAULT_ARTIFACTS_ROOT,
        max_agent_iterations=max_agent_iterations,
    )
    return BenchmarkRunner(llm=llm, options=options).run(task_ref)
