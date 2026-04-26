# Domain 04: Chiplet / Die-to-Die Integration

This domain tests chiplet wrapper logic rather than core computation, with emphasis on die-to-die framing, sequencing, and backpressure handling.

Tasks in this domain:
- `task_41`: `ucie_flit_packager` wraps SoC payloads into UCIe-style flits with transfer-qualified sequence tracking.
- `task_131`: `alloc_two` is a VerilogDB-derived NoC/flit channel allocator with route-based output selection and backpressure.

Each RTL-generation task directory contains `input.txt`, `ref.v`, and `tb.v`.
Some older tasks also include `flawed.v`.
