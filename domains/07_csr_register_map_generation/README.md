# Domain 07: CSR / Register-Map Generation

This domain evaluates structured-spec-to-RTL translation for APB and AXI-Lite control/status register blocks, including field semantics and side effects.

Tasks in this domain:
- `task_70`: `apb_timer_csr` implements an APB timer control block from a register map.
- `task_71`: `apb_lock_cfg` implements an APB configuration block with locking behavior.
- `task_72`: `axil_sensor_csr` implements an AXI4-Lite CSR block from a JSON specification.
- `task_73`: `apb_sample_csr` implements an APB CSR block from a YAML specification.

Each task directory contains `input.txt`, `ref.v`, `flawed.v`, and `tb.v`.
