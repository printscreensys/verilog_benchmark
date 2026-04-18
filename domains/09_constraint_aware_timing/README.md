# Domain 09: Constraint-Aware Timing

This domain targets timing-aware RTL generation, where functional correctness alone is insufficient and the implementation must satisfy real mapped area/timing limits.

Tasks in this domain:
- `task_90`: `dual_mac_timing` computes a dual multiply-accumulate result with a fixed latency and explicit Sky130-mapped area/timing constraints.

In addition to the standard task artifacts, this domain includes `timing.json` for real synthesis/STA metadata.
