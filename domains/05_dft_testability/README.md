# Domain 05: DFT and Testability

This domain benchmarks design-for-test RTL patterns that are common in production flows but largely absent from LLM RTL benchmarks.

Tasks in this domain:
- `task_50`: `scan_reg8` implements a scan-friendly register with functional and scan-mode behavior.
- `task_51`: `scan_reset_override_reg` exercises test-mode reset override handling.
- `task_52`: `jtag_tap_debug` implements a minimal JTAG TAP controller for debug register access.
- `task_53`: `mbist_ram_wrapper` adds MBIST control hooks around a tiny RAM.

Each task directory contains `input.txt`, `ref.v`, `flawed.v`, and `tb.v`.
