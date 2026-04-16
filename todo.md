# TODO / Idea Backlog — Benchmark for LLMs in RTL Generation

This file lists benchmark ideas that are *poorly covered or not covered* by the papers summarized in `AGENTS.md` (VerilogEval, RTL-Repo, RTLLM2.0/AssertEval, FormalRTL, CVDP, ArchXBench, DeepCircuitX) and by the current tasks in this repo (security leaks, arbitration/races, IP integration, CDC, low-power/UPF, chiplet wrapper).

Each idea includes an implementation algorithm (steps) and suggested tools.

---

## 1) DFT / Testability Tasks (Scan, JTAG TAP, MBIST hooks)

**Why it’s under-covered:** Most RTL LLM benchmarks target “functional RTL”. Real projects spend a lot of effort on DFT plumbing (scan enable, scan chains, JTAG TAP, boundary scan, test-mode overrides), and mistakes are subtle but catastrophic.

**Task types:**
- NL → RTL: Implement a JTAG TAP controller (minimal IEEE 1149.1 subset) driving internal debug registers.
- Code modification: “Make this module scan-friendly” (add scan enable, scan in/out, mux flops).
- Repo integration: Insert DFT wrapper around an existing IP without changing its functional interface.

**Implementation algorithm:**
1. Pick 3–5 DFT “micro-patterns” (scan mux flop, test-mode clock override, JTAG register access, boundary scan cell, MBIST handshake).
2. For each pattern, write:
   - `input.txt`: a *DFT-flavored* spec (explicit signals like `scan_en`, `scan_in/out`, `tck/tms/tdi/tdo`, `test_mode`).
   - `ref.v`: golden implementation (synthesizable).
   - `tb.v`: self-checking testbench that (a) validates functional mode, (b) validates test/scan mode behavior, (c) checks “no unintended functional change”.
   - `flawed.v`: common DFT bugs (scan chain broken, TDO timing wrong, test mode not overriding resets, etc.).
3. Add “mode separation” tests: run the same functional test vectors with `test_mode=0` and ensure outputs match baseline.
4. Extend evaluation to include **lint rules** typical for DFT readiness:
   - Scan signals must not be left unconnected; no latches; no non-synthesizable constructs.
5. Metrics: pass/fail functional + pass/fail DFT mode + lint cleanliness.

**Tools:**
- Simulation: `iverilog`/`vvp` (existing), optionally `verilator` for faster regressions.
- Lint/synth sanity: `verilator --lint-only`, `yosys` (check synthesizability; optionally generate netlist).
- (Optional) Formal: `symbiyosys` to prove scan mode does not affect functional state when `scan_en=0`.

---

## 2) Reset-Domain-Crossing (RDC) + Reset Architecture Correctness

**Why it’s under-covered:** CDC appears in your repo, but **RDC** (async reset assertion + *synchronous deassertion*, per-domain reset release sequencing) causes many real silicon bugs and isn’t explicitly benchmarked in most suites.

**Task types:**
- NL → RTL: Build a reset synchronizer / reset controller for N clock domains with defined release ordering.
- Debugging: Given a design that occasionally enters X-state after reset, fix reset deassertion hazards.

**Implementation algorithm:**
1. Define a reset spec template per domain: `arst_n` async assert, must deassert synchronously to `clk`, optionally with programmable delay.
2. Create tasks that include:
   - Multiple clock domains, shared logic, and a requirement like “domain B must be held in reset until domain A is stable”.
3. Write testbenches that:
   - Randomize reset deassert time relative to each clock (including mid-cycle).
   - Check for illegal transitions (e.g., logic coming out of reset with unknown state).
   - Check release ordering and minimum hold times.
4. Add a “metastability proxy” checker:
   - Ensure reset deassert uses a 2-flop synchronizer (or equivalent) per domain.
5. Provide `flawed.v` variants: async deassert, missing synchronizer, combinational reset gating glitches.

**Tools:**
- Simulation: `iverilog`/`vvp` + randomized stimulus.
- Lint: `verilator --lint-only` (catch accidental latch/comb loops).
- (Optional) Formal: `symbiyosys` assertions about reset release ordering invariants.

---

## 3) CSR / Register-Map Generation from Structured Specs (SVD/CSV/JSON)

**Why it’s under-covered:** “Interface logic” is partly covered by IP-integration, but **register maps** (bus register blocks with bitfields, side effects, access policies) are ubiquitous and error-prone; benchmarks rarely model the *structured* nature of these specs.

**Task types:**
- Agentic: Given `regmap.yaml` + bus choice (APB/AXI-lite), generate `csr_block.v` + decode + side effects.
- Non-agentic: NL spec includes a register table; generate RTL.

**Implementation algorithm:**
1. Choose a minimal structured format (YAML/JSON) describing:
   - address offsets, reset values, RO/RW/W1C bits, write masks, “write triggers pulse”, “read side effects”.
2. Build tasks with:
   - `input.txt` instructing the model to read the regmap file (agentic) or include it inline (non-agentic).
   - `ref.v` implementing a CSR block and a tiny “device core” that reacts to CSR pulses.
   - `tb.v` that runs a bus driver sequence (reads/writes, checks masks, side effects).
3. Make corner cases mandatory:
   - partial writes (byte enables), write-one-to-clear, reserved bits, lock bits, self-clearing bits.
4. For evaluation, run:
   - protocol-level checks (APB/AXI-lite handshake),
   - functional checks (register behavior),
   - “no spurious pulses” checks (one-cycle strobes only when intended).

**Tools:**
- Simulation: `iverilog`/`vvp`, or `cocotb` for clean bus-driver reuse.
- Data handling: Python (`PyYAML` already in deps) to generate stimuli and golden expectations.
- Lint/synth: `verilator`, `yosys`.

---

## 4) Coverage-Driven Verification (CDV) Loop as an Agentic Benchmark

**Why it’s under-covered:** CVDP mentions verification tasks, but “close coverage” (iterate based on coverage metrics) is a distinct, realistic workflow for verification engineers and is rarely benchmarked end-to-end.

**Task types:**
- Agentic multi-turn: (1) run tests, (2) read coverage report, (3) add new tests or constraints, (4) repeat until target.

**Implementation algorithm:**
1. Provide a DUT with subtle corner cases and an initial weak testbench.
2. Define an explicit target:
   - e.g., “≥ 90% branch coverage” or “hit all coverpoints in `covergroup`”.
3. Implement infrastructure:
   - baseline tests + coverage instrumentation (line/branch/toggle depending on tool support).
4. Evaluation:
   - score = coverage achieved under a fixed budget (N iterations / time),
   - penalize flaky tests and nondeterminism.
5. Add anti-shortcut rules:
   - forbid editing DUT for CDV tasks (only tests allowed) in some variants; allow both in others.

**Tools:**
- Fast sim + coverage: `verilator` (coverage) or `iverilog` + `cocotb-coverage`.
- Python test runner: `pytest`, `pytest-xdist` for parallel seeds.
- Reporting: `lcov`/`genhtml` (optional) or parse coverage text.

---

## 5) “Spec Clarification” Benchmarks (Ambiguous / Incomplete Requirements)

**Why it’s under-covered:** Most benchmarks assume the spec is complete. In real projects, specs are incomplete or contradictory. Measuring whether an LLM asks the *right clarifying questions* is a missing axis.

**Task types:**
- Two-stage benchmark:
  1) Model outputs clarifying questions.
  2) Benchmark provides deterministic answers; model generates RTL.

**Implementation algorithm:**
1. Create intentionally under-specified specs (e.g., reset polarity unclear, overflow behavior, handshake timing, priority rules).
2. Provide a “hidden answer key” with:
   - the minimal set of clarifications required for a unique implementation.
3. Evaluate question phase:
   - coverage of critical ambiguities (did it ask about overflow? ordering? reset?),
   - non-redundancy (avoid 20 vague questions).
4. After answering, evaluate RTL as usual with simulation.
5. Add baselines: compare performance of “no questions allowed” vs “questions allowed”.

**Tools:**
- Harness orchestration: Python (your `grok.py`-style runner).
- Simulation: `iverilog`/`vvp` / `cocotb`.
- Scoring: rule-based matching on question intents (simple keyword/embedding clustering).

---

## 6) Constraint-Aware RTL + Timing Closure Surrogates (Open-Source Flow)

**Why it’s under-covered:** A few benchmarks mention PPA, but most do not force *constraint-aware design decisions* (pipelining, multicycle constraints, target Fmax). You can approximate this with open-source STA/PnR surrogates.

**Task types:**
- Synthesis-in-the-loop: “Meet Fmax=200MHz with area budget; choose pipelining depth.”
- Code modification: given slow RTL, pipeline/retime to meet timing.

**Implementation algorithm:**
1. Select small datapaths where pipelining choices matter (MAC, CRC, barrel shifter, small FFT stage).
2. Define constraints:
   - target clock period, max latency, max registers (area proxy).
3. Build an evaluation loop:
   - (a) simulate for correctness, (b) synthesize, (c) run timing estimate, (d) accept/reject.
4. Use a consistent open-source flow:
   - Yosys for synthesis; OpenSTA (or a simplified delay model) for timing estimation.
5. Score:
   - primary = correctness,
   - secondary = achieved slack / registers / cell count.

**Tools:**
- `yosys` (synth + stats), `abc` mapping (via Yosys), OpenSTA (if available), or a simple gate-delay proxy.
- Simulation: `iverilog`/`vvp` or `verilator`.

---

## 7) Fault-Tolerant / Functional-Safety RTL (Lockstep, ECC, Error Injection)

**Why it’s under-covered:** Safety mechanisms (ECC/parity, lockstep redundancy, watchdogs, error escalation) are common in automotive/industrial chips and are not a focus in typical RTL LLM benchmarks.

**Task types:**
- NL → RTL: Implement SECDED ECC for a small SRAM interface + syndrome reporting.
- Agentic: given a fault-injection testbench, iterate until all injected faults are detected/contained.

**Implementation algorithm:**
1. Choose 2–3 safety patterns:
   - parity/ECC encode/decode, lockstep compare, control-flow monitor, safe-state on fault.
2. Write `tb.v` with explicit fault injection:
   - flip a bit in storage, corrupt an internal state, glitch an input.
3. Define acceptance:
   - correct data when no fault,
   - fault flagged within N cycles,
   - safe output behavior when fault persists.
4. Provide flawed implementations:
   - parity computed over wrong bits, syndrome miswired, fault flag not sticky.

**Tools:**
- Simulation: `iverilog`/`vvp`, optional `cocotb` for injection scenarios.
- Formal (optional): prove “fault implies fault_flag eventually” for bounded time with `symbiyosys`.

---

## 8) Side-Channel “Constant-Activity / Constant-Time” Constraints (Practical Security)

**Why it’s under-covered:** You already have secret leakage, but side-channel resistance (timing/power) is a different axis. Even crude proxies (constant latency, bounded toggle) capture real secure-hardware practices.

**Task types:**
- NL → RTL: “Crypto-like” datapath must have fixed latency regardless of inputs; no early-exit.
- Code modification: remove data-dependent branching from control FSM.

**Implementation algorithm:**
1. Define a function with a tempting early-exit (e.g., compare, search, conditional subtraction).
2. Require:
   - fixed cycle count per transaction,
   - constant handshake behavior (no “done early”).
3. Build a testbench that:
   - randomizes inputs,
   - checks latency is constant,
   - optionally checks toggle-count proxy (see below).
4. (Optional) Add a switching-activity proxy:
   - count changes on selected internal nets (or outputs) across cycles for two chosen inputs and ensure within a bound.

**Tools:**
- Simulation: `iverilog`/`vvp`.
- (Optional) Activity: dump VCD and post-process with Python (`pyvcd`) to compare toggles.

---

## 9) Mixed-Abstraction Co-Design Tasks (RTL + Reference Model Consistency)

**Why it’s under-covered:** FormalRTL uses C reference models, but you can create *smaller, more diverse* “executable spec” tasks where the key challenge is aligning edge cases (rounding, saturation, overflow, protocol corner cases).

**Task types:**
- NL + Python reference model → RTL; or “RTL must match this golden Python function exactly”.

**Implementation algorithm:**
1. Provide `model.py` as the executable spec (fixed-point DSP, packet parser, checksum, etc.).
2. Auto-generate stimuli + expected outputs from the model.
3. Testbench applies stimuli to DUT and checks cycle-accurate outputs (or streaming outputs).
4. Add edge-case emphasis:
   - NaN/Inf for FP-like formats, saturating arithmetic boundaries, CRC init seeds.
5. Score separately:
   - functional match,
   - correct handling of explicitly listed edge cases.

**Tools:**
- Python model + vector generation (`numpy` if needed).
- Simulation: `cocotb` is ideal for bridging Python expectations to RTL easily.
- Optional formal equivalence for combinational blocks (`symbiyosys`).

---

## 10) Build-System / Multi-Tool Compatibility (Synthesisable Subset Discipline)

**Why it’s under-covered:** Many benchmarks accept code that “simulates” but is not robustly synthesizable or tool-portable. Real flows demand compatibility across simulators and synth tools.

**Task types:**
- Same RTL must pass: `iverilog` + `verilator` + `yosys` (and optionally one more) without warnings above a threshold.

**Implementation algorithm:**
1. For each task, define a “tool matrix”:
   - simulate with iverilog,
   - lint with verilator,
   - synth with yosys.
2. Define a warning budget (e.g., 0 critical warnings; ≤K style warnings).
3. Add tests that tempt non-synth constructs (e.g., delays `#`, force/release, real numbers, unsized constants pitfalls).
4. Evaluation runs all tools and aggregates a single score:
   - correctness gates everything; then portability score.

**Tools:**
- `iverilog`, `verilator`, `yosys`.
- A small Python runner that captures logs and normalizes warnings (regex-based).

---

## 11) Post-Silicon Debuggability Tasks (Trace Buffers, Event Counters, Trigger Logic)

**Why it’s under-covered:** Benchmarks usually ignore observability hooks. Silicon bring-up relies on trace FIFOs, trigger capture, event counters, timestamping—lots of “glue RTL” that must be correct under backpressure.

**Task types:**
- NL → RTL: “Triggerable trace buffer” with circular RAM, trigger condition, pre/post samples.
- Repo integration: add debug module without perturbing timing/behavior (functional transparency until enabled).

**Implementation algorithm:**
1. Define a small stream interface + trace buffer requirements:
   - depth, trigger predicate, freeze modes, readout interface (e.g., simple APB/AXI-lite CSR).
2. Testbench:
   - drives random traffic,
   - asserts trigger at known time,
   - checks captured window matches expected pre/post frames,
   - stresses backpressure on readout.
3. Include common pitfalls in `flawed.v`:
   - off-by-one in circular indexing, incorrect window alignment, losing samples under stall.

**Tools:**
- Simulation: `iverilog`/`vvp` or `cocotb` (good for sequence checking).
- Optional: VCD dump + Python check for trace correctness.

---

## 12) “No-Cheating” Evaluation Hardening as a Benchmark Axis

**Why it’s under-covered:** Simple token-based pass/fail (“print TEST_PASSED”) is easy to game if the model sees the testbench, and even if hidden, spurious output logic can pass shallow checks. Hardening evaluation is a technical contribution.

**Task types:**
- Not a new *domain*, but a cross-cutting benchmark design upgrade:
  - hidden tests, metamorphic tests, differential tests, and anti-tamper checks.

**Implementation algorithm:**
1. Stop relying on a single string token for pass/fail:
   - move pass/fail to exit code, or to a scoreboard in cocotb.
2. Hide/obfuscate test intent:
   - split testbench into a compiled harness + runtime vectors stored separately.
3. Add metamorphic relations:
   - e.g., if input is scaled/shifted, output must transform predictably.
4. Add negative tests:
   - explicitly check forbidden behaviors (X-propagation, multiple drivers, latches, blocking assignments in sequential always blocks if disallowed).
5. Produce a “robustness score” per task:
   - number of independent checks passed (syntax, sim, lint, synth, formal).

**Tools:**
- `cocotb` + `pytest` (better structure for scoreboards).
- `verilator` lint, `yosys` synth checks.
- Optional: `symbiyosys` for small formal invariants.

dumpvars;
switch;
UVM Tests;