`timescale 1ns/1ps
module tb;
  reg clk=0, rst=0, wr=0, rd=0;
  reg [3:0] wbe=0, rbe=0;
  reg [31:0] wa=0, wd=0, ra=0;
  wire mt1_wr, mt1_rd, mt2_wr, mt2_rd;
  wire [3:0] mt1_wbe, mt1_rbe, mt2_wbe, mt2_rbe;
  wire [31:0] mt1_wa, mt1_wd, mt1_ra, mt2_wa, mt2_wd, mt2_ra;
  tessera_sdram_req_sync dut(clk,rst,wr,wbe,wa,wd,rd,rbe,ra,mt1_wr,mt1_wbe,mt1_wa,mt1_wd,mt1_rd,mt1_rbe,mt1_ra,mt2_wr,mt2_wbe,mt2_wa,mt2_wd,mt2_rd,mt2_rbe,mt2_ra);
  always #5 clk=~clk;
  initial begin
    rst=1; @(posedge clk); #1 rst=0;
    if (mt1_wr || mt2_wr || mt1_wa || mt2_wa) begin $display("TEST_FAILED reset"); $finish; end
    wr=1; wbe=4'ha; wa=32'h11223344; wd=32'h55667788; rd=1; rbe=4'h5; ra=32'h99aabbcc;
    @(posedge clk); #1;
    if (!mt1_wr || mt1_wbe !== 4'ha || mt1_wa !== 32'h11223344 || mt1_wd !== 32'h55667788 || !mt1_rd || mt1_rbe !== 4'h5 || mt1_ra !== 32'h99aabbcc) begin $display("TEST_FAILED stage1"); $finish; end
    wr=0; rd=0; wbe=0; rbe=0; wa=0; wd=0; ra=0;
    @(posedge clk); #1;
    if (!mt2_wr || mt2_wbe !== 4'ha || mt2_wa !== 32'h11223344 || mt2_wd !== 32'h55667788 || !mt2_rd || mt2_rbe !== 4'h5 || mt2_ra !== 32'h99aabbcc) begin $display("TEST_FAILED stage2"); $finish; end
    @(posedge clk); #1;
    if (mt2_wr || mt2_rd) begin $display("TEST_FAILED stage2 clears after pipeline"); $finish; end
    $display("TEST_PASSED"); $finish;
  end
endmodule
