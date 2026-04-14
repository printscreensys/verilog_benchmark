module power_aware_fsm (
    input wire clk, input wire rst_n, input wire data_in, input wire low_power_mode,
    output reg [7:0] match_count, output reg cg_en
);
    localparam IDLE=0, S1=1, S10=2, SLEEP=3;
    reg [1:0] state, next_state;

    // FSM Sequential
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // FSM Combinational
    always @(*) begin
        cg_en = 1;
        next_state = state;
        
        if (low_power_mode) begin
            next_state = SLEEP;
            cg_en = 0;
        end else begin
            case (state)
                IDLE: if (data_in) next_state = S1; else next_state = IDLE;
                S1:   if (!data_in) next_state = S10; else next_state = S1;
                S10:  if (data_in) next_state = IDLE; else next_state = IDLE;
                SLEEP: next_state = IDLE;
                default: next_state = IDLE;
            endcase
        end
    end

    // INTENTIONAL FLAW: The datapath logic is totally decoupled from the sleep state!
    // It continues looking at the data_in toggles and state changes regardless of power mode.
    // This wastes power and causes state corruption.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            match_count <= 0;
        end else begin
            if (state == S10 && data_in == 1) begin
                match_count <= match_count + 1;
            end
        end
    end
endmodule
