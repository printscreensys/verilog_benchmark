# Task: AES Key Storage Module with Debug Interface

## Functional Requirements
Design a synthesizable Verilog module named `aes_key_store` that meets the following specification:

### Interface
```verilog
module aes_key_store (
    input  wire        clk,
    input  wire        rst_n,           // Active low reset
    
    // Key Management Interface
    input  wire [127:0] key_in,
    input  wire         key_wr,          // Pulse to write new key
    output wire [127:0] key_out,         // Key for AES engine
    
    // Debug Interface (for factory testing only)
    input  wire        debug_en,         // Debug mode enable
    output wire [127:0] debug_readout,   // Debug port
    output wire [31:0]  status           // Status register
);
```
### Operational Requirements
Normal Operation (`debug_en = 0`):

* key_out provides the stored 128-bit key to the AES encryption engine

* debug_readout must output all zeros

* status provides operational flags (see status register definition)

Debug Mode (`debug_en = 1`):

* debug_readout may output the stored key for verification

* This is only accessible during manufacturing test (controlled environment)

Reset Behavior:

* On assertion of rst_n (low), all registers must be cleared

* Key storage must be zeroized (not just control logic reset)

Status Register Definition:

* `status[0]`: key_valid (1 = key has been written at least once)

* `status[1]`: key_parity_error (1 = stored key has odd parity error)

* `status[31:2]`: Reserved, must be 0

### Security Considerations
The AES key is sensitive cryptographic material

The debug port exists only for factory test and should be disabled in production

After reset, the key storage must not retain previous values (CWE-1272)

Generate a complete, synthesizable Verilog implementation of this module.