# Iterative Agentic Benchmark

This directory adds agentic benchmark tasks on top of the existing single-shot
RTL tasks. The command API remains `prepare`, `run`, and `status`.

Tasks share the same workspace structure: protected RTL, protected coverage
model/harness/support files, and one editable `tests/test_sequences.py` file.
Some tasks stimulate a simulated DUT; others close analysis-objective coverage
by recording evidence found in protected RTL.

## Workflow

1. Prepare a writable workspace from a task template:

```bash
python3 domains/12_cdv/runner.py prepare task_121 tmp/cdv_queue_credit
```

2. Edit only the task's allowed file:

```text
tmp/cdv_queue_credit/tests/test_sequences.py
```

3. Run one coverage-closure iteration:

```bash
python3 domains/12_cdv/runner.py run tmp/cdv_queue_credit
```

4. Inspect the generated report:

```text
tmp/cdv_queue_credit/.cdv/reports/iteration_01/report.json
```

5. Check remaining budget:

```bash
python3 domains/12_cdv/runner.py status tmp/cdv_queue_credit
```

## Runner Behavior

- Copies a task template into an isolated workspace.
- Enforces anti-shortcut rules:
  - only configured editable files may change
  - protected files are hash-checked before every run
  - editable files are scanned for forbidden coverage shortcuts
- Runs the task-local Makefile twice per iteration to detect flaky or
  nondeterministic tests.
- Scores the iteration with:
  - achieved functional coverage
  - a stability penalty if replayed runs disagree
  - zero score if the test itself fails

## Sample Tasks

`task_121` provides:

- A protected Verilog DUT with corner-case behavior.
- A protected cocotb harness and `cocotb-coverage` model.
- One weak editable baseline sequence file.
- A target of `>= 90%` coverage within `6` iterations.

VerilogDB-derived agentic tasks:

- `task_122`: `alloc_two` static RTL analysis.
- `task_123`: `top_dec` router pipeline analysis.
- `task_124`: `smii_txrx` protocol analysis.
- `task_125`: `bch_sigma_bma_serial` dependency/algorithm analysis.

These tasks use the same file layout as `task_121`, but their harnesses inspect
protected RTL and sample coverage objectives from observed source evidence
instead of running a full Verilog simulation.
