# Context
I am writing master thesis "Benchmark for LLMs in RTL Generation"

# This project
This is a project for my thesis

# My research
Here is summary of 7 papers about benchmarks for LLMs in RTL generation
## **List of benchmarks**
1. ### **VerilogEval**
<https://dl.acm.org/doi/pdf/10.1145/3718088> 
Benchmark: VerilogEval (v2 – improved version)
- Supports code completion tasks (original benchmark capability)
- Supports specification-to-RTL generation tasks (instruction-style prompting)
- Includes in-context learning (ICL) support with configurable number of examples (one-shot, two-shot, three-shot)
- Enables prompt engineering experimentation (variation across prompts, tasks, and models)
- Provides automatic failure classification:
  - Compile-time errors (syntax, binding, type issues, missing modules, etc.)
  - Runtime errors (timeouts, reset issues, incorrect behavior)
- Offers fine-grained failure analysis instead of only pass/fail
- Uses pass\@k metric (primarily pass\@1 in updated evaluation) for performance measurement
- Supports multiple sampling configurations (temperature-based evaluation)
- Includes dataset with 156 Verilog problems (from HDLBits, curated for diversity and clarity)
- Provides two prompt styles:
  - Verilog-comment-based (code completion)
  - Q/A structured format (spec-to-RTL)
- Contains human-written and machine-generated problem descriptions (focus on human for realism)
- Uses Icarus Verilog-based simulation and testing pipeline for functional correctness
- Introduces Makefile-based evaluation infrastructure:
  - Modular dataset organization (no monolithic JSONL)
  - Parameterized experiment control (model, shots, samples, task type)
  - Parallel execution support
  - Easier debugging and inspection
- Stores per-problem evaluation artifacts (prompts, responses, generated RTL, logs)
- Supports scalable benchmarking across many models and configurations
- Allows evaluation resumption and incremental runs
- Designed for analyzing prompt sensitivity and model variability
- Publicly available, open-source benchmark framework
2. ### **RTL-Repo**
<https://arxiv.org/pdf/2405.17378>
Based on the provided paper, here is the feature list for RTL-Repo:
- Repository-Level Context: Evaluates generation within the full context of a multi-file Verilog repository, not just a single standalone module.
- Large-Scale Dataset: Comprises over 4,000 code samples extracted from more than 1,300 public GitHub repositories (with 1,174 test samples).
- Cross-File Code Completion Task: The core task requires the model to predict a randomly masked line of code given the context of the entire repository and the preceding lines in the current file.
- Long-Context Evaluation: Benchmarks performance across varying context lengths (from 2K to 128K tokens), specifically testing models' ability to handle long-range dependencies in RTL.
- Real-World Project Focus: Utilizes actual public GitHub RTL projects rather than synthetic or textbook problems to ensure realistic design scenarios.
- Context-Aware Metrics: Evaluates using Exact Match (EM) for precise line completion accuracy and Edit Similarity (ES) based on Levenshtein distance to measure the developer effort required for correction.
- Living Benchmark Design: Built with an automated collection pipeline to facilitate regular updates with new repositories, preventing data leakage and keeping the benchmark current.
- Training Split Availability: Provides a separate training split of the dataset intended for fine-tuning open-source models to improve performance on multi-file RTL generation.
3. ### **RTLLM 2.0 (bundle)**
<https://dl.acm.org/doi/pdf/10.1145/3676536.3697118> 
**RTLLM 2.0 (RTL generation benchmark)**
- Open-source benchmark for natural language → RTL generation
- Contains 50 hand-crafted RTL designs (expanded from 30)
- Each design includes:
  - Natural language design description
  - Testbench with test cases
  - Golden (reference) RTL implementation
- Supports multiple HDL targets (Verilog, VHDL, Chisel)
- Covers diverse design categories:
  - Arithmetic modules
  - Memory modules
  - Control modules
  - Miscellaneous/system modules
- Provides fine-grained categorization by function/application (not just logic/arithmetic)
- Enables functional correctness evaluation via simulation (testbench)
- Supports syntax correctness evaluation (via synthesis tools)
- Supports design quality evaluation (PPA: power, performance, area)
- Defines multi-level evaluation metrics:
  - Syntax correctness
  - Functional correctness
  - Design quality (PPA)
- Enables automatic evaluation pipeline (description → generated RTL → testbench validation)
- Designed for scalability across design complexity and size
AssertEval (RTL verification / assertion generation benchmark)
- Benchmark for LLM-based assertion (SVA) generation
- Contains 18 real-world designs across domains (crypto, processors, comms, etc.)
- Input: full natural language specification documents (multi-section, multi-modal)
- Provides:
  - Specification documents
  - Golden RTL implementations (bug-free)
  - Formal Property Verification (FPV) scripts
- Supports formal verification-based evaluation (FPV)
- Defines assertion quality metrics:
  - Syntax correctness
  - FPV pass/fail (semantic correctness)
  - COI (cone-of-influence) coverage
- Enables automatic evaluation of generated assertions
- Handles complex, unstructured specifications (text + waveform diagrams)
- Supports end-to-end assertion generation + verification workflow
4. ### **FormalRTL**
<https://arxiv.org/pdf/2603.08738> 
Benchmark: FormalRTL (benchmark suite within FormalRTL framework)
- Provides a new suite of industrial-grade RTL generation benchmarks
- Each benchmark includes:
  - Natural language specification
  - Software reference model (C/C++) acting as executable specification
- Targets datapath-intensive designs (e.g., floating-point units like FP16, Hifloat8)
- Includes both academic benchmarks (e.g., SoftFloat-derived FP units) and industrial-inspired designs
- Supports formal equivalence checking (C ↔ RTL) as primary correctness criterion
  - Uses C-RTL equivalence (EC) instead of testbench-only validation
- Enables counterexample-based evaluation and debugging
  - Benchmarks inherently produce counterexamples on failure
- Provides module-level decomposition:
  - Benchmarks structured into submodules (leaf, mid, top)
  - Supports incremental / hierarchical verification
- Supports large-scale RTL generation tasks:
  - Designs up to 1000+ lines of RTL code
- Includes sequential and combinational design cases
- Enables evaluation of planning strategies:
  - Comparison of reference-model-based vs spec-only planning
- Enables evaluation of debugging strategies:
  - Bug localization
  - Counterexample simplification
  - Iterative fixing performance
- Provides fine-grained evaluation metrics:
  - Initial Success Rate (ISR / pass\@1 equivalent)
  - Final Success Rate (FSR)
  - Average fixing iterations
  - Iteration variance
- Supports evaluation under iterative repair loops (not single-shot only)
- Enables measurement of scalability with design complexity
- Provides QoR (Quality of Result) evaluation capability:
  - Area
  - Delay (timing)
  - Comparison with human-designed RTL
- Designed to evaluate multi-agent RTL generation systems
- Eliminates reliance on testbench coverage limitations via formal methods
- Supports bottom-up verification workflow (submodule correctness guarantees system correctness)
- Open-sourced benchmark (with framework) for reproducibility and future research
Distinctive aspects (benchmark-specific)
- Uses software reference models as ground-truth specs (rare in prior benchmarks)
- Uses formal equivalence instead of simulation-based validation
- Focuses on industrial-scale, datapath-heavy designs rather than toy tasks
- Enables evaluation of full generation + debugging pipelines, not just generation
5. ### **CVDP**
<https://arxiv.org/pdf/2506.14074> 
Benchmark: CVDP (Comprehensive Verilog Design Problems)
- Large-scale benchmark with 783 human-authored problems
- Covers 13 task categories spanning RTL design and verification workflows
Task Coverage / Scope
- Supports RTL generation tasks:
  - Code completion
  - Natural language → RTL
  - Code modification
  - Module reuse (composition)
- Supports design verification tasks:
  - Testbench stimulus generation
  - Testbench checker generation
  - Assertion generation
  - Debugging / bug fixing
- Supports code quality and optimization tasks:
  - Linting improvements
  - QoR (power/area/performance) improvements
- Supports code comprehension tasks:
  - Spec ↔ RTL correspondence
  - Testbench ↔ test plan mapping
  - Technical Q\&A (RTL and testbench)
Agentic + Non-Agentic Support
- Provides both:
  - Non-agentic (single-turn) tasks
  - Agentic (multi-turn, tool-using) tasks
- First benchmark designed for LLM agents in RTL workflows
- Agentic tasks support:
  - Tool interaction (EDA tools)
  - Iterative workflows
  - Repository-level reasoning
Realism and Difficulty
- Problems are written by experienced hardware engineers (≈35 contributors)
- Includes expert review and QA filtering pipeline
- Designed to be significantly harder than prior benchmarks
- Provides substantial headroom (≤34% pass\@1 on generation)
- Covers real-world design domains:
  - FSM/control logic
  - Datapath/arithmetic
  - Interconnects
  - Memory systems
  - Processor/accelerator architectures
Data Structure / Format
- Each problem is a multi-file mini-repository
- Includes:
  - Prompt/context
  - Supporting artifacts (docs, modules, testbenches)
  - Golden reference solution
- Dataset distributed as:
  - Two JSONL files (agentic + non-agentic)
- Uses oracle context design (minimal necessary info provided)
Evaluation Infrastructure
- Provides full benchmarking framework + runner
- Uses open-source EDA tools:
  - Icarus Verilog (simulation)
  - Yosys (synthesis)
  - Verilator (linting)
- Supports commercial tools when required (e.g., Xcelium)
- Uses Docker-based execution:
  - Isolation
  - Reproducibility
  - Tool consistency
- Includes:
  - Test harnesses (hidden from model)
  - Logging and reporting infrastructure
Evaluation Metrics
- Uses pass\@k (pass\@1 with sampling) for generation tasks
- Uses multiple evaluation methods depending on task:
  - Simulation-based correctness (via CocoTB)
  - BLEU score (for exact-match tasks)
  - LLM-based judging (for subjective/QA tasks)
Advanced Features
- Supports conversion between agentic and non-agentic formats
- Includes map/reduce-style evaluation utilities for batch testing
- Enables LLM-based dataset quality filtering and scoring
- Supports difficulty levels:
  - Easy, medium (non-agentic)
  - Easy → hard (agentic)
Failure Analysis Capabilities
- Provides systematic failure analysis pipeline:
  - LLM-based failure reflection
  - Embedding + clustering (K-means)
  - Category-level failure summarization
- Enables fine-grained failure categorization across tasks
Key Distinguishing Features
- First benchmark to comprehensively cover full RTL lifecycle:
  - Generation + verification + debugging + comprehension
- First to natively support agentic evaluation with tools
- Provides broadest task diversity (13 categories) among RTL benchmarks
- Emphasizes real-world complexity and workflows, not isolated toy problems
6. ### **ArchXBench**
<https://arxiv.org/pdf/2508.06047> 
Benchmark: ArchXBench
- Provides a multi-level benchmark suite for complex RTL generation (Levels 0–6, with sublevels 1a/1b/1c)
- Contains \~51 benchmark designs spanning increasing architectural complexity
Complexity & Scaling Features
- Explicitly designed for scaling from simple circuits → full SoC-like subsystems
- Covers:
  - Combinational designs
  - Multi-cycle designs
  - Deeply pipelined architectures
  - Hierarchical multi-module systems
- Includes designs ranging from hundreds to tens of thousands of RTL lines
- Captures architecture-level trade-offs:
  - Latency
  - Area
  - Throughput
  - Power
Domain Coverage
- Benchmarks span real-world accelerator domains:
  - Cryptography (e.g., AES cores)
  - Signal processing (FFT, filters)
  - Image processing (e.g., unsharp mask, Harris corner detection)
  - Machine learning (CNNs, GEMM, systolic arrays)
- Focuses on datapath-intensive systems (excludes control-heavy designs)
Architectural Diversity
- Includes parametric and tunable designs (e.g., unroll factors, block sizes)
- Supports hierarchical composition of modules
- Covers iterative algorithms and floating-point designs
- Includes pipeline vs multi-cycle implementations of same functionality
Benchmark Structure / Artifacts
- Each benchmark provides:
  - Natural language problem description
  - Formal design specification (interfaces, parameters)
  - Verilog testbench
- Advanced levels additionally include:
  - Python reference models (executable specs)
  - Stimulus generation scripts
  - Golden outputs and DUT outputs
  - Input/output datasets
- Organized as hierarchical directory structure (Level-based)
Evaluation Capabilities
- Supports functional correctness evaluation via testbenches
- Supports syntactic correctness checking
- Includes architectural correctness validation:
  - Checks whether generated RTL matches required architecture (e.g., pipelined vs iterative)
- Uses pass\@k evaluation (pass\@5 in baseline experiments)
End-to-End Design Flow Coverage
- Enables evaluation across multiple RTL design stages:
  - Specification understanding
  - Microarchitecture planning
  - RTL implementation
  - Verification against reference models
- Supports design space exploration via parameter tuning
Support for Advanced LLM Methods
- Designed to evaluate:
  - Zero-shot and in-context prompting
  - Agentic workflows
  - Iterative refinement approaches
  - Retrieval-augmented generation (RAG)
- Suitable for multi-agent and planning-based RTL generation systems
Realism & Difficulty
- Addresses limitations of prior benchmarks by including:
  - Deep pipelining
  - Hierarchical integration
  - Large-scale accelerator designs
- Introduces a clear difficulty progression across levels
- Exposes capability gaps in current LLMs at higher complexity levels
Key Distinguishing Features
- Focus on complex digital subsystems rather than toy circuits
- Combines architecture-level reasoning + RTL generation
- Provides multi-level structured difficulty scaling
- Includes rich artifacts (specs, testbenches, reference models, scripts)
- Enables research on full-stack RTL synthesis workflows
7. ### **DeepCircuitX**
<https://arxiv.org/pdf/2502.18297>
Benchmark: DeepCircuitX
- Provides repository-level RTL benchmark dataset (not just file-level)
- Contains 4000+ RTL design repositories (\~140K RTL files)
- Covers chip-level, IP-level, and module-level designs
Multi-Level Representation
- Organizes data into four abstraction levels:
  - Repository-level
  - File-level
  - Module-level
  - Block-level
- Enables multi-scale training and evaluation of LLMs
Task Coverage
- Supports RTL understanding tasks (code → description)
- Supports RTL code completion tasks
- Supports RTL generation tasks (spec → RTL)
- Supports PPA prediction tasks (learning-based)
Annotation Features
- Includes Chain-of-Thought (CoT) annotations at multiple levels
- Provides:
  - Detailed functional descriptions
  - Structural explanations
  - Question–answer pairs for code understanding
- Uses LLM-assisted annotation pipeline (GPT-4, Claude)
Multimodal Data Features
- Includes graph representations of RTL:
  - Abstract Syntax Trees (AST)
  - Control/Data Flow Graphs (CDFG)
- Includes circuit-level representations:
  - Gate-level netlists
  - And-Inverter Graphs (AIG)
  - Layout-related data
- Bridges RTL ↔ circuit implementation stages
PPA & Physical Design Integration
- Provides Power, Performance, Area (PPA) metrics
- Includes:
  - Area reports
  - Timing (delay) reports
  - Power (dynamic + leakage)
- Supports cross-stage learning (RTL → physical metrics)
- Enables early-stage PPA prediction from RTL
EDA Flow Integration
- Supports full RTL-to-layout pipeline transformations:
  - RTL → netlist → layout
- Uses EDA tools (e.g., Synopsys Design Compiler, PrimeTime) for synthesis and analysis
- Includes multi-technology mapping (e.g., 130nm, 45nm, 7nm)
Benchmark / Evaluation Design
- Provides pre-training and evaluation benchmarks for LLMs
- Includes multiple evaluation metrics depending on task:
  - BLEU, METEOR, ROUGE (for understanding)
  - Functional correctness (generation/completion)
- Includes human evaluation framework:
  - Accuracy
  - Completeness
  - Clarity
Dataset Construction Features
- Built from keyword-driven large-scale repository mining (222 keywords)
- Covers 77 functional categories
- Includes diverse real-world hardware designs
Key Distinguishing Features
- First benchmark to combine:
  - Repository-level structure
  - Multimodal circuit representations
  - PPA-aware evaluation
- Enables joint learning of RTL semantics + physical design metrics
- Bridges front-end (RTL) and back-end (physical design) stages
- Strong focus on code understanding (not just generation)

# What I've done
I've found domains that existing papers don't cover
### 1. Security Vulnerability Detection Benchmark
Evaluates whether LLMs can generate RTL free of common security vulnerabilities (CWE categories: information exposure, race conditions, privilege escalation, state leakage). Existing benchmarks ignore security entirely

### 2. IP-Integrate
Current benchmarks (even repository-level ones like RTL-Repo or ArchXBench) ask the LLM to generate the core logic (e.g., "Write an FFT"). They do not test the ability to generate the tedious, bug-prone interface logic (wrapper modules, clock-domain crossing bridges, bus width converters, arbitration logic) required to connect two existing, complex IPs.
 
### 3. Clock Domain Crossing (CDC) Test Suite
None of the benchmarks explicitly test CDC logic generation. CVDP mentions "interconnects" but not asynchronous boundaries. Real-world designs spend ~30% of verification effort on CDC issues.

### 4. Low-Power Design Constructs
DeepCircuitX provides PPA metrics but doesn't test generation of power-specific RTL constructs like clock gating, power gating interfaces, or retention flops. No benchmark tests UPF/CPF awareness.

### 5. Hierarchical Chiplet/2.5D Design Tasks
Tasks require generating hierarchical RTL for chiplet-based designs (multiple dies/interconnects). Tests ability to reason about die-to-die interfaces, UCIe/BoW protocols, and power domain crossing

There are tasks in directories `task_NM` - where `N` stands for domain number.
Each task contains 4 files:
* `input.txt` - Natural language specification for LLM to generate RTL.
* `ref.v` - golden Verilog reference code
* `flawed.v` - example of flawed code that doesn't pass testbench
* `tb.v` - testbench for cheking solution

In the root there is `eval.py` that runs simulation and checks correctness of solution.