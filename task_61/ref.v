module ordered_reset_ctrl (
    input wire clk_a,
    input wire clk_b,
    input wire arst_n,
    input wire a_init_done,
    output wire rst_a_n,
    output wire rst_b_n
);

    reg [1:0] a_reset_sync;
    reg [1:0] b_ready_sync;
    wire a_ready;

    always @(posedge clk_a or negedge arst_n) begin
        if (!arst_n) begin
            a_reset_sync <= 2'b00;
        end else begin
            a_reset_sync <= {a_reset_sync[0], 1'b1};
        end
    end

    assign rst_a_n = a_reset_sync[1];
    assign a_ready = rst_a_n & a_init_done;

    always @(posedge clk_b or negedge arst_n) begin
        if (!arst_n) begin
            b_ready_sync <= 2'b00;
        end else begin
            b_ready_sync <= {b_ready_sync[0], a_ready};
        end
    end

    assign rst_b_n = b_ready_sync[1];

endmodule
