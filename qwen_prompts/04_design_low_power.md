## Prompt 5: Low-Power Design Test Suite

```
You are an expert in low-power RTL design and power-aware verification. I need a test suite of power optimization tasks testing LLM ability to implement energy-efficient hardware.

Task: Create a "Low-Power Test Suite" containing 10 hand-crafted power optimization problems.

Each problem must include:
- Base RTL design (functional but power-inefficient)
- Power intent specification (voltage domains, power states, requirements)
- Power optimization goals (e.g., reduce dynamic power by 30%)
- Testbench with activity profiles for power measurement
- Reference power-optimized solution

The suite should contain three problem categories:

1. Clock Gating Insertion (4 problems):
   - Datapath with idle detection → insert fine-grained clock gates
   - Pipeline with valid signals → gate registers when invalid
   - FSM with low-activity states → gate unused state registers
   - Multi-channel design → per-channel clock gating

2. Power Domain Crossing (3 problems):
   - VDD_HIGH (1.2V) to VDD_LOW (0.8V) → insert level shifters
   - Power-gated domain → add isolation cells and control
   - Multi-voltage design → verify all crossings have correct cells

3. State Retention Design (3 problems):
   - Power-gated FSM → add retention registers with save/restore
   - Configuration registers → retain during sleep mode
   - Pipeline state → retain critical state with wake-up sequence

Each problem directory structure:
```
problem_001_clock_gating_datapath/
├── prompt.md
├── base_rtl/
│   └── datapath_ungated.v        # Functional but power-hungry
├── power_intent.yaml              # Voltage domains and power states
├── constraints/
│   ├── timing.sdc
│   └── power_budget.yaml          # Target power reduction
├── testbench/
│   ├── tb_top.sv
│   ├── activity_profile_high.vcd  # High-activity scenario
│   ├── activity_profile_low.vcd   # Low-activity scenario
│   └── power_checker.sv           # Monitors for power violations
├── tech_lib/
│   └── NangateOpenCellLibrary_typical.lib
└── reference/
    └── datapath_gated.v           # Hidden during evaluation
```

Novel evaluation requirements: "Power-Aware Verification"
- Estimate dynamic power from VCD switching activity
- Measure leakage power in different power states
- Verify isolation cell presence at power domain boundaries
- Validate retention save/restore latency meets spec
- Check for power sequencing violations

Evaluation metric: "Power Optimization Score" (0-100)
- 30%: Functional correctness (all tests pass in all power modes)
- 30%: Power reduction achieved (vs target specification)
- 20%: Isolation/level-shifter correctness
- 10%: Retention sequence latency (meets spec)
- 10%: Area overhead (within acceptable limit)

Deliver: Complete test suite with 10 power optimization problems, power estimation scripts using Yosys and SAIF/VCD analysis, scoring system, and baseline results.

Use cocotb for simulation, Yosys with Liberty library for power estimation, and custom power state verification scripts.
```