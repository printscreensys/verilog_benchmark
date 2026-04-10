## Prompt 4: Clock Domain Crossing (CDC) Test Suite

```
You are an expert in CDC design and metastability analysis. I need a test suite of asynchronous interface tasks testing LLM ability to design safe clock crossing logic.

Task: Create a "CDC Test Suite" containing 12 hand-crafted CDC design problems.

Each problem must include:
- Specification of two clock domains with frequencies and phase relationships
- Functional requirements for data transfer across domains
- Testbench with clock generators and protocol checkers
- Formal properties for CDC safety verification
- Reference solution with proper synchronizers

The suite should contain three problem categories (4 problems each):

1. Asynchronous FIFO Variants:
   - Write: 400 MHz, Read: 250 MHz, 32-bit data, depth 8
   - Write: 150 MHz, Read: 600 MHz, 64-bit data, depth 16
   - Write: 500 MHz, Read: 500 MHz (phase-shifted), 128-bit data, depth 4
   - Write: 200 MHz, Read: 800 MHz, with credit-based flow control, depth 32

2. Pulse Synchronizer Challenges:
   - Single-cycle pulse from 1 GHz to 100 MHz with handshake
   - Back-to-back pulses from 400 MHz to 200 MHz (no loss allowed)
   - Level-to-pulse conversion across domains with acknowledgment
   - Multi-bit event flags crossing 300 MHz to 50 MHz

3. Reset Domain Crossing:
   - Configuration registers crossing async reset boundary
   - State machine reset synchronization between domains
   - Power-on reset sequencing across multiple clock domains
   - Warm reset handling while maintaining CDC safety

Each problem directory structure:
```
problem_001_async_fifo_400_250/
├── prompt.md
├── spec.json                     # Frequencies, widths, requirements
├── constraints/
│   ├── write_domain.sdc
│   └── read_domain.sdc
├── testbench/
│   ├── tb_top.sv
│   ├── write_clock_gen.sv
│   ├── read_clock_gen.sv
│   └── cdc_protocol_checker.sv
├── formal/
│   ├── fifo_properties.sby
│   └── gray_code_proof.sv
└── reference/
    └── async_fifo.sv             # Hidden during evaluation
```

Novel evaluation requirements: "CDC Safety Analysis"
- Detect unsynchronized signals crossing domains
- Verify synchronizer chain depth meets MTBF requirements
- Check Gray code correctness for multi-bit pointers
- Run bounded model checking for absence of CDC deadlock
- Calculate MTBF for each synchronizer path

Evaluation metric: "CDC Safety Score" (0-100)
- 30%: Functional correctness (data transfers correctly)
- 35%: Synchronizer compliance (all crossings properly synchronized)
- 15%: Gray code correctness (multi-bit transfers safe)
- 10%: Formal proof depth (cycles proven safe)
- 10%: Performance (throughput efficiency)

Deliver: Complete test suite with 12 CDC problems, CDC safety analyzer script, formal property templates, scoring system, and baseline results from reference solutions.

Use cocotb for simulation and SymbiYosys for formal CDC verification.
```

---