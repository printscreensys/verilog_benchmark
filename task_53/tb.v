`timescale 1ns / 1ps

module tb_task_53;

    reg clk;
    reg rst_n;
    reg func_we;
    reg [1:0] func_addr;
    reg [7:0] func_wdata;
    reg mbist_en;
    reg mbist_start;

    wire [7:0] func_rdata;
    wire mbist_busy;
    wire mbist_done;
    wire mbist_fail;

    reg test_failed = 0;

    mbist_ram_wrapper dut (
        .clk(clk),
        .rst_n(rst_n),
        .func_we(func_we),
        .func_addr(func_addr),
        .func_wdata(func_wdata),
        .func_rdata(func_rdata),
        .mbist_en(mbist_en),
        .mbist_start(mbist_start),
        .mbist_busy(mbist_busy),
        .mbist_done(mbist_done),
        .mbist_fail(mbist_fail)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        func_we = 0;
        func_addr = 2'b00;
        func_wdata = 8'h00;
        mbist_en = 0;
        mbist_start = 0;

        #2;
        if (func_rdata !== 8'h00 || mbist_busy !== 1'b0 || mbist_done !== 1'b0 || mbist_fail !== 1'b0) begin
            $display("ERROR: reset did not initialize the MBIST wrapper correctly.");
            test_failed = 1;
        end

        #10 rst_n = 1;

        // Test 1: functional mode read/write behavior.
        func_addr = 2'b01;
        func_wdata = 8'h11;
        func_we = 1;
        @(posedge clk);
        #1;
        func_we = 0;

        func_addr = 2'b10;
        func_wdata = 8'h22;
        func_we = 1;
        @(posedge clk);
        #1;
        func_we = 0;

        func_addr = 2'b01;
        #1;
        if (func_rdata !== 8'h11) begin
            $display("ERROR: functional readback for address 1 failed. Got %h", func_rdata);
            test_failed = 1;
        end

        func_addr = 2'b10;
        #1;
        if (func_rdata !== 8'h22) begin
            $display("ERROR: functional readback for address 2 failed. Got %h", func_rdata);
            test_failed = 1;
        end

        // Test 2: MBIST must take ownership and ignore functional writes.
        mbist_en = 1;
        mbist_start = 1;
        @(posedge clk);
        #1;
        mbist_start = 0;
        if (mbist_busy !== 1'b1) begin
            $display("ERROR: MBIST did not enter busy state after start.");
            test_failed = 1;
        end

        @(posedge clk); #1; // phase 0 write addr0
        @(posedge clk); #1; // phase 1 write addr1
        @(posedge clk); #1; // phase 2 write addr2
        @(posedge clk); #1; // phase 3 write addr3

        func_we = 1;
        func_addr = 2'b01;
        func_wdata = 8'hFF;
        @(posedge clk); #1; // phase 4 compare addr0
        func_we = 0;

        @(posedge clk); #1; // phase 5 compare addr1
        @(posedge clk); #1; // phase 6 compare addr2
        @(posedge clk); #1; // phase 7 compare addr3, done pulse

        if (mbist_busy !== 1'b0) begin
            $display("ERROR: MBIST busy did not drop when test completed.");
            test_failed = 1;
        end

        if (mbist_done !== 1'b1) begin
            $display("ERROR: MBIST done pulse missing at completion.");
            test_failed = 1;
        end

        if (mbist_fail !== 1'b0) begin
            $display("ERROR: MBIST falsely reported a failure.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (mbist_done !== 1'b0) begin
            $display("ERROR: MBIST done did not pulse for exactly one cycle.");
            test_failed = 1;
        end

        mbist_en = 0;
        func_addr = 2'b00;
        #1;
        if (func_rdata !== 8'hA0) begin
            $display("ERROR: MBIST pattern for address 0 is wrong. Got %h", func_rdata);
            test_failed = 1;
        end

        func_addr = 2'b01;
        #1;
        if (func_rdata !== 8'hA1) begin
            $display("ERROR: functional write leaked into MBIST-owned RAM at address 1. Got %h", func_rdata);
            test_failed = 1;
        end

        func_addr = 2'b10;
        #1;
        if (func_rdata !== 8'hA2) begin
            $display("ERROR: MBIST pattern for address 2 is wrong. Got %h", func_rdata);
            test_failed = 1;
        end

        func_addr = 2'b11;
        #1;
        if (func_rdata !== 8'hA3) begin
            $display("ERROR: MBIST pattern for address 3 is wrong. Got %h", func_rdata);
            test_failed = 1;
        end

        // Test 3: normal functional writes must work again after leaving MBIST mode.
        func_addr = 2'b00;
        func_wdata = 8'h55;
        func_we = 1;
        @(posedge clk);
        #1;
        func_we = 0;
        if (func_rdata !== 8'h55) begin
            $display("ERROR: functional mode did not recover after MBIST.");
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
