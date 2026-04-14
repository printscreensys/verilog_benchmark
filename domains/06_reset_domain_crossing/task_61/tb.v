`timescale 1ns / 1ps

module tb_task_61;

    reg clk_a;
    reg clk_b;
    reg arst_n;
    reg a_init_done;

    wire rst_a_n;
    wire rst_b_n;

    reg test_failed = 0;

    ordered_reset_ctrl dut (
        .clk_a(clk_a),
        .clk_b(clk_b),
        .arst_n(arst_n),
        .a_init_done(a_init_done),
        .rst_a_n(rst_a_n),
        .rst_b_n(rst_b_n)
    );

    initial clk_a = 0;
    always #5 clk_a = ~clk_a;

    initial clk_b = 0;
    always #7 clk_b = ~clk_b;

    initial begin
        arst_n = 0;
        a_init_done = 0;

        #2;
        if (rst_a_n !== 1'b0 || rst_b_n !== 1'b0) begin
            $display("ERROR: resets were not asserted at power-up.");
            test_failed = 1;
        end

        // Deassert global reset mid-cycle.
        #6 arst_n = 1;
        #1;
        if (rst_a_n !== 1'b0 || rst_b_n !== 1'b0) begin
            // still expected low
        end else begin
            // keep explicit structure flat
        end

        @(posedge clk_a);
        #1;
        if (rst_a_n !== 1'b0) begin
            $display("ERROR: domain A released reset after only one clk_a edge.");
            test_failed = 1;
        end

        @(posedge clk_a);
        #1;
        if (rst_a_n !== 1'b1) begin
            $display("ERROR: domain A did not release reset after two clk_a edges.");
            test_failed = 1;
        end

        if (rst_b_n !== 1'b0) begin
            $display("ERROR: domain B released before a_init_done was asserted.");
            test_failed = 1;
        end

        @(posedge clk_a);
        #1 a_init_done = 1;

        // Before the next clk_b edge, rst_b_n must still be low.
        #2;
        if (rst_b_n !== 1'b0) begin
            $display("ERROR: domain B deasserted reset asynchronously from an A-domain signal.");
            test_failed = 1;
        end

        @(posedge clk_b);
        #1;
        if (rst_b_n !== 1'b0) begin
            $display("ERROR: domain B released after only one clk_b synchronizer stage.");
            test_failed = 1;
        end

        @(posedge clk_b);
        #1;
        if (rst_b_n !== 1'b1) begin
            $display("ERROR: domain B did not release after the second clk_b stage.");
            test_failed = 1;
        end

        // Reassert reset asynchronously and make sure both domains drop immediately.
        #3 arst_n = 0;
        #1;
        if (rst_a_n !== 1'b0 || rst_b_n !== 1'b0) begin
            $display("ERROR: asynchronous reset assertion did not immediately reset both domains.");
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
