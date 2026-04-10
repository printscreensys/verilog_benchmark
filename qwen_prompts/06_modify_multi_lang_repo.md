
## Prompt 3: Mixed-Source Test Suite

```
You are an expert in multi-language RTL projects. I need a test suite of mixed-language design tasks requiring awareness across Verilog, SystemVerilog, and VHDL.

Task: Create a "Mixed-Source Test Suite" containing 10 hand-crafted problems in multi-language projects.

Each problem must include:
- Complete mixed-language project (Verilog headers, SystemVerilog modules, VHDL entities)
- Natural language specification of required modification
- Build scripts showing correct compilation order
- Testbench that exercises all language boundaries
- Reference solution

The suite should contain three problem categories:

1. Cross-Language Parameter Propagation (4 problems):
   - Change bus width defined in Verilog header → update VHDL generics
   - Modify constant in VHDL package → update SystemVerilog parameters
   - Change `define in included file → propagate to all language instances
   - Add new configuration parameter used in both Verilog and VHDL

2. Mixed-Language Hierarchy Modification (3 problems):
   - Add pipeline stage between Verilog and VHDL blocks
   - Insert debug tap that reads signals from both language domains
   - Modify top-level connectivity spanning three languages

3. Preprocessor-Aware Refactoring (3 problems):
   - Reorganize `ifdef hierarchy without breaking conditional builds
   - Add new configuration that affects both Verilog and VHDL conditionally
   - Clean up include dependencies across language boundaries

Each problem directory structure:
```
problem_001_bus_width_change/
├── prompt.md
├── project/
│   ├── include/
│   │   └── defines.vh            # Verilog header with parameters
│   ├── verilog/
│   │   └── datapath.sv
│   ├── vhdl/
│   │   └── controller.vhd
│   ├── top.sv                    # Mixed-language top
│   └── Makefile                  # Compilation order
├── testbench/
│   ├── tb_top.sv                 # Mixed-language test harness
│   └── reference_outputs/
├── constraints.txt                # Files that must NOT be modified
└── reference/
    └── modified_project/          # Complete correct solution
```

Novel evaluation requirement: "Cross-Language Coherence Check"
- Parse all source files into unified representation
- Verify constants defined in one language correctly reference in others
- Check that include graph has no circular dependencies
- Validate all language-specific build configurations still compile

Evaluation metric: "Multi-Language Coherence Score" (0-100)
- 35%: Compilation success (all configurations build)
- 35%: Cross-language consistency (no mismatched constants)
- 20%: Functional correctness (all tests pass)
- 10%: Include hygiene (no unused or missing dependencies)

Deliver: Complete test suite with 10 mixed-language projects, evaluation script with multi-language parsing, scoring system, and baseline results.

Use Verilator with mixed-language support and GHDL for VHDL components.
```

---

