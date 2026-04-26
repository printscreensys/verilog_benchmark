`timescale 1ns/1ps
module tb;
  reg clear, phy_ready, phy_valid, tx_valid, cs_set_i, cs_clear, cs_hold;
  reg [7:0] link_cnt, cssck, sckcs, interxfr;
  reg cs_id_i, cs_dflt_i, cs_assert, cs_set, cs_dflt, cs_id;
  reg [1:0] state;
  wire cs_active, cs_update, cs_deassert, continuous;
  wire [7:0] next_cnt;
  wire [1:0] next_state;
  wire next_assert, next_set, next_dflt, next_id, tx_ready, phy_valid_idle;
  sirv_qspi_media_cs_control dut(clear, phy_ready, phy_valid, tx_valid, cs_set_i, cs_clear, cs_hold, link_cnt, cs_id_i, cs_dflt_i, cssck, sckcs, interxfr, state, cs_assert, cs_set, cs_dflt, cs_id, cs_active, cs_update, cs_deassert, continuous, next_cnt, next_state, next_assert, next_set, next_dflt, next_id, tx_ready, phy_valid_idle);
  initial begin
    clear=0; phy_ready=1; phy_valid=1; tx_valid=1; cs_set_i=1; cs_clear=0; cs_hold=0;
    link_cnt=8'd9; cssck=8'd3; sckcs=8'd4; interxfr=8'd0; cs_id_i=0; cs_dflt_i=0; state=0; cs_assert=0; cs_set=0; cs_dflt=0; cs_id=0; #1;
    if (!cs_active || !cs_update || !next_assert || !next_set || !next_dflt || next_cnt != 8'd3 || !phy_valid_idle) begin
      $display("TEST_FAILED idle assert path"); $finish;
    end
    cs_assert=1; cs_dflt=0; cs_hold=0; cs_set_i=0; cs_dflt_i=1; tx_valid=0; clear=0; #1;
    if (!cs_deassert || next_cnt != 8'd4 || next_state != 2'd2 || phy_valid_idle !== 1'b1) begin
      $display("TEST_FAILED deassert path"); $finish;
    end
    clear=1; #1;
    if (!cs_deassert) begin $display("TEST_FAILED clear deassert"); $finish; end
    interxfr=8'd5; #1;
    if (continuous) begin $display("TEST_FAILED continuous"); $finish; end
    $display("TEST_PASSED"); $finish;
  end
endmodule
