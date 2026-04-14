`timescale 1ns / 1ps

module tb_task_50;

    reg clk;
    reg rst_n;
    reg scan_en;
    reg scan_in;
    reg load_en;
    reg [7:0] data_in;

    wire [7:0] data_out;
    wire scan_out;

    reg test_failed = 0;

    scan_reg8 dut (
        .clk(clk),
        .rst_n(rst_n),
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
        scan_en = 0;
        scan_in = 0;
        load_en = 0;
        data_in = 8'h00;

        #2;
        if (data_out !== 8'h00 || scan_out !== 1'b0) begin
            $display("ERROR: asynchronous reset did not clear the scan register.");
            test_failed = 1;
        end

        #10 rst_n = 1;

        // Test 1: functional load and hold.
        data_in = 8'hA5;
        load_en = 1;
        @(posedge clk);
        #1;
        load_en = 0;
        if (data_out !== 8'hA5) begin
            $display("ERROR: functional load failed. Expected A5, got %h", data_out);
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (data_out !== 8'hA5) begin
            $display("ERROR: register did not hold value in functional mode.");
            test_failed = 1;
        end

        // Test 2: scan mode must ignore load_en and shift from bit[7] toward scan_out.
        scan_en = 1;
        load_en = 1;
        data_in = 8'hFF;

        scan_in = 1'b0;
        @(posedge clk);
        #1;
        if (scan_out !== 1'b1) begin
            $display("ERROR: wrong first shifted-out bit. Expected 1, got %b", scan_out);
            test_failed = 1;
        end

        scan_in = 1'b0;
        @(posedge clk);
        #1;
        if (scan_out !== 1'b0) begin
            $display("ERROR: wrong second shifted-out bit. Expected 0, got %b", scan_out);
            test_failed = 1;
        end

        scan_in = 1'b1;
        @(posedge clk);
        #1;
        if (scan_out !== 1'b1) begin
            $display("ERROR: wrong third shifted-out bit. Expected 1, got %b", scan_out);
            test_failed = 1;
        end

        scan_in = 1'b1;
        @(posedge clk);
        #1;
        if (scan_out !== 1'b0) begin
            $display("ERROR: wrong fourth shifted-out bit. Expected 0, got %b", scan_out);
            test_failed = 1;
        end

        scan_in = 1'b1;
        @(posedge clk);
        #1;
        if (scan_out !== 1'b0) begin
            $display("ERROR: wrong fifth shifted-out bit. Expected 0, got %b", scan_out);
            test_failed = 1;
        end

        scan_in = 1'b1;
        @(posedge clk);
        #1;
        if (scan_out !== 1'b1) begin
            $display("ERROR: wrong sixth shifted-out bit. Expected 1, got %b", scan_out);
            test_failed = 1;
        end

        scan_in = 1'b0;
        @(posedge clk);
        #1;
        if (scan_out !== 1'b0) begin
            $display("ERROR: wrong seventh shifted-out bit. Expected 0, got %b", scan_out);
            test_failed = 1;
        end

        scan_in = 1'b0;
        @(posedge clk);
        #1;
        if (scan_out !== 1'b1) begin
            $display("ERROR: wrong eighth shifted-out bit. Expected 1, got %b", scan_out);
            test_failed = 1;
        end

        load_en = 0;
        scan_en = 0;

        if (data_out !== 8'h3C) begin
            $display("ERROR: scan load failed. Expected 3C after shifting, got %h", data_out);
            test_failed = 1;
        end

        // Test 3: return to functional mode without corrupting the scan-loaded state.
        data_in = 8'h5A;
        load_en = 1;
        @(posedge clk);
        #1;
        load_en = 0;

        if (data_out !== 8'h5A) begin
            $display("ERROR: functional recovery after scan mode failed. Expected 5A, got %h", data_out);
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
