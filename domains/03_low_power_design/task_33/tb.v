`timescale 1ns/1ps

module tb;
  reg clk = 0;
  reg rst = 0;
  reg pic_wakeup = 0;
  reg spr_write = 0;
  reg [31:0] spr_addr = 0;
  reg [31:0] spr_dat_i = 0;
  reg pm_cpustall = 0;
  wire [31:0] spr_dat_o;
  wire [3:0] pm_clksd;
  wire pm_dc_gate, pm_ic_gate, pm_dmmu_gate, pm_immu_gate, pm_tt_gate;
  wire pm_cpu_gate, pm_wakeup, pm_lvolt;

  or1200_pm dut(
    .clk(clk), .rst(rst), .pic_wakeup(pic_wakeup), .spr_write(spr_write),
    .spr_addr(spr_addr), .spr_dat_i(spr_dat_i), .spr_dat_o(spr_dat_o),
    .pm_clksd(pm_clksd), .pm_cpustall(pm_cpustall), .pm_dc_gate(pm_dc_gate),
    .pm_ic_gate(pm_ic_gate), .pm_dmmu_gate(pm_dmmu_gate), .pm_immu_gate(pm_immu_gate),
    .pm_tt_gate(pm_tt_gate), .pm_cpu_gate(pm_cpu_gate), .pm_wakeup(pm_wakeup),
    .pm_lvolt(pm_lvolt)
  );

  always #5 clk = ~clk;

  task expect;
    input cond;
    input [255:0] msg;
    begin
      if (!cond) begin
        $display("TEST_FAILED: %s", msg);
        $finish;
      end
    end
  endtask

  initial begin
    rst = 1;
    repeat (2) @(posedge clk);
    rst = 0;
    @(negedge clk);
    expect(pm_clksd == 4'h0, "reset clears slowdown");
    expect(pm_cpu_gate == 1'b0 && pm_tt_gate == 1'b0, "reset clears gates");

    spr_addr = 32'h0000_2000;
    spr_dat_i = 32'h0000_007a; // sdf=10, dme=1, sme=1, dcge=1
    spr_write = 1;
    @(posedge clk);
    #2;
    spr_write = 0;
    expect(pm_clksd == 4'ha, "slowdown field updates");
    expect(pm_cpu_gate && pm_dc_gate && pm_ic_gate && pm_dmmu_gate && pm_immu_gate, "doze or sleep gates core blocks");
    expect(pm_tt_gate == 1'b1, "sleep gates tick timer");
    expect(spr_dat_o[3:0] == 4'ha && spr_dat_o[4] && spr_dat_o[5] && spr_dat_o[6], "readback fields");
    expect(spr_dat_o[31:7] == 25'd0, "unused bits read zero");

    pm_cpustall = 1;
    #1 expect(pm_lvolt == 1'b1, "cpu stall lowers voltage");
    pm_cpustall = 0;

    pic_wakeup = 1;
    @(posedge clk);
    #2;
    expect(pm_wakeup == 1'b1, "wakeup output follows PIC");
    expect(pm_cpu_gate == 1'b0 && pm_tt_gate == 1'b0, "wakeup degates clocks");
    pic_wakeup = 0;
    @(posedge clk);
    #2;
    expect(spr_dat_o[4] == 1'b0 && spr_dat_o[5] == 1'b0, "wakeup clears doze and sleep");
    expect(pm_clksd == 4'ha, "wakeup preserves slowdown");

    spr_addr = 32'h0000_3000;
    spr_dat_i = 32'h0000_001f;
    spr_write = 1;
    @(posedge clk);
    #2;
    spr_write = 0;
    expect(pm_clksd == 4'ha, "unselected address ignored");

    $display("TEST_PASSED");
    $finish;
  end
endmodule
