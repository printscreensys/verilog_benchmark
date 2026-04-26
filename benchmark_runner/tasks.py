from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml


REPO_ROOT = Path(__file__).resolve().parent.parent
DOMAINS_DIR = REPO_ROOT / "domains"
CDV_TASKS_DIR = DOMAINS_DIR / "12_cdv" / "tasks"


@dataclass
class BenchmarkTask:
    task_id: str
    task_kind: str
    task_dir: Path
    input_file: Path
    domain: str
    title: str | None = None
    tb_file: Path | None = None
    clarification_spec_file: Path | None = None
    timing_spec_file: Path | None = None
    description_rubric_file: Path | None = None
    metadata: dict[str, Any] = field(default_factory=dict)

    @property
    def relative_dir(self) -> str:
        return self.task_dir.relative_to(REPO_ROOT).as_posix()


def _load_yaml(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} does not contain a YAML object.")
    return data


def _first_nonempty_line(path: Path) -> str:
    with path.open("r", encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if line:
                return line
    return ""


def _task_from_dir(task_dir: Path) -> BenchmarkTask:
    input_file = task_dir / "input.txt"
    if not input_file.exists():
        raise FileNotFoundError(f"Task input file is missing: {input_file}")

    clarification_spec_file = task_dir / "clarifications.json"
    timing_spec_file = task_dir / "timing.json"
    description_rubric_file = task_dir / "description_rubric.json"
    task_yaml_file = task_dir / "task.yaml"
    tb_file = task_dir / "tb.v"

    if task_yaml_file.exists():
        metadata = _load_yaml(task_yaml_file)
        task_kind = str(metadata.get("kind") or "cdv")
        return BenchmarkTask(
            task_id=str(metadata.get("id") or task_dir.name),
            task_kind=task_kind,
            task_dir=task_dir,
            input_file=input_file,
            domain=task_dir.parent.parent.name if task_kind == "cdv" else task_dir.parent.name,
            title=str(metadata.get("title") or task_dir.name),
            metadata=metadata,
        )

    input_text = input_file.read_text(encoding="utf-8")
    if "FILL_MISSING_SECTION" in input_text:
        task_kind = "code_completion"
    elif description_rubric_file.exists():
        task_kind = "rtl_description"
    elif clarification_spec_file.exists():
        task_kind = "spec_clarification"
    else:
        task_kind = "rtl_generation"

    return BenchmarkTask(
        task_id=task_dir.name,
        task_kind=task_kind,
        task_dir=task_dir,
        input_file=input_file,
        domain=task_dir.parent.name,
        title=_first_nonempty_line(input_file),
        tb_file=tb_file if tb_file.exists() else None,
        clarification_spec_file=clarification_spec_file if clarification_spec_file.exists() else None,
        timing_spec_file=timing_spec_file if timing_spec_file.exists() else None,
        description_rubric_file=description_rubric_file if description_rubric_file.exists() else None,
    )


def discover_task_dirs() -> list[Path]:
    task_dirs = sorted(
        path
        for path in DOMAINS_DIR.glob("*/task_*")
        if path.is_dir() and path.parent.name != "12_cdv"
    )

    if CDV_TASKS_DIR.exists():
        task_dirs.extend(sorted(path for path in CDV_TASKS_DIR.glob("task_*") if path.is_dir()))

    return task_dirs


def list_tasks() -> list[BenchmarkTask]:
    return [_task_from_dir(task_dir) for task_dir in discover_task_dirs()]


def resolve_task(task_ref: str) -> BenchmarkTask:
    candidate = Path(task_ref)
    search_candidates: list[Path] = []

    if candidate.is_dir():
        search_candidates.append(candidate.resolve())
    else:
        repo_relative = REPO_ROOT / candidate
        if repo_relative.is_dir():
            search_candidates.append(repo_relative.resolve())

    if not search_candidates:
        standard_matches = sorted(
            path.resolve()
            for path in DOMAINS_DIR.glob(f"*/{candidate.name}")
            if path.is_dir() and path.parent.name != "12_cdv"
        )
        cdv_match = CDV_TASKS_DIR / candidate.name
        if cdv_match.is_dir():
            standard_matches.append(cdv_match.resolve())

        if not standard_matches:
            raise FileNotFoundError(f"Could not resolve task '{task_ref}'.")

        if len(standard_matches) > 1:
            match_list = ", ".join(str(path) for path in standard_matches)
            raise ValueError(f"Task reference '{task_ref}' is ambiguous: {match_list}")

        search_candidates = standard_matches

    return _task_from_dir(search_candidates[0])
