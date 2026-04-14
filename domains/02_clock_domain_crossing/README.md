# Domain 02: Clock Domain Crossing

This domain evaluates CDC-safe data transfer patterns, especially cases where naive multi-bit synchronization would create incoherent samples.

Tasks in this domain:
- `task_24`: `cdc_bus_sync` transfers a 16-bit bus across asynchronous domains using a synchronized control event plus destination-side capture.

Each task directory contains `input.txt`, `ref.v`, `flawed.v`, and `tb.v`.
