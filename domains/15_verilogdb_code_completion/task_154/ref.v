module sirv_qspi_media_cs_control(
    input clear,
    input phy_io_op_ready,
    input phy_io_op_valid,
    input io_link_tx_valid,
    input io_link_cs_set,
    input io_link_cs_clear,
    input io_link_cs_hold,
    input [7:0] io_link_cnt,
    input io_ctrl_cs_id,
    input io_ctrl_cs_dflt_0,
    input [7:0] io_ctrl_dla_cssck,
    input [7:0] io_ctrl_dla_sckcs,
    input [7:0] io_ctrl_dla_interxfr,
    input [1:0] state,
    input cs_assert,
    input cs_set,
    input cs_dflt_0,
    input cs_id,
    output cs_active_0,
    output cs_update,
    output cs_deassert,
    output continuous,
    output [7:0] next_cnt_idle,
    output [1:0] next_state_idle,
    output next_cs_assert_idle,
    output next_cs_set_idle,
    output next_cs_dflt_idle,
    output next_cs_id_idle,
    output tx_ready_idle,
    output phy_valid_idle
);
wire idle;
wire transfer_done;
wire [1:0] cs_mask;
assign idle = state == 2'd0;
assign transfer_done = phy_io_op_ready & phy_io_op_valid;
assign cs_mask = {1'b0, io_ctrl_cs_dflt_0} ^ ({1'b0, io_link_cs_set} << io_ctrl_cs_id);
assign cs_active_0 = cs_mask[0];
assign cs_update = cs_active_0 != cs_dflt_0;
assign cs_deassert = clear | (cs_update & !io_link_cs_hold);
assign continuous = io_ctrl_dla_interxfr == 8'h0;
assign next_cnt_idle = idle ? ((!cs_assert && io_link_tx_valid) ? io_ctrl_dla_cssck : (cs_assert && cs_deassert) ? io_ctrl_dla_sckcs : io_link_cnt) : io_link_cnt;
assign next_state_idle = idle ? ((cs_assert && !cs_deassert && transfer_done) ? 2'd1 : (cs_assert && cs_deassert && phy_io_op_ready) ? 2'd2 : state) : state;
assign next_cs_assert_idle = idle ? ((!cs_assert && io_link_tx_valid) ? (phy_io_op_ready ? 1'b1 : cs_assert) : cs_assert) : cs_assert;
assign next_cs_set_idle = idle ? ((!cs_assert && io_link_tx_valid && phy_io_op_ready) ? io_link_cs_set : cs_set) : cs_set;
assign next_cs_dflt_idle = idle ? ((!cs_assert && io_link_tx_valid && phy_io_op_ready) ? cs_active_0 : cs_dflt_0) : cs_dflt_0;
assign next_cs_id_idle = io_ctrl_cs_id;
assign tx_ready_idle = idle && cs_assert && !cs_deassert ? phy_io_op_ready : 1'b0;
assign phy_valid_idle = idle ? (cs_assert ? (cs_deassert ? 1'b1 : io_link_tx_valid) : 1'b1) : 1'b1;
endmodule
