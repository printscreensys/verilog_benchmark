module shared_reg (
    input wire clk,
    input wire rst_n,
    input wire req_a,
    input wire [31:0] data_a,
    input wire req_b,
    input wire [31:0] data_b,
    output wire [31:0] read_data
);

    reg [31:0] internal_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            internal_reg <= 32'b0;
        end else if (req_a) begin
            // Agent A has strict priority; evaluated first.
            internal_reg <= data_a;
        end else if (req_b) begin
            // Agent B only gets to write if Agent A is not requesting.
            internal_reg <= data_b;
        end
    end

    assign read_data = internal_reg;

endmodule
