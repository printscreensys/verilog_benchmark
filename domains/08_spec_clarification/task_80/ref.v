module event_counter_alert (
    input wire clk,
    input wire rst,
    input wire event_valid,
    input wire clear,
    output reg [3:0] count,
    output reg overflow
);

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            count <= 4'h0;
            overflow <= 1'b0;
        end else if (clear) begin
            count <= 4'h0;
            overflow <= 1'b0;
        end else if (event_valid) begin
            if (count == 4'hF) begin
                count <= 4'hF;
                overflow <= 1'b1;
            end else begin
                count <= count + 4'h1;
            end
        end
    end

endmodule
