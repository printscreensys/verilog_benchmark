# Domain 08: Spec Clarification

This domain measures whether a model identifies missing requirements before coding instead of silently choosing an arbitrary interpretation.

Tasks in this domain:
- `task_80`: `event_counter_alert` is intentionally ambiguous and should trigger clarification questions before RTL generation.
- `task_140`: `RsDecodeChien` is a VerilogDB-derived RTL-to-NL task that asks for a concise technical module description.

Spec-clarification tasks include `clarifications.json` for deterministic answer release and question scoring.
RTL-to-NL tasks include `description_rubric.json` and `rtl.v` instead of a Verilog testbench.
