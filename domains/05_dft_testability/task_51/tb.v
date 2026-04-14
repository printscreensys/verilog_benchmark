`timescale 1ns / 1ps

module tb_task_51;

    reg clk;
    reg rst_n;
    reg test_mode;
    reg scan_en;
    reg scan_in;
    reg load_en;
    reg [3:0] data_in;

    wire [3:0] data_out;
    wire scan_out;

    reg test_failed = 0;

    scan_reset_override_reg dut (
        .clk(clk),
        .rst_n(rst_n),
        .test_mode(test_mode),
        .scan_en(scan_en),
        .scan_in(scan_in),
        .load_en(load_en),
        .data_in(data_in),
        .data_out(data_out),
        .scan_out(scan_out)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        test_mode = 0;
        scan_en = 0;
        scan_in = 0;
        load_en = 0;
        data_in = 4'h0;

        #2;
        if (data_out !== 4'h0 || scan_out !== 1'b0) begin
            $display("ERROR: reset did not initialize the register.");
            test_failed = 1;
        end

        #10 rst_n = 1;

        // Test 1: normal functional load.
        data_in = 4'hD;
        load_en = 1;
        @(posedge clk);
        #1;
        load_en = 0;
        if (data_out !== 4'hD) begin
            $display("ERROR: functional load failed. Expected D, got %h", data_out);
            test_failed = 1;
        end

        // Test 2: scan shift must continue even while rst_n is low in test mode.
        test_mode = 1;
        scan_en = 1;
        scan_in = 1'b0;
        @(posedge clk);
        #1;
        if (data_out !== 4'hA || scan_out !== 1'b1) begin
            $display("ERROR: first scan shift failed before reset override check.");
            test_failed = 1;
        end

        #2 rst_n = 0;
        #1;
        if (data_out !== 4'hA || scan_out !== 1'b1) begin
            $display("ERROR: test-mode reset override failed. Scan state was cleared by rst_n.");
            test_failed = 1;
        end

        scan_in = 1'b1;
        @(posedge clk);
        #1;
        if (data_out !== 4'h5 || scan_out !== 1'b1) begin
            $display("ERROR: scan shift did not continue while reset was asserted in test mode.");
            test_failed = 1;
        end

        // Test 3: leaving test mode while reset is still low must immediately clear the register.
        test_mode = 0;
        scan_en = 0;
        #1;
        if (data_out !== 4'h0 || scan_out !== 1'b0) begin
            $display("ERROR: functional reset was not restored when leaving test mode.");
            test_failed = 1;
        end

        rst_n = 1;

        // Test 4: functional mode must recover after scan.
        data_in = 4'h6;
        load_en = 1;
        @(posedge clk);
        #1;
        load_en = 0;
        if (data_out !== 4'h6) begin
            $display("ERROR: functional load after test mode failed. Expected 6, got %h", data_out);
            test_failed = 1;
        end

        // Test 5: standard reset still works in functional mode.
        #2 rst_n = 0;
        #1;
        if (data_out !== 4'h0 || scan_out !== 1'b0) begin
            $display("ERROR: functional reset no longer clears the register.");
            test_failed = 1;
        end

        rst_n = 1;

        #10;
        if (test_failed == 0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end
        $finish;
    end

endmodule
