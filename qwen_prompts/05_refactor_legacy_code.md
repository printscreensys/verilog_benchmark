
## Prompt 2: Legacy-Refactor Test Suite

```
You are an expert in RTL refactoring and design maintenance. I need a test suite of legacy code modification tasks where LLMs must change existing RTL without breaking functionality.

Task: Create a "Legacy-Refactor Test Suite" containing 12 hand-crafted problems based on real-world RTL patterns.

Each problem must include:
- Original messy but functional RTL module
- Natural language specification of requested change
- Complete verification environment that must still pass
- Constraints on what must remain unchanged
- Reference refactored solution

The suite should contain three problem categories (4 problems each):

1. Parameterization Tasks:
   - Hard-coded FIFO depth (fixed at 8) → parameterized
   - Fixed-width ALU (32-bit only) → configurable width
   - Hard-coded state machine encoding → parameterized states
   - Fixed counter threshold → runtime configurable

2. Feature Injection Tasks:
   - Add bypass path to pipeline stage (preserve original when bypass=0)
   - Add error injection capability for testing (disabled by default)
   - Add debug register access (without affecting normal operation)
   - Add performance counters (must not alter data path)

3. Interface Migration Tasks:
   - Add flow control to existing streaming interface
   - Convert synchronous outputs to registered
   - Add sideband signals while maintaining backward compatibility
   - Migrate from AHB to AXI-Lite (register interface only)

Each problem directory structure:
```
problem_001_parameterize_fifo/
├── prompt.md
├── original/
│   ├── fifo_legacy.v             # Messy but functional
│   └── constraints.yaml           # What must NOT change
├── testbench/
│   ├── tb_fifo.sv
│   └── test_vectors/              # Known-good input/output pairs
├── golden/
│   ├── original_netlist.json      # Synthesized baseline
│   └── fsm_states.json            # Extracted state machine
└── reference/
    └── fifo_parameterized.v       # Hidden during evaluation
```

Novel evaluation requirement: "Equivalence Checking"
- Synthesize original and modified designs with Yosys
- Apply cut points to isolate new logic portions
- Formally prove unchanged logic cones are equivalent
- Verify that disabling new features restores original behavior exactly

Evaluation metric: "Refactoring Purity Score" (0-100)
- 40%: Functional correctness (all original tests pass)
- 30%: Logic cone equivalence (unchanged portions identical)
- 15%: FSM preservation (states and transitions unchanged)
- 15%: Parameterization completeness (all hard-coded values extracted)

Deliver: Complete test suite with 12 problems, equivalence checking scripts using Yosys, scoring system, and baseline results from reference refactoring.

Use cocotb for simulation and Yosys with custom equivalence passes for verification.
```

---
