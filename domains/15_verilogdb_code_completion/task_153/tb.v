`timescale 1ns/1ps
module tb;
  reg clk = 0, rst = 0, bit_ct_rst = 0, bit_ct_en = 0, word_ct_en = 0, word_ct_sel = 0;
  reg [5:0] word_size_bits = 6'd3;
  reg [15:0] count_data_in = 0;
  reg [1:0] tdo_output_sel = 0;
  reg [31:0] data_out_shift_reg = 0;
  reg biu_ready = 0, crc_match = 0, crc_serial_out = 0;
  wire [5:0] bit_count;
  wire [15:0] word_count;
  wire bit_count_max, bit_count_32, word_count_zero, module_tdo_o;
  adv_dbg_if_wb_cpu0_or1k_counter_mux dut(clk, rst, bit_ct_rst, bit_ct_en, word_size_bits, word_ct_en, word_ct_sel, count_data_in, tdo_output_sel, data_out_shift_reg, biu_ready, crc_match, crc_serial_out, bit_count, word_count, bit_count_max, bit_count_32, word_count_zero, module_tdo_o);
  always #5 clk = ~clk;
  initial begin
    rst = 1; @(posedge clk); #1 rst = 0;
    if (bit_count != 0 || word_count != 0 || !word_count_zero) begin $display("TEST_FAILED reset"); $finish; end
    bit_ct_en = 1; repeat (3) @(posedge clk); #1;
    if (bit_count != 3 || !bit_count_max) begin $display("TEST_FAILED bit counter"); $finish; end
    bit_ct_rst = 1; @(posedge clk); #1 bit_ct_rst = 0; bit_ct_en = 0;
    if (bit_count != 0) begin $display("TEST_FAILED bit reset"); $finish; end
    count_data_in = 16'd5; word_ct_en = 1; word_ct_sel = 0; @(posedge clk); #1;
    if (word_count != 16'd5) begin $display("TEST_FAILED word load"); $finish; end
    word_ct_sel = 1; @(posedge clk); #1;
    if (word_count != 16'd4) begin $display("TEST_FAILED word decrement"); $finish; end
    biu_ready = 1; tdo_output_sel = 0; #1 if (!module_tdo_o) begin $display("TEST_FAILED tdo biu"); $finish; end
    data_out_shift_reg = 32'h1; tdo_output_sel = 1; #1 if (!module_tdo_o) begin $display("TEST_FAILED tdo data"); $finish; end
    crc_match = 1; tdo_output_sel = 2; #1 if (!module_tdo_o) begin $display("TEST_FAILED tdo crc_match"); $finish; end
    crc_serial_out = 1; tdo_output_sel = 3; #1 if (!module_tdo_o) begin $display("TEST_FAILED tdo crc_serial"); $finish; end
    $display("TEST_PASSED"); $finish;
  end
endmodule
