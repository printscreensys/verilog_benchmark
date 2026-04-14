module consttime_word_compare (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] lhs,
    input wire [31:0] rhs,
    output reg busy,
    output reg done,
    output reg match
);

    reg [31:0] lhs_q;
    reg [31:0] rhs_q;
    reg [1:0] byte_index;
    reg active;

    wire current_match;

    assign current_match =
        (byte_index == 2'd0) ? (lhs_q[7:0]   == rhs_q[7:0])   :
        (byte_index == 2'd1) ? (lhs_q[15:8]  == rhs_q[15:8])  :
        (byte_index == 2'd2) ? (lhs_q[23:16] == rhs_q[23:16]) :
                               (lhs_q[31:24] == rhs_q[31:24]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lhs_q <= 32'h00000000;
            rhs_q <= 32'h00000000;
            byte_index <= 2'd0;
            active <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            match <= 1'b0;
        end else begin
            done <= 1'b0;
            match <= 1'b0;

            if (!active) begin
                busy <= 1'b0;
                if (start) begin
                    lhs_q <= lhs;
                    rhs_q <= rhs;
                    byte_index <= 2'd0;
                    active <= 1'b1;
                    busy <= 1'b1;
                end
            end else begin
                busy <= 1'b1;

                if (!current_match) begin
                    active <= 1'b0;
                    done <= 1'b1;
                    match <= 1'b0;
                end else if (byte_index == 2'd3) begin
                    active <= 1'b0;
                    done <= 1'b1;
                    match <= 1'b1;
                end else begin
                    byte_index <= byte_index + 2'd1;
                end
            end
        end
    end

endmodule
