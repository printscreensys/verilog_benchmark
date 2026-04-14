# Domain 10: Fault-Tolerant Safety

This domain benchmarks RTL that must continue operating safely under injected faults, with explicit error detection, containment, and sticky fault signaling.

Tasks in this domain:
- `task_100`: `ecc_guarded_byte` protects a byte-wide storage element with SECDED-style behavior.
- `task_101`: `lockstep_event_counter` uses redundant lockstep state and mismatch detection to halt on corruption.

Each task directory contains `input.txt`, `ref.v`, `flawed.v`, and `tb.v`.
