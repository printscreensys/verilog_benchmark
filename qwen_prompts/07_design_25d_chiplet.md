You are an expert in advanced hardware design, specifically chiplet-based architectures, die-to-die interfaces (UCIe, BoW, AIB), and hierarchical RTL verification. I need a complete benchmark suite that evaluates whether LLMs can generate correct RTL for hierarchical chiplet/2.5D designs.

## Context
Existing benchmarks (VerilogEval, RTLLM, ArchXBench) only test flat, single-module designs. Real-world SoCs now use multiple chiplets (dies) connected via die-to-die (D2D) interfaces with complex protocols, power domain crossings, and clock domain crossings. No existing benchmark tests LLMs on this capability.

## Deliverables

Create a Python-based benchmark suite with the following components:

### 1. Chiplet Task Definitions (5 tasks)

Define 5 hierarchical chiplet design tasks with increasing complexity:

**Task 1: Simple 2-chiplet system**
- Chiplet A: Processor core (simple RISC-V or state machine)
- Chiplet B: Memory controller + SRAM
- Interface: UCIe streaming protocol (valid/ready with flow control)
- Requirements: Coherency check (writes to Chiplet B are visible to Chiplet A)

**Task 2: 3-chiplet system with router**
- Chiplet A: Compute accelerator (matrix multiplier)
- Chiplet B: Scratchpad memory
- Chiplet C: DMA engine
- Interface: AIB (Advanced Interface Bus) with packetized requests
- Requirements: No deadlock, fair arbitration, backpressure handling

**Task 3: Power-domain crossing**
- Chiplet A: Always-on voltage island (control FSM)
- Chiplet B: Power-gated compute island (can sleep)
- Interface: Power-aware handshake (sleep/wakeup sequences)
- Requirements: No data loss during power transitions, proper isolation cells

**Task 4: Heterogeneous chiplets (mixed clock domains)**
- Chiplet A: 1 GHz clock
- Chiplet B: 500 MHz clock
- Chiplet C: 250 MHz clock
- Interface: Asynchronous FIFO with clock domain crossing (CDC) correctness
- Requirements: CDC analysis (no metastability, proper synchronizers)

**Task 5: Full 2.5D integration with interposer**
- 4 chiplets: CPU, GPU, Memory, I/O
- Interface: UCIe with PHY layer abstraction
- Requirements: Protocol compliance, deadlock-free routing, quality-of-service (QoS)

For each task, generate:
- `spec.md`: Natural language specification with architectural diagram (ASCII art or text description)
- `interface_definitions/`: SystemVerilog interface definitions for each D2D link
- `chiplet_skeletons/`: Empty RTL templates for each chiplet with correct ports
- `top_testbench.sv`: Hierarchical testbench that instantiates all chiplets and checks cross-chiplet invariants
- `golden_reference/`: Correct RTL implementation (for scoring)

### 2. D2D Protocol Checkers

Implement Python/Verilog protocol checkers for:
- **UCIe streaming**: Valid/ready handshake, credit-based flow control, packet framing
- **AIB**: Request/response matching, transaction ID tracking, out-of-order completion
- **Power-aware handshake**: Sleep/wakeup sequences, power-OK signaling, isolation enable/disable

Each checker should:
- Run in simulation (cocotb/Verilator) as monitors
- Assert protocol violations (e.g., "valid without ready for >N cycles", "wakeup without prior sleep request")
- Output violation count and waveform timestamp

### 3. Cross-Chiplet Invariant Verification

For each task, define invariants that span multiple chiplets:
- Example: "Data written to memory chiplet from CPU must be readable by DMA within 10 cycles"
- Example: "No two chiplets drive the same interposer wire simultaneously"
- Example: "Power-down sequence completes within 100 cycles of sleep request"

Implement these as SystemVerilog Assertions (SVA) or cocotb property checkers at the top level.

### 4. Evaluation Harness

Create a Python script `evaluate_chiplet_design.py` that:

```python
def evaluate_chiplet_task(task_id, llm_generated_rtl_folder):
    # Input: task_id (1-5) and folder containing RTL for all chiplets + top
    # Output: JSON with scores
    
    # Step 1: Compile all chiplets with top testbench
    compile_success = compile_with_verilator(llm_generated_rtl_folder)
    
    # Step 2: Run simulation with protocol monitors
    sim_result = run_simulation(timeout_seconds=300)
    
    # Step 3: Check cross-chiplet invariants (SVA)
    invariant_results = check_sva_assertions(sim_result.vcd)
    
    # Step 4: Run D2D protocol checks
    protocol_violations = run_protocol_checkers(sim_result.vcd)
    
    # Step 5: Compare to golden reference (optional, for functional equivalence)
    functional_match = compare_to_golden(llm_rtl, golden_rtl, sim_stimulus)
    
    # Compute scores
    scores = {
        "compilation_pass": compile_success,
        "simulation_pass": sim_result.passed,
        "invariant_pass_rate": len(invariant_results.passed) / len(invariant_results.total),
        "protocol_violations": len(protocol_violations),
        "functional_equivalence_score": functional_match,
        "overall_score": (0.3 * sim_result.passed + 
                          0.3 * invariant_pass_rate +
                          0.2 * (1 - protocol_violations/10) +
                          0.2 * functional_match)
    }
    return scores
```