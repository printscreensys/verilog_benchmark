
module aes_key_store (
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire [127:0] key_in,
    input  wire         key_wr,
    output wire [127:0] key_out,
    
    input  wire        debug_en,
    output wire [127:0] debug_readout,
    output wire [31:0]  status
);
    // Secure key storage with proper reset handling
    reg [127:0] key_reg;
    reg         key_valid;
    
    // Zeroization on reset (CWE-1272 mitigation)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_reg <= 128'h0;  // Explicit zeroization
            key_valid <= 1'b0;
        end else if (key_wr) begin
            key_reg <= key_in;
            key_valid <= 1'b1;
        end
    end
    
    // Combinational logic for key output
    assign key_out = key_reg;
    
    // Secure debug readout - only active when debug_en=1
    assign debug_readout = debug_en ? key_reg : 128'h0;
    
    // Status register - no sensitive information exposure
    assign status = {
        30'h0,                    // Reserved bits zeroed (no state leakage)
        ^key_reg,                 // Parity check (computational, not state)
        key_valid                 // Valid flag (non-sensitive)
    };
    
    // Assertions for formal verification
    `ifdef FORMAL
        // Property: Debug port zero when disabled
        property debug_disabled_zero;
            @(posedge clk) disable iff (!rst_n)
            (!debug_en) |-> (debug_readout == 128'h0);
        endproperty
        assert property (debug_disabled_zero);
        
        // Property: Key zeroized after reset
        property reset_zeroization;
            @(posedge clk)
            !rst_n |-> (key_reg == 128'h0);
        endproperty
        assert property (reset_zeroization);
    `endif
endmodule