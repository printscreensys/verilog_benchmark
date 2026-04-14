module reset_sync_2ff (
    input wire clk,
    input wire arst_n,
    output wire srst_n
);

    // INTENTIONAL FLAW: reset deassertion is asynchronous and bypasses synchronizer flops.
    assign srst_n = arst_n;

endmodule
