module tessera_sdram_req_sync(
    input sys_sdram_clk,
    input sys_sdram_res,
    input wbif_write_req,
    input [3:0] wbif_write_byte,
    input [31:0] wbif_write_address,
    input [31:0] wbif_write_data,
    input wbif_read_req,
    input [3:0] wbif_read_byte,
    input [31:0] wbif_read_address,
    output reg mt1_write_req,
    output reg [3:0] mt1_write_byte,
    output reg [31:0] mt1_write_address,
    output reg [31:0] mt1_write_data,
    output reg mt1_read_req,
    output reg [3:0] mt1_read_byte,
    output reg [31:0] mt1_read_address,
    output reg mt2_write_req,
    output reg [3:0] mt2_write_byte,
    output reg [31:0] mt2_write_address,
    output reg [31:0] mt2_write_data,
    output reg mt2_read_req,
    output reg [3:0] mt2_read_byte,
    output reg [31:0] mt2_read_address
);
always @(posedge sys_sdram_clk or posedge sys_sdram_res)
    if (sys_sdram_res)
        {mt1_write_req, mt1_write_byte, mt1_write_address, mt1_write_data, mt1_read_req, mt1_read_byte, mt1_read_address} <= 106'd0;
    else
        {mt1_write_req, mt1_write_byte, mt1_write_address, mt1_write_data, mt1_read_req, mt1_read_byte, mt1_read_address} <= {wbif_write_req, wbif_write_byte, wbif_write_address, wbif_write_data, wbif_read_req, wbif_read_byte, wbif_read_address};
always @(posedge sys_sdram_clk or posedge sys_sdram_res)
    if (sys_sdram_res)
        {mt2_write_req, mt2_write_byte, mt2_write_address, mt2_write_data, mt2_read_req, mt2_read_byte, mt2_read_address} <= 106'd0;
    else
        {mt2_write_req, mt2_write_byte, mt2_write_address, mt2_write_data, mt2_read_req, mt2_read_byte, mt2_read_address} <= {mt1_write_req, mt1_write_byte, mt1_write_address, mt1_write_data, mt1_read_req, mt1_read_byte, mt1_read_address};
endmodule
