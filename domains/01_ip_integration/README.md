# Domain 01: IP Integration

This domain focuses on glue logic that connects existing interfaces correctly under backpressure, width conversion, and protocol translation constraints.

Tasks in this domain:
- `task_11`: `axi2apb_write_bridge` converts AXI4-Lite write traffic into an APB4 write transaction.
- `task_12`: `width_upsizer` packs two 32-bit stream beats into one 64-bit output beat.

Each task directory contains `input.txt`, `ref.v`, `flawed.v`, and `tb.v`.
