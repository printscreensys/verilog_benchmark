module power_aware_fsm (
    input wire clk,
    input wire rst_n,
    input wire data_in,
    input wire low_power_mode,
    output reg [7:0] match_count,
    output reg cg_en
);

    localparam IDLE  = 3'd0;
    localparam S1    = 3'd1;
    localparam S10   = 3'd2;
    localparam SLEEP = 3'd3;

    reg [2:0] state, next_state;
    reg inc_count;

    // Sequential State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            match_count <= 8'd0;
        end else begin
            state <= next_state;
            if (inc_count && !low_power_mode && state != SLEEP) begin
                match_count <= match_count + 1'b1;
            end
        end
    end

    // Combinational Next State & Output Logic
    always @(*) begin
        next_state = state;
        cg_en = 1'b1;
        inc_count = 1'b0;

        if (low_power_mode) begin
            next_state = SLEEP;
            cg_en = 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (data_in) next_state = S1;
                end
                S1: begin
                    if (!data_in) next_state = S10;
                end
                S10: begin
                    if (data_in) begin
                        inc_count = 1'b1;
                        next_state = IDLE; // Non-overlapping
                    end else begin
                        next_state = IDLE;
                    end
                end
                SLEEP: begin
                    // Already checked !low_power_mode above
                    next_state = IDLE;
                end
                default: next_state = IDLE;
            endcase
        end
    end

endmodule
