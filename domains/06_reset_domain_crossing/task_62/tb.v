`timescale 1ns / 1ps

module tb_task_62;

    reg clk_cpu;
    reg clk_bus;
    reg clk_periph;
    reg arst_n;

    wire rst_cpu_n;
    wire rst_bus_n;
    wire rst_periph_n;

    reg test_failed = 0;

    triple_reset_sequencer dut (
        .clk_cpu(clk_cpu),
        .clk_bus(clk_bus),
        .clk_periph(clk_periph),
        .arst_n(arst_n),
        .rst_cpu_n(rst_cpu_n),
        .rst_bus_n(rst_bus_n),
        .rst_periph_n(rst_periph_n)
    );

    initial clk_cpu = 0;
    always #4 clk_cpu = ~clk_cpu;

    initial clk_bus = 0;
    always #6 clk_bus = ~clk_bus;

    initial clk_periph = 0;
    always #9 clk_periph = ~clk_periph;

    initial begin
        arst_n = 0;

        #2;
        if (rst_cpu_n !== 1'b0 || rst_bus_n !== 1'b0 || rst_periph_n !== 1'b0) begin
            $display("ERROR: not all domains were held in reset during global reset.");
            test_failed = 1;
        end

        // Deassert asynchronously.
        #5 arst_n = 1;
        #1;
        if (rst_cpu_n !== 1'b0 || rst_bus_n !== 1'b0 || rst_periph_n !== 1'b0) begin
            // expected to stay low
        end else begin
            // keep flat formatting
        end

        @(posedge clk_cpu);
        #1;
        if (rst_cpu_n !== 1'b0) begin
            $display("ERROR: CPU reset released after one edge instead of two.");
            test_failed = 1;
        end

        @(posedge clk_cpu);
        #1;
        if (rst_cpu_n !== 1'b1) begin
            $display("ERROR: CPU reset did not release after two clk_cpu edges.");
            test_failed = 1;
        end

        if (rst_bus_n !== 1'b0 || rst_periph_n !== 1'b0) begin
            $display("ERROR: downstream domains released before CPU was safely active.");
            test_failed = 1;
        end

        @(posedge clk_bus);
        #1;
        if (rst_bus_n !== 1'b0) begin
            $display("ERROR: BUS reset released after one synchronizer stage.");
            test_failed = 1;
        end

        @(posedge clk_bus);
        #1;
        if (rst_bus_n !== 1'b1) begin
            $display("ERROR: BUS reset did not release after the second synchronized stage.");
            test_failed = 1;
        end

        if (rst_periph_n !== 1'b0) begin
            $display("ERROR: PERIPH reset released before BUS reset was synchronized.");
            test_failed = 1;
        end

        @(posedge clk_periph);
        #1;
        if (rst_periph_n !== 1'b0) begin
            $display("ERROR: PERIPH reset released after one synchronizer stage.");
            test_failed = 1;
        end

        @(posedge clk_periph);
        #1;
        if (rst_periph_n !== 1'b1) begin
            $display("ERROR: PERIPH reset did not release after two synchronized stages.");
            test_failed = 1;
        end

        // Reassert reset and ensure immediate assertion across all domains.
        #3 arst_n = 0;
        #1;
        if (rst_cpu_n !== 1'b0 || rst_bus_n !== 1'b0 || rst_periph_n !== 1'b0) begin
            $display("ERROR: asynchronous reassertion did not drop all local resets immediately.");
            test_failed = 1;
        end

        #10;
        if (test_failed == 0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end
        $finish;
    end

endmodule
