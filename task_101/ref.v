module lockstep_event_counter (
    input wire clk,
    input wire rst_n,
    input wire load,
    input wire step,
    input wire [3:0] load_value,
    input wire inject_shadow_fault,
    output wire [3:0] count,
    output wire count_valid,
    output reg fault_flag,
    output wire halted
);

    reg [3:0] primary_count;
    reg [3:0] shadow_count;
    wire [3:0] advanced_primary;
    wire [3:0] advanced_shadow_base;
    wire [3:0] advanced_shadow;

    assign count = (!rst_n || fault_flag) ? 4'h0 : primary_count;
    assign count_valid = rst_n && !fault_flag;
    assign halted = rst_n && fault_flag;
    assign advanced_primary = load ? load_value :
                              step ? (primary_count + 4'h1) :
                              primary_count;
    assign advanced_shadow_base = load ? load_value :
                                  step ? (shadow_count + 4'h1) :
                                  shadow_count;
    assign advanced_shadow = inject_shadow_fault ?
        (advanced_shadow_base ^ 4'b0001) : advanced_shadow_base;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            primary_count <= 4'h0;
            shadow_count <= 4'h0;
            fault_flag <= 1'b0;
        end else if (!fault_flag) begin
            primary_count <= advanced_primary;
            shadow_count <= advanced_shadow;

            if (advanced_primary != advanced_shadow) begin
                fault_flag <= 1'b1;
            end
        end
    end

endmodule
