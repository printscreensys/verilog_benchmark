module ordered_reset_ctrl (
    input wire clk_a,
    input wire clk_b,
    input wire arst_n,
    input wire a_init_done,
    output wire rst_a_n,
    output wire rst_b_n
);

    // INTENTIONAL FLAW: both domains release asynchronously and B is directly gated
    // by an unsynchronized A-domain signal.
    assign rst_a_n = arst_n;
    assign rst_b_n = arst_n & rst_a_n & a_init_done;

endmodule
