# Domain 03: Low-Power Design

This domain covers power-aware RTL generation, including UPF-friendly partitioning and sleep-mode behavior that suppresses unnecessary activity.

Tasks in this domain:
- `task_34`: `soc_top` models a multi-power-domain SoC shell with always-on control and UPF-facing hooks.
- `task_40`: `power_aware_fsm` adds a sleep state and clock-gating control to a sequence detector.
- `task_130`: `or1200_pm` is a VerilogDB-derived OR1200 power-management register and gate-control block.

Each RTL-generation task directory contains `input.txt`, `ref.v`, and `tb.v`.
Some older tasks also include `flawed.v`.
