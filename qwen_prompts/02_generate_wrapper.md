# Qwen Prompts for RTL Benchmark Test Suites

## Prompt 1: IP-Integrate Test Suite

```
You are an expert in RTL integration and system-on-chip design. I need a comprehensive test suite of IP integration problems where LLMs must generate glue logic between existing IP blocks.

Task: Create an "IP-Integrate Test Suite" containing 15 hand-crafted problems that test interface adaptation logic generation.

Each problem must include:
- Two frozen IP blocks (provided as read-only Verilog)
- Natural language specification describing the connection requirements
- Complete testbench with protocol checkers
- Reference solution (hidden during evaluation)
- Formal properties for protocol compliance

The suite should contain three problem categories (5 problems each):

1. Protocol Bridge: Connect IPs with different bus protocols
   - Example: AXI4-Stream Master to Wishbone Slave
   - Example: APB Register File to AXI4-Lite Peripheral
   - Example: Avalon-ST Source to AXI4-Stream Sink

2. Width/Channel Adapter: Connect IPs with mismatched data widths
   - Example: 512-bit source to 64-bit sink with packing
   - Example: 32-bit to 128-bit with byte-enable handling
   - Example: 8-bit to 256-bit with alignment logic

3. Flow Control Converter: Connect IPs with incompatible handshaking
   - Example: Credit-based to valid/ready
   - Example: Fixed-latency to backpressured
   - Example: Burst-oriented to streaming

Each problem directory structure:
```
problem_001_axi_to_wishbone/
├── prompt.md
├── ip_a/                          # Frozen AXI-Stream master
│   └── axis_master.v
├── ip_b/                          # Frozen Wishbone slave
│   └── wb_slave.v
├── interface_spec.json            # Port definitions for both IPs
├── testbench/
│   ├── tb_top.sv
│   ├── axis_protocol_checker.sv
│   └── wb_protocol_checker.sv
├── formal/
│   └── bridge_properties.sby
└── reference/
    └── bridge.sv                  # Hidden during evaluation
```

Evaluation requirements for each problem:
- Basic compilation check with Verilator
- Functional simulation with randomized traffic (10000 cycles minimum)
- Protocol fuzzing: random backpressure on both interfaces
- Formal proof of no protocol deadlock (bounded to 50 cycles)
- Synthesis area measurement with Yosys

Novel evaluation metric: "Integration Quality Score" (0-100)
- 40%: Functional correctness across test vectors
- 30%: Protocol compliance (no SVA violations under fuzzing)
- 20%: Backpressure stability (maintains throughput under stall)
- 10%: Area efficiency (vs reference solution)

Deliver: Complete test suite with 15 problems, evaluation script that runs simulation and formal checks, scoring rubric documentation, and baseline results from reference solutions.

Use Icarus Verilog and cocotb for simulation, SymbiYosys for formal properties.
```

---
