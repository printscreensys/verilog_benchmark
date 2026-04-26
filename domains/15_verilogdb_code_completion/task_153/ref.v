module adv_dbg_if_wb_cpu0_or1k_counter_mux(
    input tck_i,
    input rst_i,
    input bit_ct_rst,
    input bit_ct_en,
    input [5:0] word_size_bits,
    input word_ct_en,
    input word_ct_sel,
    input [15:0] count_data_in,
    input [1:0] tdo_output_sel,
    input [31:0] data_out_shift_reg,
    input biu_ready,
    input crc_match,
    input crc_serial_out,
    output reg [5:0] bit_count,
    output reg [15:0] word_count,
    output bit_count_max,
    output bit_count_32,
    output word_count_zero,
    output reg module_tdo_o
);
wire [15:0] decremented_word_count;
wire [15:0] data_to_word_counter;
assign data_to_word_counter = (word_ct_sel) ? decremented_word_count : count_data_in;
assign decremented_word_count = word_count - 16'h1;
always @ (posedge tck_i or posedge rst_i)
  begin
    if(rst_i)             bit_count <= 6'h0;
    else if(bit_ct_rst)  bit_count <= 6'h0;
    else if(bit_ct_en)    bit_count <= bit_count + 6'h1;
  end
assign bit_count_max = (bit_count == word_size_bits) ? 1'b1 : 1'b0 ;
assign bit_count_32 = (bit_count == 6'h20) ? 1'b1 : 1'b0;
always @ (posedge tck_i or posedge rst_i)
  begin
    if(rst_i)
      word_count <= 16'h0;
    else if(word_ct_en)
      word_count <= data_to_word_counter;
  end
assign word_count_zero = (word_count == 16'h0);
always @ (tdo_output_sel or data_out_shift_reg[0] or biu_ready or crc_match or crc_serial_out)
  begin
    if(tdo_output_sel == 2'h0) module_tdo_o = biu_ready;
    else if(tdo_output_sel == 2'h1) module_tdo_o = data_out_shift_reg[0];
    else if(tdo_output_sel == 2'h2) module_tdo_o = crc_match;
    else module_tdo_o = crc_serial_out;
  end
endmodule
