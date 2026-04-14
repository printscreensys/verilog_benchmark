`timescale 1ns / 1ps

module tb_task_60;

    reg clk;
    reg arst_n;
    wire srst_n;

    reg test_failed = 0;

    reset_sync_2ff dut (
        .clk(clk),
        .arst_n(arst_n),
        .srst_n(srst_n)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        arst_n = 0;

        #2;
        if (srst_n !== 1'b0) begin
            $display("ERROR: reset was not asserted immediately.");
            test_failed = 1;
        end

        // Deassert reset mid-cycle. Local reset must wait two full rising edges.
        #6 arst_n = 1;
        #1;
        if (srst_n !== 1'b0) begin
            $display("ERROR: local reset deasserted asynchronously before clock synchronization.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (srst_n !== 1'b0) begin
            $display("ERROR: local reset deasserted after only one clock edge.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (srst_n !== 1'b1) begin
            $display("ERROR: local reset did not deassert after two clock edges.");
            test_failed = 1;
        end

        // Reassert asynchronously in the middle of operation.
        #3 arst_n = 0;
        #1;
        if (srst_n !== 1'b0) begin
            $display("ERROR: asynchronous assertion failed during active operation.");
            test_failed = 1;
        end

        // Restart deassertion sequence and make sure it fully restarts.
        #2 arst_n = 1;
        #1;
        if (srst_n !== 1'b0) begin
            $display("ERROR: deassertion restarted asynchronously instead of synchronously.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (srst_n !== 1'b0) begin
            $display("ERROR: restart sequence released reset too early after one edge.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (srst_n !== 1'b1) begin
            $display("ERROR: restart sequence failed to release reset after two edges.");
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
