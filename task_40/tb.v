`timescale 1ns / 1ps

module tb_task_40;

    reg clk;
    reg rst_n;
    reg data_in;
    reg low_power_mode;
    
    wire [7:0] match_count;
    wire cg_en;

    reg test_failed = 0;

    power_aware_fsm dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .low_power_mode(low_power_mode),
        .match_count(match_count),
        .cg_en(cg_en)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        data_in = 0;
        low_power_mode = 0;

        #12 rst_n = 1;

        // --- TEST 1: Normal Operation ---
        // Feed: 1 0 1
        @(posedge clk); #1 data_in = 1; 
        @(posedge clk); #1 data_in = 0; 
        @(posedge clk); #1 data_in = 1; 
        @(posedge clk); #1 data_in = 0; 
        
        #5;
        if (match_count !== 8'd1) begin
            $display("ERROR: Failed to detect normal '101' sequence. Count is %d", match_count);
            test_failed = 1;
        end

        // --- TEST 2: Power-Aware Sleep Isolation ---
        @(posedge clk);
        #1;
        low_power_mode = 1;
        
        @(posedge clk); // Allow state machine to jump to SLEEP
        #1;
        if (cg_en !== 1'b0) begin
            $display("ERROR: clock-gate enable (cg_en) did not drop during sleep mode!");
            test_failed = 1;
        end

        // While asleep, feed: 1 0 1 (This should be completely ignored/isolated)
        @(posedge clk); #1 data_in = 1; 
        @(posedge clk); #1 data_in = 0; 
        @(posedge clk); #1 data_in = 1; 
        @(posedge clk); #1 data_in = 0; 

        #5;
        if (match_count !== 8'd1) begin
            $display("ERROR: Datapath toggled during SLEEP! Power Intent Violation.");
            $display("LLM failed to isolate operands during low_power_mode.");
            test_failed = 1;
        end

        // --- TEST 3: Recovery ---
        @(posedge clk);
        #1;
        low_power_mode = 0;
        @(posedge clk);
        #1;

        if (cg_en !== 1'b1) begin
            $display("ERROR: cg_en did not recover after sleep mode.");
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
