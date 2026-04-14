module queue_credit_tracker (
    input wire clk,
    input wire rst_n,
    input wire push,
    input wire pop,
    input wire flush,
    input wire [1:0] cfg_limit,
    output reg [2:0] count,
    output wire full,
    output wire empty,
    output reg overflow_pulse,
    output reg underflow_pulse
);

    wire [2:0] limit_value;
    assign limit_value = {1'b0, cfg_limit} + 3'd1;

    assign full = (count == limit_value);
    assign empty = (count == 3'd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 3'd0;
            overflow_pulse <= 1'b0;
            underflow_pulse <= 1'b0;
        end else begin
            overflow_pulse <= 1'b0;
            underflow_pulse <= 1'b0;

            if (flush) begin
                count <= 3'd0;
            end else if (push && !pop) begin
                if (count < limit_value) begin
                    count <= count + 3'd1;
                end else begin
                    count <= count;
                    overflow_pulse <= 1'b1;
                end
            end else if (!push && pop) begin
                if (count > 3'd0) begin
                    count <= count - 3'd1;
                end else begin
                    count <= count;
                    underflow_pulse <= 1'b1;
                end
            end else if (push && pop) begin
                if (count == 3'd0) begin
                    count <= count + 3'd1;
                end else if (count == limit_value) begin
                    count <= count - 3'd1;
                end else begin
                    count <= count;
                end
            end
        end
    end

endmodule
