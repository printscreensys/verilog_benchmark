# Domain 09: Constraint-Aware Timing

This domain targets timing-aware RTL generation, where functional correctness alone is insufficient and the implementation must satisfy a surrogate timing budget.

Tasks in this domain:
- `task_90`: `dual_mac_timing` computes a dual multiply-accumulate result with a fixed latency and an associated timing surrogate.

In addition to the standard task artifacts, this domain includes `timing.json` for the timing-constraint surrogate check.
