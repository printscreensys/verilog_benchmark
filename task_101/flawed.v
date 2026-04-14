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
    reg [3:0] next_primary;
    reg [3:0] next_shadow;

    assign count = rst_n ? primary_count : 4'h0;
    assign count_valid = rst_n;
    assign halted = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            primary_count <= 4'h0;
            shadow_count <= 4'h0;
            fault_flag <= 1'b0;
        end else begin
            next_primary = primary_count;
            next_shadow = shadow_count;

            if (load) begin
                next_primary = load_value;
                next_shadow = load_value;
            end else if (step) begin
                next_primary = primary_count + 4'h1;
                next_shadow = shadow_count + 4'h1;
            end

            if (inject_shadow_fault) begin
                next_shadow = next_shadow ^ 4'b0001;
            end

            primary_count <= next_primary;
            shadow_count <= next_shadow;
            fault_flag <= (next_primary != next_shadow);
        end
    end

endmodule
