`timescale 1ns/1ps

module tb;
  reg clk = 0;
  reg rstn = 0;
  reg [`DATA_WIDTH-1:0] data_i = 0;
  reg valid_i = 0;
  wire ready_o;
  wire A_valid_o;
  reg A_ready_i = 0;
  wire [`DATA_WIDTH-1:0] A_data_o;
  wire B_valid_o;
  reg B_ready_i = 0;
  wire [`DATA_WIDTH-1:0] B_data_o;

  alloc_two #(.CHANNEL_ID(`LEFT), .ROUTER_ID_X(2), .ROUTER_ID_Y(1)) dut(
    .clk(clk), .rstn(rstn), .data_i(data_i), .valid_i(valid_i), .ready_o(ready_o),
    .A_valid_o(A_valid_o), .A_ready_i(A_ready_i), .A_data_o(A_data_o),
    .B_valid_o(B_valid_o), .B_ready_i(B_ready_i), .B_data_o(B_data_o)
  );

  always #5 clk = ~clk;

  function [`DATA_WIDTH-1:0] flit;
    input [1:0] kind;
    input [3:0] x;
    input [3:0] y;
    input [7:0] payload;
    reg [`DATA_WIDTH-1:0] tmp;
    begin
      tmp = 0;
      tmp[`DATA_WIDTH-1:`DATA_WIDTH-2] = kind;
      tmp[`RTID_H:`RTID_L] = {x, y};
      tmp[7:0] = payload;
      flit = tmp;
    end
  endfunction

  task fail;
    input [255:0] msg;
    begin
      $display("TEST_FAILED: %s", msg);
      $finish;
    end
  endtask

  task push_flit;
    input [`DATA_WIDTH-1:0] value;
    begin
      @(negedge clk);
      if (!ready_o) fail("input not ready");
      data_i = value;
      valid_i = 1;
      @(negedge clk);
      valid_i = 0;
      data_i = 0;
    end
  endtask

  task reset_dut;
    begin
      rstn = 0;
      valid_i = 0;
      A_ready_i = 0;
      B_ready_i = 0;
      repeat (2) @(posedge clk);
      rstn = 1;
      repeat (2) @(posedge clk);
    end
  endtask

  initial begin
    reset_dut();

    push_flit(flit(`TAIL, 4'd2, 4'd3, 8'ha1));
    #1;
    if (!A_valid_o || B_valid_o) fail("LEFT port must route greater Y to A");
    if (A_data_o[7:0] != 8'ha1 || B_data_o[7:0] != 8'ha1) fail("output data must mirror FIFO data");
    A_ready_i = 1;
    @(posedge clk);
    #1;
    A_ready_i = 0;

    reset_dut();
    push_flit(flit(`TAIL, 4'd0, 4'd1, 8'hb1));
    #1;
    if (!B_valid_o || A_valid_o) fail("LEFT port must route equal Y to B");
    B_ready_i = 1;
    @(posedge clk);
    #1;
    B_ready_i = 0;

    reset_dut();
    push_flit(flit(2'b00, 4'd3, 4'd3, 8'hc1));
    push_flit(flit(2'b01, 4'd3, 4'd0, 8'hc2));
    push_flit(flit(`TAIL, 4'd3, 4'd0, 8'hc3));
    #1;
    if (!A_valid_o || B_valid_o) fail("packet head should choose A");
    A_ready_i = 1;
    @(posedge clk);
    #1;
    if (!A_valid_o || B_valid_o) fail("body flit must stay locked to A despite changed route");
    @(posedge clk);
    #1;
    if (!A_valid_o || B_valid_o) fail("tail flit must stay locked to A");
    @(posedge clk);
    #1;
    A_ready_i = 0;

    push_flit(flit(`TAIL, 4'd1, 4'd1, 8'hd1));
    #1;
    if (!B_valid_o || A_valid_o) fail("route lock must release after tail");
    B_ready_i = 1;
    @(posedge clk);
    #1;

    $display("TEST_PASSED");
    $finish;
  end
endmodule
