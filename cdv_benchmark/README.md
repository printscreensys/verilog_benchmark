# Coverage-Driven Verification Benchmark

This directory adds an agentic coverage-closure benchmark flow on top of the
existing single-shot RTL tasks.

## Workflow

1. Prepare a writable workspace from a task template:

```bash
python3 cdv_benchmark/runner.py prepare task_01_queue_credit tmp/cdv_queue_credit
```

2. Edit only the task's allowed file:

```text
tmp/cdv_queue_credit/tests/test_sequences.py
```

3. Run one coverage-closure iteration:

```bash
python3 cdv_benchmark/runner.py run tmp/cdv_queue_credit
```

4. Inspect the generated report:

```text
tmp/cdv_queue_credit/.cdv/reports/iteration_01/report.json
```

5. Check remaining budget:

```bash
python3 cdv_benchmark/runner.py status tmp/cdv_queue_credit
```

## Runner Behavior

- Copies a task template into an isolated workspace.
- Enforces anti-shortcut rules:
  - only configured editable files may change
  - protected files are hash-checked before every run
  - editable files are scanned for forbidden coverage shortcuts
- Runs the cocotb test twice per iteration to detect flaky or nondeterministic
  tests.
- Scores the iteration with:
  - achieved functional coverage
  - a stability penalty if replayed runs disagree
  - zero score if the test itself fails

## Sample Task

`task_01_queue_credit` provides:

- A protected Verilog DUT with corner-case behavior.
- A protected cocotb harness and `cocotb-coverage` model.
- One weak editable baseline sequence file.
- A target of `>= 90%` coverage within `6` iterations.
