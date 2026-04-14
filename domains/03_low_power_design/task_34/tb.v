`timescale 1ns / 1ps

module tb_task_34;

    reg clk;
    reg rst_n;
    reg sleep_req;
    reg [31:0] data_in;
    
    wire [31:0] data_out;
    wire pwr_enable;
    wire iso_en;

    reg test_failed = 0;

    soc_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .sleep_req(sleep_req),
        .data_in(data_in),
        .data_out(data_out),
        .pwr_enable(pwr_enable),
        .iso_en(iso_en)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        sleep_req = 0;
        data_in = 32'hAAAA_BBBB;

        #12 rst_n = 1;
        
        // Wait for system to become active
        #10;
        if (pwr_enable !== 1 || iso_en !== 0) begin
            $display("ERROR: Bad reset state. Expected pwr=1, iso=0");
            test_failed = 1;
        end

        // --- TEST 1: INITIATE POWER DOWN SEQUENCE ---
        @(posedge clk);
        #1; 
        sleep_req = 1;

        // Cycle 1: Expected ISO_ON state (iso=1, pwr=1)
        @(posedge clk);
        #1;
        if (iso_en !== 1 || pwr_enable !== 1) begin
            $display("ERROR: UPF Power Down Sequence Flaw! Missing isolation safety step.");
            $display("  Expected: pwr_enable=1, iso_en=1");
            $display("  Got:      pwr_enable=%b, iso_en=%b", pwr_enable, iso_en);
            test_failed = 1;
        end

        // Cycle 2: Expected SLEEP state (iso=1, pwr=0)
        @(posedge clk);
        #1;
        if (iso_en !== 1 || pwr_enable !== 0) begin
            $display("ERROR: Power Down failed. Expected pwr_enable=0, iso_en=1.");
            test_failed = 1;
        end

        // --- TEST 2: INITIATE WAKE UP SEQUENCE ---
        @(posedge clk);
        #1;
        sleep_req = 0;

        // Cycle 1: Expected PWR_ON state (iso=1, pwr=1)
        @(posedge clk);
        #1;
        if (iso_en !== 1 || pwr_enable !== 1) begin
            $display("ERROR: UPF Wake-Up Sequence Flaw! Isolation dropped prematurely.");
            $display("  Expected: pwr_enable=1, iso_en=1");
            $display("  Got:      pwr_enable=%b, iso_en=%b", pwr_enable, iso_en);
            test_failed = 1;
        end

        // Cycle 2: Expected ACTIVE state (iso=0, pwr=1)
        @(posedge clk);
        #1;
        if (iso_en !== 0 || pwr_enable !== 1) begin
            $display("ERROR: Wake Up failed to resolve. Expected pwr_enable=1, iso_en=0.");
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
