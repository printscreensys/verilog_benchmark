#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

THIS_FILE = Path(__file__).resolve()
VENV_SITE_PACKAGES = (
    THIS_FILE.parent.parent
    / ".venv"
    / "lib"
    / f"python{sys.version_info.major}.{sys.version_info.minor}"
    / "site-packages"
)
if VENV_SITE_PACKAGES.exists() and str(VENV_SITE_PACKAGES) not in sys.path:
    sys.path.insert(0, str(VENV_SITE_PACKAGES))

import yaml


SCRIPT_DIR = THIS_FILE.parent
REPO_ROOT = SCRIPT_DIR.parent
TASKS_DIR = SCRIPT_DIR / "tasks"
STATE_DIR_NAME = ".cdv"


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_yaml(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} did not contain a YAML object.")
    return data


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise ValueError(f"{path} did not contain a JSON object.")
    return data


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def assert_within_workspace(workspace: Path, candidate: Path) -> None:
    workspace_resolved = workspace.resolve()
    candidate_resolved = candidate.resolve()
    if candidate_resolved != workspace_resolved and workspace_resolved not in candidate_resolved.parents:
        raise ValueError(f"{candidate} escapes workspace {workspace}.")


def expand_configured_paths(workspace: Path, rel_paths: list[str]) -> list[Path]:
    expanded: list[Path] = []
    for rel_path in rel_paths:
        candidate = workspace / rel_path
        assert_within_workspace(workspace, candidate)
        if not candidate.exists():
            raise FileNotFoundError(f"Configured path does not exist: {candidate}")
        if candidate.is_dir():
            expanded.extend(sorted(path for path in candidate.rglob("*") if path.is_file()))
        else:
            expanded.append(candidate)
    return sorted(set(expanded))


def resolve_task_dir(task_name: str) -> Path:
    task_dir = TASKS_DIR / task_name
    if not task_dir.is_dir():
        available = ", ".join(sorted(path.name for path in TASKS_DIR.iterdir() if path.is_dir()))
        raise FileNotFoundError(f"Unknown task '{task_name}'. Available tasks: {available}")
    return task_dir


def load_task_config(task_root: Path) -> dict[str, Any]:
    config = load_yaml(task_root / "task.yaml")
    required_keys = [
        "id",
        "title",
        "coverage_root",
        "iteration_budget",
        "stability_runs",
        "timeout_sec",
        "goal",
        "editable_paths",
        "protected_paths",
    ]
    missing = [key for key in required_keys if key not in config]
    if missing:
        raise ValueError(f"Task config {task_root / 'task.yaml'} is missing keys: {', '.join(missing)}")
    return config


def compute_protected_hashes(workspace: Path, config: dict[str, Any]) -> dict[str, str]:
    protected_files = expand_configured_paths(workspace, list(config["protected_paths"]))
    hashes: dict[str, str] = {}
    for path in protected_files:
        rel_path = path.relative_to(workspace).as_posix()
        hashes[rel_path] = sha256_file(path)
    return hashes


def verify_protected_files(workspace: Path, state: dict[str, Any]) -> list[str]:
    mismatches: list[str] = []
    for rel_path, expected_hash in sorted(state["protected_hashes"].items()):
        candidate = workspace / rel_path
        if not candidate.exists():
            mismatches.append(f"Protected file is missing: {rel_path}")
            continue
        actual_hash = sha256_file(candidate)
        if actual_hash != expected_hash:
            mismatches.append(f"Protected file was modified: {rel_path}")
    return mismatches


def scan_for_forbidden_text(workspace: Path, config: dict[str, Any]) -> list[str]:
    violations: list[str] = []
    forbidden_patterns = list(config.get("forbidden_text", []))
    if not forbidden_patterns:
        return violations
    for rel_path in config["editable_paths"]:
        candidate = workspace / rel_path
        text = candidate.read_text(encoding="utf-8")
        for pattern in forbidden_patterns:
            if pattern in text:
                violations.append(f"{rel_path} contains forbidden text: {pattern}")
    return violations


def default_python_bin() -> Path:
    candidate = REPO_ROOT / ".venv" / "bin" / "python"
    if candidate.exists():
        return candidate
    return Path(sys.executable)


def parse_coverage_report(path: Path, root_name: str) -> dict[str, Any]:
    if not path.exists():
        return {
            "root": root_name,
            "coverage_percent": 0.0,
            "coverage": 0,
            "size": 0,
            "items": [],
            "uncovered_bins": {},
        }

    data = load_yaml(path)
    root_node = data.get(root_name)
    if not isinstance(root_node, dict):
        raise ValueError(f"Coverage report {path} does not contain root node '{root_name}'.")

    items: list[dict[str, Any]] = []
    uncovered_bins: dict[str, list[str]] = {}

    for name, node in sorted(data.items()):
        if name == root_name or not name.startswith(f"{root_name}."):
            continue
        if not isinstance(node, dict):
            continue

        bins = node.get("bins:_hits", {}) or {}
        at_least = int(node.get("at_least", 1))
        missing_bins = sorted(str(bin_name) for bin_name, hits in bins.items() if int(hits) < at_least)
        item = {
            "name": name,
            "coverage_percent": float(node.get("cover_percentage", 0.0)),
            "coverage": int(node.get("coverage", 0)),
            "size": int(node.get("size", 0)),
            "missing_bins": missing_bins,
        }
        items.append(item)
        if missing_bins:
            uncovered_bins[name] = missing_bins

    return {
        "root": root_name,
        "coverage_percent": float(root_node.get("cover_percentage", 0.0)),
        "coverage": int(root_node.get("coverage", 0)),
        "size": int(root_node.get("size", 0)),
        "items": items,
        "uncovered_bins": uncovered_bins,
    }


def coverage_fingerprint(summary: dict[str, Any]) -> str:
    payload = {
        "coverage_percent": round(float(summary["coverage_percent"]), 4),
        "items": [
            {
                "name": item["name"],
                "coverage_percent": round(float(item["coverage_percent"]), 4),
                "missing_bins": list(item["missing_bins"]),
            }
            for item in summary["items"]
        ],
    }
    return json.dumps(payload, sort_keys=True)


def parse_results_file(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {
            "results_written": False,
            "tests_passed": False,
            "failures": 0,
            "errors": 0,
        }

    tree = ET.parse(path)
    root = tree.getroot()
    failures = len(root.findall(".//failure"))
    errors = len(root.findall(".//error"))
    return {
        "results_written": True,
        "tests_passed": failures == 0 and errors == 0,
        "failures": failures,
        "errors": errors,
    }


def run_make_once(
    workspace: Path,
    config: dict[str, Any],
    iteration_dir: Path,
    run_index: int,
    python_bin: Path,
) -> dict[str, Any]:
    run_dir = iteration_dir / f"run_{run_index:02d}"
    run_dir.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["PATH"] = f"{python_bin.parent}{os.pathsep}{env.get('PATH', '')}"
    env["CDV_COVERAGE_FILE"] = str(run_dir / "coverage.yaml")
    env["COCOTB_REDUCED_LOG_FMT"] = "1"
    env["VIRTUAL_ENV"] = str(python_bin.parent.parent)
    env.pop("PYTHONHOME", None)
    results_path = run_dir / "results.xml"

    command = [
        "make",
        "SIM=icarus",
        f"PYTHON_BIN={python_bin}",
        f"SIM_BUILD={run_dir / 'sim_build'}",
        f"COCOTB_RESULTS_FILE={results_path}",
    ]

    try:
        process = subprocess.run(
            command,
            cwd=workspace,
            env=env,
            capture_output=True,
            text=True,
            timeout=int(config["timeout_sec"]),
        )
        timed_out = False
        stdout = process.stdout
        stderr = process.stderr
        return_code = process.returncode
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        stdout = exc.stdout or ""
        stderr = exc.stderr or ""
        return_code = 124

    coverage_summary = parse_coverage_report(run_dir / "coverage.yaml", str(config["coverage_root"]))
    test_results = parse_results_file(results_path)

    return {
        "run_index": run_index,
        "command": " ".join(str(part) for part in command),
        "timed_out": timed_out,
        "return_code": return_code,
        "passed": return_code == 0 and not timed_out and bool(test_results["tests_passed"]),
        "test_results": test_results,
        "stdout": stdout,
        "stderr": stderr,
        "coverage": coverage_summary,
    }


def build_iteration_report(
    config: dict[str, Any],
    iteration_number: int,
    run_details: list[dict[str, Any]],
) -> dict[str, Any]:
    goal = float(config["goal"]["coverage_percent"])
    all_passed = all(detail["passed"] for detail in run_details)
    effective_run = min(run_details, key=lambda detail: detail["coverage"]["coverage_percent"])
    coverage_match = len({coverage_fingerprint(detail["coverage"]) for detail in run_details}) == 1
    stable = all_passed and coverage_match
    flaky_penalty = float(config.get("scoring", {}).get("flaky_penalty", 0.0)) if not stable else 0.0

    if all_passed:
        raw_score = float(effective_run["coverage"]["coverage_percent"])
        final_score = max(0.0, raw_score - flaky_penalty)
    else:
        raw_score = 0.0
        final_score = 0.0

    effective_coverage = effective_run["coverage"]
    goal_met = all_passed and stable and float(effective_coverage["coverage_percent"]) >= goal

    report = {
        "iteration": iteration_number,
        "goal_percent": goal,
        "tests_passed": all_passed,
        "stable": stable,
        "coverage_percent": float(effective_coverage["coverage_percent"]),
        "raw_score": raw_score,
        "score": final_score,
        "goal_met": goal_met,
        "penalties": [],
        "coverage": effective_coverage,
        "runs": run_details,
    }
    if flaky_penalty:
        report["penalties"].append(
            {
                "name": "flaky_or_nondeterministic_replay",
                "points": flaky_penalty,
            }
        )
    return report


def print_iteration_summary(report: dict[str, Any], report_path: Path) -> None:
    print(f"Iteration {report['iteration']}")
    print(f"Coverage: {report['coverage_percent']:.2f}% / target {report['goal_percent']:.2f}%")
    print(f"Tests passed: {'yes' if report['tests_passed'] else 'no'}")
    print(f"Stable replay: {'yes' if report['stable'] else 'no'}")
    if report["penalties"]:
        penalty = report["penalties"][0]
        print(f"Penalty: {penalty['name']} (-{penalty['points']:.2f})")
    print(f"Score: {report['score']:.2f}")
    uncovered = report["coverage"]["uncovered_bins"]
    if uncovered:
        print("Uncovered bins:")
        for item_name, bins in uncovered.items():
            print(f"  {item_name}: {', '.join(bins)}")
    else:
        print("Uncovered bins: none")
    print(f"Report: {report_path}")


def prepare_workspace(task_name: str, workspace: Path, force: bool) -> int:
    task_dir = resolve_task_dir(task_name)
    if workspace.exists():
        if not force:
            raise FileExistsError(f"Workspace already exists: {workspace}")
        shutil.rmtree(workspace)

    shutil.copytree(task_dir, workspace)
    config = load_task_config(workspace)
    state = {
        "task_id": config["id"],
        "task_title": config["title"],
        "prepared_at": now_iso(),
        "iteration_budget": int(config["iteration_budget"]),
        "iterations_used": 0,
        "editable_paths": list(config["editable_paths"]),
        "protected_paths": list(config["protected_paths"]),
        "protected_hashes": compute_protected_hashes(workspace, config),
        "last_report": None,
    }
    write_json(workspace / STATE_DIR_NAME / "state.json", state)

    print(f"Prepared {config['id']} at {workspace}")
    print(f"Editable files: {', '.join(config['editable_paths'])}")
    print(f"Run with: python3 cdv_benchmark/runner.py run {workspace}")
    return 0


def run_workspace(workspace: Path) -> int:
    config = load_task_config(workspace)
    state_path = workspace / STATE_DIR_NAME / "state.json"
    if not state_path.exists():
        raise FileNotFoundError(f"Workspace is not prepared: {workspace}")
    state = load_json(state_path)

    if int(state["iterations_used"]) >= int(state["iteration_budget"]):
        print("Iteration budget exhausted.")
        return 2

    protection_errors = verify_protected_files(workspace, state)
    if protection_errors:
        for message in protection_errors:
            print(message, file=sys.stderr)
        return 3

    shortcut_errors = scan_for_forbidden_text(workspace, config)
    if shortcut_errors:
        for message in shortcut_errors:
            print(message, file=sys.stderr)
        return 4

    next_iteration = int(state["iterations_used"]) + 1
    iteration_dir = workspace / STATE_DIR_NAME / "reports" / f"iteration_{next_iteration:02d}"
    iteration_dir.mkdir(parents=True, exist_ok=True)

    python_bin = default_python_bin()
    run_details = [
        run_make_once(workspace, config, iteration_dir, run_index, python_bin)
        for run_index in range(1, int(config["stability_runs"]) + 1)
    ]
    report = build_iteration_report(config, next_iteration, run_details)
    report["created_at"] = now_iso()
    report_path = iteration_dir / "report.json"
    write_json(report_path, report)

    state["iterations_used"] = next_iteration
    state["last_report"] = report_path.relative_to(workspace).as_posix()
    write_json(state_path, state)

    print_iteration_summary(report, report_path)
    return 0 if report["tests_passed"] else 5


def status_workspace(workspace: Path) -> int:
    config = load_task_config(workspace)
    state = load_json(workspace / STATE_DIR_NAME / "state.json")
    remaining = int(state["iteration_budget"]) - int(state["iterations_used"])
    print(f"Task: {config['id']} - {config['title']}")
    print(f"Iterations used: {state['iterations_used']}/{state['iteration_budget']}")
    print(f"Iterations remaining: {remaining}")
    print(f"Coverage target: {float(config['goal']['coverage_percent']):.2f}%")
    if state.get("last_report"):
        report_path = workspace / state["last_report"]
        if report_path.exists():
            report = load_json(report_path)
            print(f"Last score: {float(report['score']):.2f}")
            print(f"Last coverage: {float(report['coverage_percent']):.2f}%")
            print(f"Last stable replay: {'yes' if report['stable'] else 'no'}")
            print(f"Last report: {report_path}")
    return 0


def list_tasks() -> int:
    for task_dir in sorted(path for path in TASKS_DIR.iterdir() if path.is_dir()):
        config = load_task_config(task_dir)
        print(f"{task_dir.name}: {config['title']}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Coverage-driven verification benchmark runner.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list", help="List available CDV tasks.")
    list_parser.set_defaults(handler=lambda args: list_tasks())

    prepare_parser = subparsers.add_parser("prepare", help="Copy a task template into a workspace.")
    prepare_parser.add_argument("task_name", help="Task directory name under cdv_benchmark/tasks.")
    prepare_parser.add_argument("workspace", help="Workspace path to create.")
    prepare_parser.add_argument("--force", action="store_true", help="Overwrite an existing workspace.")
    prepare_parser.set_defaults(
        handler=lambda args: prepare_workspace(args.task_name, Path(args.workspace).resolve(), args.force)
    )

    run_parser = subparsers.add_parser("run", help="Execute one CDV iteration in an existing workspace.")
    run_parser.add_argument("workspace", help="Prepared workspace path.")
    run_parser.set_defaults(handler=lambda args: run_workspace(Path(args.workspace).resolve()))

    status_parser = subparsers.add_parser("status", help="Show workspace budget and last report.")
    status_parser.add_argument("workspace", help="Prepared workspace path.")
    status_parser.set_defaults(handler=lambda args: status_workspace(Path(args.workspace).resolve()))

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return int(args.handler(args))
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
