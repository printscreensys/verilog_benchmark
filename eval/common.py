import os
from pathlib import Path


LOCALE_WARNING_FRAGMENTS = (
    "perl: warning:",
    "LC_ALL =",
    "LC_CTYPE =",
    "LANG =",
    "are supported and installed on your system.",
    "Falling back to the standard locale",
)


def clean_tool_output(raw_output):
    cleaned_lines = []
    for line in raw_output.splitlines():
        if any(fragment in line for fragment in LOCALE_WARNING_FRAGMENTS):
            continue
        cleaned_lines.append(line)
    return "\n".join(cleaned_lines).strip()


def resolve_task_dir(task_dir):
    if task_dir is None:
        return None

    candidate = Path(task_dir)
    if candidate.is_dir():
        return str(candidate)

    repo_root = Path(__file__).resolve().parent.parent
    repo_relative_candidate = repo_root / candidate
    if repo_relative_candidate.is_dir():
        return str(repo_relative_candidate)

    if candidate.name.startswith("task_"):
        domain_matches = sorted((repo_root / "domains").glob(f"*/{candidate.name}"))
        if len(domain_matches) == 1:
            return str(domain_matches[0])
        if len(domain_matches) > 1:
            raise ValueError(
                f"Task reference '{task_dir}' is ambiguous. Matches: "
                + ", ".join(str(match) for match in domain_matches)
            )

    return str(candidate)


def resolve_task_paths(task_dir):
    task_paths = {}
    if task_dir is None:
        return task_paths

    resolved_task_dir = resolve_task_dir(task_dir)
    task_paths["task_dir"] = resolved_task_dir
    task_paths["tb_file"] = os.path.join(resolved_task_dir, "tb.v")
    task_paths["clarification_spec_file"] = os.path.join(
        resolved_task_dir,
        "clarifications.json",
    )
    task_paths["timing_spec_file"] = os.path.join(resolved_task_dir, "timing.json")
    task_paths["reference_verilog_file"] = os.path.join(resolved_task_dir, "ref.v")
    return task_paths


def write_text_file(path, contents):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(contents)
