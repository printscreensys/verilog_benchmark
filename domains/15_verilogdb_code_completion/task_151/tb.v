`timescale 1ns/1ps
module tb;
  reg [3:0] s;
  reg tms;
  wire [3:0] n;
  dbg_top_tap_next dut(s, tms, n);
  task check; input [3:0] state; input bit; input [3:0] exp; begin
    s = state; tms = bit; #1;
    if (n !== exp) begin $display("TEST_FAILED state=%0d tms=%0d got=%0d exp=%0d", state, bit, n, exp); $finish; end
  end endtask
  initial begin
    check(4'd0, 0, 4'd1); check(4'd0, 1, 4'd0);
    check(4'd2, 0, 4'd3); check(4'd2, 1, 4'd9);
    check(4'd7, 0, 4'd4); check(4'd7, 1, 4'd8);
    check(4'd9, 0, 4'd10); check(4'd9, 1, 4'd0);
    check(4'd14, 0, 4'd11); check(4'd14, 1, 4'd15);
    $display("TEST_PASSED"); $finish;
  end
endmodule
