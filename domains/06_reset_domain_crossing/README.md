# Domain 06: Reset Domain Crossing

This domain focuses on reset architecture correctness: asynchronous assertion, synchronous deassertion, and ordered release across multiple clock domains.

Tasks in this domain:
- `task_60`: `reset_sync_2ff` converts a global asynchronous reset into a local synchronously released reset.
- `task_61`: `ordered_reset_ctrl` sequences reset release across two asynchronous domains.
- `task_62`: `triple_reset_sequencer` extends ordered release to three domains.
- `task_63`: `delayed_reset_release` adds a programmable hold interval after synchronized deassertion.

Each task directory contains `input.txt`, `ref.v`, `flawed.v`, and `tb.v`.
