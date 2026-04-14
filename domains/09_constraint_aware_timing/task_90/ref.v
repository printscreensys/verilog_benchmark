module dual_mac_timing(clk, rst_n, in_valid, a, b, c, d, out_valid, y);
input clk;
input rst_n;
input in_valid;
input signed [15:0] a;
input signed [15:0] b;
input signed [15:0] c;
input signed [15:0] d;
output out_valid;
output signed [32:0] y;

reg valid_s1;
reg valid_s2;
reg signed [31:0] prod_ab_r;
reg signed [31:0] prod_cd_r;
reg signed [32:0] y_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_s1 <= 1'b0;
        valid_s2 <= 1'b0;
        prod_ab_r <= 32'sd0;
        prod_cd_r <= 32'sd0;
        y_r <= 33'sd0;
    end else begin
        valid_s1 <= in_valid;
        valid_s2 <= valid_s1;

        if (in_valid) begin
            prod_ab_r <= a * b;
            prod_cd_r <= c * d;
        end

        if (valid_s1) begin
            y_r <= $signed(prod_ab_r) + $signed(prod_cd_r);
        end
    end
end

assign out_valid = valid_s2;
assign y = y_r;

endmodule
