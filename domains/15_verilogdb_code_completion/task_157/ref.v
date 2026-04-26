module or1200_immu_no_mmu_path #(
    parameter OR1200_IMMU_PS = 13,
    parameter OR1200_IMMU_CI = 1'b0
)(
    input clk,
    input rst,
    input icpu_adr_select,
    input [31:0] icpu_adr_boot,
    input [31:0] icpu_adr_default,
    input [31:0] icpu_adr_i,
    input icpu_cycstb_i,
    input qmemimmu_rty_i,
    input qmemimmu_err_i,
    input [3:0] qmemimmu_tag_i,
    input mbist_si_i,
    output reg [31:0] icpu_adr_o,
    output page_cross,
    output reg [31-OR1200_IMMU_PS:0] icpu_vpn_r,
    output [31:0] spr_dat_o,
    output [31:0] qmemimmu_adr_o,
    output [3:0] icpu_tag_o,
    output qmemimmu_cycstb_o,
    output icpu_rty_o,
    output icpu_err_o,
    output qmemimmu_ci_o,
    output mbist_so_o
);
always @(icpu_adr_boot or icpu_adr_default or icpu_adr_select)
    if (icpu_adr_select)
        icpu_adr_o = icpu_adr_boot ;
    else
        icpu_adr_o = icpu_adr_default ;

assign page_cross = icpu_adr_i[31:OR1200_IMMU_PS] != icpu_vpn_r;

always @(posedge clk or posedge rst)
    if (rst)
        icpu_vpn_r <=  {32-OR1200_IMMU_PS{1'b0}};
    else
        icpu_vpn_r <=  icpu_adr_i[31:OR1200_IMMU_PS];

assign spr_dat_o = 32'h00000000;
assign qmemimmu_adr_o = icpu_adr_i;
assign icpu_tag_o = qmemimmu_tag_i;
assign qmemimmu_cycstb_o = icpu_cycstb_i & ~page_cross;
assign icpu_rty_o = qmemimmu_rty_i;
assign icpu_err_o = qmemimmu_err_i;
assign qmemimmu_ci_o = OR1200_IMMU_CI;
assign mbist_so_o = mbist_si_i;
endmodule
