module triple_reset_sequencer (
    input wire clk_cpu,
    input wire clk_bus,
    input wire clk_periph,
    input wire arst_n,
    output wire rst_cpu_n,
    output wire rst_bus_n,
    output wire rst_periph_n
);

    // INTENTIONAL FLAW: release ordering is purely combinational and asynchronous.
    assign rst_cpu_n = arst_n;
    assign rst_bus_n = arst_n & rst_cpu_n;
    assign rst_periph_n = arst_n & rst_bus_n;

endmodule
