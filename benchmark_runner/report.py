from __future__ import annotations

from dataclasses import dataclass
import html
import json
from pathlib import Path
import re
from typing import Any

from metrics.metrics import mean_pass_at_k

from .tasks import BenchmarkTask, list_tasks


DEFAULT_REPORT_ARTIFACTS_ROOT = Path("tmp") / "llm_runs"
FIRST_TABLE_METRICS = (
    ("syntax_correct", "syntax"),
    ("functionally_correct", "functional"),
    ("lint_clean", "lint"),
)
SECOND_TABLE_METRICS = (
    ("synth_check_passed", "synthesizable"),
    ("area_constraints_met", "area"),
    ("timing_constraints_met", "timing"),
)
MODULE_NAME_PATTERNS = (
    re.compile(r"\bmodule\s+([A-Za-z_][A-Za-z0-9_$]*)\b"),
    re.compile(r"\bnamed\s+`([A-Za-z_][A-Za-z0-9_$]*)`"),
)


@dataclass(frozen=True)
class RunSample:
    benchmark_pass: bool
    evaluation: dict[str, Any]
    path: Path
    sort_key: str


@dataclass(frozen=True)
class ReportTask:
    task_id: str
    label: str


def _load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError(f"{path} does not contain a JSON object.")
    return payload


def _task_module_name(task: BenchmarkTask) -> str | None:
    reference_file = task.task_dir / "ref.v"
    if reference_file.exists():
        reference_text = reference_file.read_text(encoding="utf-8")
        match = MODULE_NAME_PATTERNS[0].search(reference_text)
        if match:
            return match.group(1)

    title = task.title or ""
    for pattern in MODULE_NAME_PATTERNS[1:]:
        match = pattern.search(title)
        if match:
            return match.group(1)

    input_text = task.input_file.read_text(encoding="utf-8")
    for pattern in MODULE_NAME_PATTERNS[1:]:
        match = pattern.search(input_text)
        if match:
            return match.group(1)

    return None


def _task_label(task: BenchmarkTask) -> str:
    module_name = _task_module_name(task)
    if module_name:
        return f"{task.task_id} ({module_name})"
    return task.task_id


def _normalize_model_name(payload: dict[str, Any], path: Path, artifacts_root: Path) -> str:
    model = payload.get("model")
    if isinstance(model, str) and model.strip():
        return model.strip()

    try:
        relative_parts = path.relative_to(artifacts_root).parts
    except ValueError:
        relative_parts = path.parts

    if len(relative_parts) >= 4 and relative_parts[0] and not relative_parts[0].startswith("task_"):
        return relative_parts[0]

    return "unknown_model"


def _result_sort_key(payload: dict[str, Any], path: Path) -> str:
    run_dir = payload.get("run_dir")
    if isinstance(run_dir, str) and run_dir.strip():
        return run_dir.strip()
    return path.parent.as_posix()


def _discover_runs(artifacts_root: Path) -> dict[str, dict[str, list[RunSample]]]:
    discovered: dict[str, dict[str, list[RunSample]]] = {}
    if not artifacts_root.exists():
        return discovered

    for path in artifacts_root.rglob("results.json"):
        payload = _load_json(path)
        if payload.get("task_kind") == "cdv":
            continue

        task_id = payload.get("task_id")
        if not isinstance(task_id, str) or not task_id.strip():
            continue

        evaluation = payload.get("evaluation")
        if not isinstance(evaluation, dict):
            continue

        model = _normalize_model_name(payload, path, artifacts_root)
        sample = RunSample(
            benchmark_pass=bool(payload.get("benchmark_pass")),
            evaluation=evaluation,
            path=path,
            sort_key=_result_sort_key(payload, path),
        )
        discovered.setdefault(model, {}).setdefault(task_id, []).append(sample)

    for task_runs in discovered.values():
        for samples in task_runs.values():
            samples.sort(key=lambda item: (item.sort_key, item.path.as_posix()))

    return discovered


def _select_latest_runs(
    discovered: dict[str, dict[str, list[RunSample]]],
    sample_count: int,
) -> dict[str, dict[str, list[RunSample]]]:
    selected: dict[str, dict[str, list[RunSample]]] = {}
    for model, task_runs in discovered.items():
        selected[model] = {}
        for task_id, samples in task_runs.items():
            selected[model][task_id] = samples[-sample_count:] if sample_count < len(samples) else list(samples)
    return selected


def _build_report_tasks(task_ids: set[str]) -> list[ReportTask]:
    remaining = set(task_ids)
    report_tasks: list[ReportTask] = []

    for task in list_tasks():
        if task.task_kind == "cdv":
            continue
        if task.task_id not in remaining:
            continue
        report_tasks.append(ReportTask(task_id=task.task_id, label=_task_label(task)))
        remaining.remove(task.task_id)

    for task_id in sorted(remaining):
        report_tasks.append(ReportTask(task_id=task_id, label=task_id))

    return report_tasks


def _metric_pass_count(samples: list[RunSample], metric_key: str) -> int:
    return sum(1 for sample in samples if sample.evaluation.get(metric_key) is True)


def _render_table(
    *,
    tasks: list[ReportTask],
    models: list[str],
    selected_runs: dict[str, dict[str, list[RunSample]]],
    metrics: tuple[tuple[str, str], ...],
    include_pass_at_k: bool,
    pass_at_k_values: dict[str, float | None],
) -> str:
    lines = [
        "<table>",
        "  <thead>",
        "    <tr>",
        '      <th rowspan="2">task (top module)</th>',
    ]
    for model in models:
        lines.append(f'      <th colspan="{len(metrics)}">{html.escape(model)}</th>')
    lines.extend(
        [
            "    </tr>",
            "    <tr>",
        ]
    )
    for _model in models:
        for _metric_key, label in metrics:
            lines.append(f"      <th>{html.escape(label)}</th>")
    lines.extend(
        [
            "    </tr>",
            "  </thead>",
            "  <tbody>",
        ]
    )

    for task in tasks:
        lines.append("    <tr>")
        lines.append(f"      <td>{html.escape(task.label)}</td>")
        for model in models:
            task_samples = selected_runs.get(model, {}).get(task.task_id, [])
            for metric_key, _label in metrics:
                lines.append(f"      <td>{_metric_pass_count(task_samples, metric_key)}</td>")
        lines.append("    </tr>")

    if include_pass_at_k:
        lines.append("    <tr>")
        lines.append("      <td>pass@k</td>")
        for model in models:
            value = pass_at_k_values.get(model)
            rendered_value = "n/a" if value is None else f"{value:.4f}"
            lines.append(f'      <td colspan="{len(metrics)}">{rendered_value}</td>')
        lines.append("    </tr>")

    lines.extend(
        [
            "  </tbody>",
            "</table>",
        ]
    )
    return "\n".join(lines)


def generate_report(
    *,
    artifacts_root: str | Path = DEFAULT_REPORT_ARTIFACTS_ROOT,
    n: int = 3,
    k: int = 1,
) -> str:
    if n <= 0:
        raise ValueError("n must be positive.")
    if k <= 0:
        raise ValueError("k must be positive.")

    artifacts_root_path = Path(artifacts_root)
    discovered_runs = _discover_runs(artifacts_root_path)
    if not discovered_runs:
        return f"No benchmark results found under {artifacts_root_path.as_posix()}."

    selected_runs = _select_latest_runs(discovered_runs, n)
    models = sorted(selected_runs)
    task_ids = {
        task_id
        for task_runs in selected_runs.values()
        for task_id, samples in task_runs.items()
        if samples
    }
    if not task_ids:
        return f"No benchmark results found under {artifacts_root_path.as_posix()}."

    tasks = _build_report_tasks(task_ids)
    pass_at_k_values: dict[str, float | None] = {}
    for model in models:
        problems: list[tuple[int, int]] = []
        for task in tasks:
            task_samples = selected_runs.get(model, {}).get(task.task_id, [])
            if not task_samples:
                continue
            attempts = len(task_samples)
            successes = sum(1 for sample in task_samples if sample.benchmark_pass)
            problems.append((attempts, successes))
        pass_at_k_values[model] = mean_pass_at_k(problems, k) if problems else None

    latest_sample_count = max(len(samples) for task_runs in selected_runs.values() for samples in task_runs.values())
    subtitle = f"_latest samples per task = up to {n}, pass@{k}, observed max samples = {latest_sample_count}_"

    sections = [
        "### Syntax and functional correctness",
        subtitle,
        _render_table(
            tasks=tasks,
            models=models,
            selected_runs=selected_runs,
            metrics=FIRST_TABLE_METRICS,
            include_pass_at_k=True,
            pass_at_k_values=pass_at_k_values,
        ),
        "",
        "### Area and timing",
        subtitle,
        _render_table(
            tasks=tasks,
            models=models,
            selected_runs=selected_runs,
            metrics=SECOND_TABLE_METRICS,
            include_pass_at_k=False,
            pass_at_k_values=pass_at_k_values,
        ),
    ]
    return "\n".join(sections)
