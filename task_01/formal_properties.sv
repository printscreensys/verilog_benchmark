// Formal verification properties for SymbiYosys
module formal_properties (
    input clk, rst_n,
    input debug_en,
    input [127:0] debug_readout,
    input [127:0] key_reg,
    input [127:0] key_out,
    input key_valid,
    input [31:0] status
);
    // Property 1: No key exposure through status register
    property status_no_key_leak;
        @(posedge clk)
        (status[31:2] == 30'h0);
    endproperty
    assert property (status_no_key_leak);
    
    // Property 2: Debug port masked in normal mode
    property debug_masked;
        @(posedge clk) disable iff (!rst_n)
        (!debug_en) |-> (debug_readout == 128'h0);
    endproperty
    assert property (debug_masked);
    
    // Property 3: Key persistence unless written
    property key_stability;
        @(posedge clk) disable iff (!rst_n)
        (!$past(key_wr) && $past(rst_n)) |-> 
        ($stable(key_reg));
    endproperty
    assert property (key_stability);
    
    // Property 4: Reset zeroization
    property reset_clear;
        @(posedge clk)
        !rst_n |=> (key_reg == 128'h0);
    endproperty
    assert property (reset_clear);
endmodule