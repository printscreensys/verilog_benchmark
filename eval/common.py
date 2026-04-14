import os


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


def resolve_task_paths(task_dir):
    task_paths = {}
    if task_dir is None:
        return task_paths

    task_paths["tb_file"] = os.path.join(task_dir, "tb.v")
    task_paths["clarification_spec_file"] = os.path.join(task_dir, "clarifications.json")
    task_paths["timing_spec_file"] = os.path.join(task_dir, "timing.json")
    return task_paths


def write_text_file(path, contents):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(contents)
