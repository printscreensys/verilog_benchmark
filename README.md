# Verilog Benchmark

Benchmark tasks and evaluation utilities for a thesis on LLMs in RTL generation.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp env.example .env
```

`benchmark_runner` uses an OpenAI-compatible API. Put your API key and base URL
in `.env` if you want to run tasks through a model.

## Environment Variables

Example values are in `env.example`.

Recommended variables:

- `BENCH_LLM_API_KEY`
- `BENCH_LLM_BASE_URL`

Fallback variable names also supported by the runner:

- `LLM_API_KEY`
- `OPENAI_API_KEY`
- `GROQ_API_KEY`
- `LLM_BASE_URL`
- `OPENAI_BASE_URL`

The model name is passed on the command line, not through `.env`.

## Run A Specific Test

To evaluate a single non-agentic benchmark task, run `eval` with the candidate
Verilog file and the task directory. The candidate file can be `ref.v`,
`flawed.v`, or your generated output.

Golden reference example:

```bash
.venv/bin/python -m eval domains/00_security_vulnerability_detection/task_01/ref.v --task-dir task_01
```

Flawed implementation example:

```bash
.venv/bin/python -m eval domains/00_security_vulnerability_detection/task_06/flawed.v --task-dir task_06
```

Your generated file example:

```bash
.venv/bin/python -m eval tmp/output.v --task-dir task_01
```

## Run All Tests

The command below evaluates every standard task that has both `ref.v` and
`tb.v`. It prints `PASS` or `FAIL` for each task and a final failure count.

```bash
.venv/bin/python - <<'PY'
import subprocess
from pathlib import Path

python_bin = ".venv/bin/python"
failed = []

for task_dir in sorted(Path("domains").glob("*/task_*")):
    if not (task_dir / "ref.v").exists():
        continue
    if not (task_dir / "tb.v").exists():
        continue

    cmd = [python_bin, "-m", "eval", str(task_dir / "ref.v"), "--task-dir", str(task_dir)]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    ok = proc.returncode == 0 and '"benchmark_pass": true' in proc.stdout
    print(f"{task_dir.name}: {'PASS' if ok else 'FAIL'}")
    if not ok:
        failed.append(task_dir.as_posix())

print(f"FAILED {len(failed)}")
PY
```

This sweep covers the standard `tb.v`-based tasks. Agentic CDV tasks use a
separate workflow.

RTL-to-NL description tasks use the same `benchmark_runner run` command as
single-shot tasks and are scored with a rubric instead of a Verilog testbench.

Code-completion tasks are also single-shot tasks. Their prompts contain a
Verilog skeleton with a `FILL_MISSING_SECTION` marker, and evaluation checks the
completed module against a focused testbench for that missing section.

## Run Agentic CDV Tasks

Prepare a writable workspace:

```bash
.venv/bin/python domains/12_cdv/runner.py prepare task_121 tmp/cdv_queue_credit
```

Run one CDV iteration:

```bash
.venv/bin/python domains/12_cdv/runner.py run tmp/cdv_queue_credit
```

Check status:

```bash
.venv/bin/python domains/12_cdv/runner.py status tmp/cdv_queue_credit
```

## Run A Task Through An LLM API

List available tasks:

```bash
.venv/bin/python -m benchmark_runner list
```

Run a single task through an OpenAI-compatible API:

```bash
.venv/bin/python -m benchmark_runner run task_80 --model mistral-medium-latest
```

Results, prompts, model responses, generated files, and reports are written
under `tmp/llm_runs/`.

## Generate A Markdown Report

Generate a Markdown summary from the latest benchmark runs:

```bash
.venv/bin/python -m benchmark_runner report --n 3 --k 1
```

This scans `tmp/llm_runs/`, groups runs by model, counts metric passes from the
latest `n` attempts per task, adds a mean `pass@k` row for each model, and
writes the markdown report to `reports/report_<timestamp>.md`. Use `--output`
to override the default path.
