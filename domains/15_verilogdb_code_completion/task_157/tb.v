`timescale 1ns/1ps
module tb;
  reg clk=0, rst=0, sel=0, cyc=0, rty=0, err=0, mbist=0;
  reg [31:0] boot=32'h1000_0000, def=32'h2000_0000, adr=32'h0000_1000;
  reg [3:0] tag=4'ha;
  wire [31:0] adr_o, spr, qadr;
  wire page_cross, qcyc, irty, ierr, ci, mbso;
  wire [3:0] itag;
  wire [18:0] vpn;
  or1200_immu_no_mmu_path dut(clk,rst,sel,boot,def,adr,cyc,rty,err,tag,mbist,adr_o,page_cross,vpn,spr,qadr,itag,qcyc,irty,ierr,ci,mbso);
  always #5 clk=~clk;
  initial begin
    sel=1; #1 if (adr_o !== boot) begin $display("TEST_FAILED boot select"); $finish; end
    sel=0; #1 if (adr_o !== def) begin $display("TEST_FAILED default select"); $finish; end
    rst=1; @(posedge clk); #1 rst=0; adr=32'h0000_2000; @(posedge clk); #1;
    cyc=1; #1 if (page_cross || !qcyc || qadr !== adr || itag !== tag) begin $display("TEST_FAILED pass-through"); $finish; end
    adr=32'h0040_2000; #1 if (!page_cross || qcyc) begin $display("TEST_FAILED page cross"); $finish; end
    rty=1; err=1; mbist=1; #1 if (!irty || !ierr || !mbso || spr !== 32'h0) begin $display("TEST_FAILED outputs"); $finish; end
    $display("TEST_PASSED"); $finish;
  end
endmodule
