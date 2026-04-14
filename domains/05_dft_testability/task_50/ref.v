module scan_reg8 (
    input wire clk,
    input wire rst_n,
    input wire scan_en,
    input wire scan_in,
    input wire load_en,
    input wire [7:0] data_in,
    output reg [7:0] data_out,
    output reg scan_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 8'b0;
            scan_out <= 1'b0;
        end else if (scan_en) begin
            scan_out <= data_out[7];
            data_out <= {data_out[6:0], scan_in};
        end else if (load_en) begin
            data_out <= data_in;
        end
    end

endmodule
