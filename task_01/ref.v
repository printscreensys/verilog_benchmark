module secure_reg #(
    parameter SECURE_MODE = 1
)(
    input wire clk,
    input wire rst_n,
    input wire write_en,
    input wire [31:0] secret_data,
    output wire [31:0] debug_out
);

    reg [31:0] internal_secret;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            internal_secret <= 32'b0;
        end else if (write_en) begin
            internal_secret <= secret_data;
        end
    end

    // Security check: only allow data to flow to debug_out if SECURE_MODE is 0
    assign debug_out = (SECURE_MODE == 1) ? 32'b0 : internal_secret;

endmodule
