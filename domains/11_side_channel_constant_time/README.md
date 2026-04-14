# Domain 11: Side-Channel Constant-Time

This domain evaluates constant-latency, no-early-exit RTL patterns that reduce obvious timing side channels in security-sensitive logic.

Tasks in this domain:
- `task_110`: `consttime_word_compare` compares two words using a fixed four-cycle schedule.
- `task_111`: `consttime_byte_search` scans all byte positions over a fixed eight-cycle schedule.

Each task directory contains `input.txt`, `ref.v`, `flawed.v`, and `tb.v`.
