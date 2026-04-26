`timescale 1ns/1ps
module tb;
  reg pre, fcs, jam, eq15;
  reg [1:0] data_state;
  reg [7:0] txdata;
  reg [31:0] crc;
  wire [3:0] out;
  eth_txethmac_nibble_mux dut(pre, data_state, fcs, jam, eq15, txdata, crc, out);
  initial begin
    pre=0; fcs=0; jam=0; eq15=0; data_state=2'b01; txdata=8'hab; crc=32'h0; #1;
    if (out !== 4'hb) begin $display("TEST_FAILED low nibble"); $finish; end
    data_state=2'b10; #1; if (out !== 4'ha) begin $display("TEST_FAILED high nibble"); $finish; end
    data_state=0; fcs=1; crc[31:28]=4'b1010; #1; if (out !== 4'b1010) begin $display("TEST_FAILED fcs"); $finish; end
    fcs=0; jam=1; #1; if (out !== 4'h9) begin $display("TEST_FAILED jam"); $finish; end
    jam=0; pre=1; eq15=0; #1; if (out !== 4'h5) begin $display("TEST_FAILED preamble"); $finish; end
    eq15=1; #1; if (out !== 4'hd) begin $display("TEST_FAILED sfd"); $finish; end
    pre=0; #1; if (out !== 4'h0) begin $display("TEST_FAILED idle"); $finish; end
    $display("TEST_PASSED"); $finish;
  end
endmodule
