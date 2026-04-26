module dbg_top_tap_next(
    input [3:0] tap_state,
    input TMS,
    output reg [3:0] tap_next_state
);
localparam TAP_TEST_LOGIC_RESET = 4'd0, TAP_RUN_TEST_IDLE = 4'd1,
           TAP_SELECT_DR_SCAN = 4'd2, TAP_CAPTURE_DR = 4'd3,
           TAP_SHIFT_DR = 4'd4, TAP_EXIT1_DR = 4'd5,
           TAP_PAUSE_DR = 4'd6, TAP_EXIT2_DR = 4'd7,
           TAP_UPDATE_DR = 4'd8, TAP_SELECT_IR_SCAN = 4'd9,
           TAP_CAPTURE_IR = 4'd10, TAP_SHIFT_IR = 4'd11,
           TAP_EXIT1_IR = 4'd12, TAP_PAUSE_IR = 4'd13,
           TAP_EXIT2_IR = 4'd14, TAP_UPDATE_IR = 4'd15;
always @* begin
  case(tap_state)
    TAP_TEST_LOGIC_RESET: tap_next_state = TMS ? TAP_TEST_LOGIC_RESET : TAP_RUN_TEST_IDLE;
    TAP_RUN_TEST_IDLE:    tap_next_state = TMS ? TAP_SELECT_DR_SCAN : TAP_RUN_TEST_IDLE;
    TAP_SELECT_DR_SCAN:   tap_next_state = TMS ? TAP_SELECT_IR_SCAN : TAP_CAPTURE_DR;
    TAP_CAPTURE_DR:       tap_next_state = TMS ? TAP_EXIT1_DR : TAP_SHIFT_DR;
    TAP_SHIFT_DR:         tap_next_state = TMS ? TAP_EXIT1_DR : TAP_SHIFT_DR;
    TAP_EXIT1_DR:         tap_next_state = TMS ? TAP_UPDATE_DR : TAP_PAUSE_DR;
    TAP_PAUSE_DR:         tap_next_state = TMS ? TAP_EXIT2_DR : TAP_PAUSE_DR;
    TAP_EXIT2_DR:         tap_next_state = TMS ? TAP_UPDATE_DR : TAP_SHIFT_DR;
    TAP_UPDATE_DR:        tap_next_state = TMS ? TAP_SELECT_DR_SCAN : TAP_RUN_TEST_IDLE;
    TAP_SELECT_IR_SCAN:   tap_next_state = TMS ? TAP_TEST_LOGIC_RESET : TAP_CAPTURE_IR;
    TAP_CAPTURE_IR:       tap_next_state = TMS ? TAP_EXIT1_IR : TAP_SHIFT_IR;
    TAP_SHIFT_IR:         tap_next_state = TMS ? TAP_EXIT1_IR : TAP_SHIFT_IR;
    TAP_EXIT1_IR:         tap_next_state = TMS ? TAP_UPDATE_IR : TAP_PAUSE_IR;
    TAP_PAUSE_IR:         tap_next_state = TMS ? TAP_EXIT2_IR : TAP_PAUSE_IR;
    TAP_EXIT2_IR:         tap_next_state = TMS ? TAP_UPDATE_IR : TAP_SHIFT_IR;
    default:              tap_next_state = TMS ? TAP_SELECT_DR_SCAN : TAP_RUN_TEST_IDLE;
  endcase
end
endmodule
