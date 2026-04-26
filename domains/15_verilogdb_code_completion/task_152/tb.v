`timescale 1ns/1ps
module tb;
  reg [3:0] bram_rate;
  wire [2:0] N_BPSC;
  wire [8:0] N_DBPS;
  wire [4:0] RATE;
  dot11_tx_rate_decode dut(bram_rate, N_BPSC, N_DBPS, RATE);
  task check; input [3:0] r; input [2:0] bpsc; input [8:0] dbps; input [4:0] rate; begin
    bram_rate = r; #1;
    if (N_BPSC !== bpsc || N_DBPS !== dbps || RATE !== rate) begin
      $display("TEST_FAILED r=%b got bpsc=%0d dbps=%0d rate=%b", r, N_BPSC, N_DBPS, RATE);
      $finish;
    end
  end endtask
  initial begin
    check(4'b1011, 3'd1, 9'd24, 5'b01011);
    check(4'b1110, 3'd2, 9'd72, 5'b01110);
    check(4'b1101, 3'd4, 9'd144, 5'b01101);
    check(4'b1100, 3'd6, 9'd216, 5'b01100);
    check(4'b0000, 3'd1, 9'd24, 5'b01011);
    $display("TEST_PASSED"); $finish;
  end
endmodule
