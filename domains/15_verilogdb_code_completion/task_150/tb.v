`timescale 1ns/1ps
module tb;
  reg [3:0] entry;
  wire [11:0] q1_index, q2_index;
  wire [9:0] l_index, p_index;
  ldpc_decoder_tail_map dut(entry, q1_index, q2_index, l_index, p_index);

  task check;
    input [3:0] e;
    input [11:0] q1;
    input [11:0] q2;
    input [9:0] l;
    input [9:0] p;
    begin
      entry = e; #1;
      if (q1_index !== q1 || q2_index !== q2 || l_index !== l || p_index !== p) begin
        $display("TEST_FAILED entry=%0d got q1=%0d q2=%0d l=%0d p=%0d", e, q1_index, q2_index, l_index, p_index);
        $finish;
      end
    end
  endtask

  initial begin
    check(4'd0, 12'd1300, 12'd1456, 10'd515, 10'd514);
    check(4'd4, 12'd1328, 12'd1480, 10'd519, 10'd518);
    check(4'd9, 12'd1363, 12'd1510, 10'd524, 10'd523);
    check(4'd15, 12'd0, 12'd0, 10'd0, 10'd0);
    $display("TEST_PASSED");
    $finish;
  end
endmodule
