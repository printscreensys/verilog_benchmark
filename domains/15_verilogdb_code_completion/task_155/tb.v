`timescale 1ns/1ps
module tb;
  reg [3:0] huge, huge_hit, hit;
  reg [95:0] huge_flat;
  reg [127:0] trans_flat;
  reg [23:0] low24;
  reg [12:0] low13;
  reg [1:0] spr_way;
  reg mr, tr, mcs, tcs, we, pf;
  wire miss;
  wire [31:0] phys;
  wire ure, uwe, sre, swe, ci;
  wire [3:0] mwe, twe;
  mor1kx_dmmu_way_select dut(huge, huge_hit, hit, huge_flat, trans_flat, low24, low13, spr_way, mr, tr, mcs, tcs, we, pf, miss, phys, ure, uwe, sre, swe, ci, mwe, twe);
  initial begin
    huge=0; huge_hit=0; hit=4'b0010; huge_flat=0; trans_flat=0; low24=24'h123456; low13=13'h1555; spr_way=2'd2; mr=0; tr=0; mcs=1; tcs=0; we=1; pf=0;
    trans_flat[1*32 +: 32] = 32'habcde3c2; #1;
    if (miss || phys !== {19'h55e6f, low13} || !ure || !uwe || !sre || !swe || !ci) begin $display("TEST_FAILED normal hit"); $finish; end
    huge=4'b0100; huge_hit=4'b0100; hit=0; huge_flat[2*24 +: 24] = 24'h7f03c2; #1;
    if (miss || phys !== {8'h7f, low24} || !ure || !uwe || !sre || !swe || !ci) begin $display("TEST_FAILED huge hit"); $finish; end
    mr=1; tr=1; #1; if (mwe !== 4'b1111 || twe !== 4'b1011) begin $display("TEST_FAILED write enables reload/spr override mwe=%b twe=%b", mwe, twe); $finish; end
    $display("TEST_PASSED"); $finish;
  end
endmodule
