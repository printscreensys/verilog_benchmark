# Domain 04: Chiplet / Die-to-Die Integration

This domain tests chiplet wrapper logic rather than core computation, with emphasis on die-to-die framing, sequencing, and backpressure handling.

Tasks in this domain:
- `task_41`: `ucie_flit_packager` wraps SoC payloads into UCIe-style flits with transfer-qualified sequence tracking.

Each task directory contains `input.txt`, `ref.v`, `flawed.v`, and `tb.v`.
