`timescale 1ns / 1ps

module tb_task_63;

    reg clk;
    reg arst_n;
    reg [1:0] release_delay;

    wire srst_n;
    wire init_pulse;

    reg test_failed = 0;

    delayed_reset_release dut (
        .clk(clk),
        .arst_n(arst_n),
        .release_delay(release_delay),
        .srst_n(srst_n),
        .init_pulse(init_pulse)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        arst_n = 0;
        release_delay = 2'd2;

        #2;
        if (srst_n !== 1'b0 || init_pulse !== 1'b0) begin
            $display("ERROR: outputs were not properly reset.");
            test_failed = 1;
        end

        // Release with delay=2. Expect two sync cycles plus two extra hold cycles.
        #6 arst_n = 1;

        @(posedge clk);
        #1;
        if (srst_n !== 1'b0) begin
            $display("ERROR: reset released after only one synchronizer edge.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (srst_n !== 1'b0 || init_pulse !== 1'b0) begin
            $display("ERROR: reset released before the extra delay window started.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (srst_n !== 1'b0 || init_pulse !== 1'b0) begin
            $display("ERROR: extra hold cycle 1 failed.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (srst_n !== 1'b0 || init_pulse !== 1'b0) begin
            $display("ERROR: extra hold cycle 2 failed.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (srst_n !== 1'b1 || init_pulse !== 1'b1) begin
            $display("ERROR: reset did not release with a one-cycle init pulse after the full delay.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (srst_n !== 1'b1 || init_pulse !== 1'b0) begin
            $display("ERROR: init_pulse was not exactly one cycle wide.");
            test_failed = 1;
        end

        // Reassert and test delay=0 path.
        #3 arst_n = 0;
        #1;
        if (srst_n !== 1'b0 || init_pulse !== 1'b0) begin
            $display("ERROR: asynchronous reassertion failed.");
            test_failed = 1;
        end

        release_delay = 2'd0;
        #4 arst_n = 1;

        @(posedge clk);
        #1;
        if (srst_n !== 1'b0) begin
            $display("ERROR: delay=0 still requires the base synchronizer and should stay low after one edge.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (srst_n !== 1'b1 || init_pulse !== 1'b1) begin
            $display("ERROR: delay=0 did not release immediately after the base synchronizer completed.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (init_pulse !== 1'b0) begin
            $display("ERROR: delay=0 init_pulse lasted too long.");
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
