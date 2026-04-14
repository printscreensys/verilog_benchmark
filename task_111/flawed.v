module consttime_byte_search (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] haystack,
    input wire [7:0] needle,
    output reg busy,
    output reg done,
    output reg found,
    output reg [2:0] first_index
);

    reg [63:0] haystack_q;
    reg [7:0] needle_q;
    reg [2:0] byte_index;
    reg active;

    wire current_match;

    assign current_match =
        (byte_index == 3'd0) ? (haystack_q[7:0]   == needle_q) :
        (byte_index == 3'd1) ? (haystack_q[15:8]  == needle_q) :
        (byte_index == 3'd2) ? (haystack_q[23:16] == needle_q) :
        (byte_index == 3'd3) ? (haystack_q[31:24] == needle_q) :
        (byte_index == 3'd4) ? (haystack_q[39:32] == needle_q) :
        (byte_index == 3'd5) ? (haystack_q[47:40] == needle_q) :
        (byte_index == 3'd6) ? (haystack_q[55:48] == needle_q) :
                               (haystack_q[63:56] == needle_q);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            haystack_q <= 64'h0000000000000000;
            needle_q <= 8'h00;
            byte_index <= 3'd0;
            active <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            found <= 1'b0;
            first_index <= 3'd0;
        end else begin
            done <= 1'b0;
            found <= 1'b0;
            first_index <= 3'd0;

            if (!active) begin
                busy <= 1'b0;
                if (start) begin
                    haystack_q <= haystack;
                    needle_q <= needle;
                    byte_index <= 3'd0;
                    active <= 1'b1;
                    busy <= 1'b1;
                end
            end else begin
                busy <= 1'b1;

                if (current_match) begin
                    active <= 1'b0;
                    done <= 1'b1;
                    found <= 1'b1;
                    first_index <= byte_index;
                end else if (byte_index == 3'd7) begin
                    active <= 1'b0;
                    done <= 1'b1;
                    found <= 1'b0;
                    first_index <= 3'd0;
                end else begin
                    byte_index <= byte_index + 3'd1;
                end
            end
        end
    end

endmodule
