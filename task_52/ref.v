module jtag_tap_debug (
    input wire tck,
    input wire trst_n,
    input wire tms,
    input wire tdi,
    output reg tdo,
    input wire [7:0] dbg_status,
    output reg [7:0] dbg_control
);

    localparam ST_TEST_LOGIC_RESET = 4'd0;
    localparam ST_RUN_TEST_IDLE    = 4'd1;
    localparam ST_SELECT_DR_SCAN   = 4'd2;
    localparam ST_CAPTURE_DR       = 4'd3;
    localparam ST_SHIFT_DR         = 4'd4;
    localparam ST_UPDATE_DR        = 4'd5;
    localparam ST_SELECT_IR_SCAN   = 4'd6;
    localparam ST_CAPTURE_IR       = 4'd7;
    localparam ST_SHIFT_IR         = 4'd8;
    localparam ST_UPDATE_IR        = 4'd9;

    localparam IR_IDCODE  = 4'b0001;
    localparam IR_DBG_CTL = 4'b0010;
    localparam IR_DBG_STAT = 4'b0011;

    reg [3:0] state;
    reg [3:0] ir;
    reg [3:0] ir_shift;
    reg [7:0] dr_shift;

    function [3:0] tap_next_state;
        input [3:0] current_state;
        input tms_value;
        begin
            case (current_state)
                ST_TEST_LOGIC_RESET: tap_next_state = tms_value ? ST_TEST_LOGIC_RESET : ST_RUN_TEST_IDLE;
                ST_RUN_TEST_IDLE:    tap_next_state = tms_value ? ST_SELECT_DR_SCAN : ST_RUN_TEST_IDLE;
                ST_SELECT_DR_SCAN:   tap_next_state = tms_value ? ST_SELECT_IR_SCAN : ST_CAPTURE_DR;
                ST_CAPTURE_DR:       tap_next_state = tms_value ? ST_UPDATE_DR : ST_SHIFT_DR;
                ST_SHIFT_DR:         tap_next_state = tms_value ? ST_UPDATE_DR : ST_SHIFT_DR;
                ST_UPDATE_DR:        tap_next_state = tms_value ? ST_TEST_LOGIC_RESET : ST_RUN_TEST_IDLE;
                ST_SELECT_IR_SCAN:   tap_next_state = tms_value ? ST_TEST_LOGIC_RESET : ST_CAPTURE_IR;
                ST_CAPTURE_IR:       tap_next_state = tms_value ? ST_UPDATE_IR : ST_SHIFT_IR;
                ST_SHIFT_IR:         tap_next_state = tms_value ? ST_UPDATE_IR : ST_SHIFT_IR;
                ST_UPDATE_IR:        tap_next_state = tms_value ? ST_TEST_LOGIC_RESET : ST_RUN_TEST_IDLE;
                default:             tap_next_state = ST_TEST_LOGIC_RESET;
            endcase
        end
    endfunction

    always @(posedge tck or negedge trst_n) begin
        if (!trst_n) begin
            state <= ST_TEST_LOGIC_RESET;
            ir <= IR_IDCODE;
            ir_shift <= 4'b0101;
            dr_shift <= 8'h00;
            dbg_control <= 8'h00;
            tdo <= 1'b0;
        end else begin
            if (state != ST_SHIFT_IR && state != ST_SHIFT_DR) begin
                tdo <= 1'b0;
            end

            case (state)
                ST_CAPTURE_IR: begin
                    ir_shift <= 4'b0101;
                end
                ST_SHIFT_IR: begin
                    tdo <= ir_shift[0];
                    ir_shift <= {tdi, ir_shift[3:1]};
                end
                ST_UPDATE_IR: begin
                    ir <= ir_shift;
                end
                ST_CAPTURE_DR: begin
                    case (ir)
                        IR_IDCODE:   dr_shift <= 8'hA5;
                        IR_DBG_CTL:  dr_shift <= dbg_control;
                        IR_DBG_STAT: dr_shift <= dbg_status;
                        default:     dr_shift <= 8'h00;
                    endcase
                end
                ST_SHIFT_DR: begin
                    tdo <= dr_shift[0];
                    dr_shift <= {tdi, dr_shift[7:1]};
                end
                ST_UPDATE_DR: begin
                    if (ir == IR_DBG_CTL) begin
                        dbg_control <= dr_shift;
                    end
                end
                default: begin
                end
            endcase

            state <= tap_next_state(state, tms);
        end
    end

endmodule
