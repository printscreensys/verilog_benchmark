module scan_reset_override_reg (
    input wire clk,
    input wire rst_n,
    input wire test_mode,
    input wire scan_en,
    input wire scan_in,
    input wire load_en,
    input wire [3:0] data_in,
    output reg [3:0] data_out,
    output reg scan_out
);

    wire dft_rst_n;

    assign dft_rst_n = rst_n | test_mode;

    always @(posedge clk or negedge dft_rst_n) begin
        if (!dft_rst_n) begin
            data_out <= 4'b0000;
            scan_out <= 1'b0;
        end else if (test_mode) begin
            if (scan_en) begin
                scan_out <= data_out[3];
                data_out <= {data_out[2:0], scan_in};
            end
        end else if (load_en) begin
            data_out <= data_in;
        end
    end

endmodule
