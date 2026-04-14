`timescale 1ns / 1ps

module tb_task_80;

    reg clk;
    reg rst;
    reg event_valid;
    reg clear;
    wire [3:0] count;
    wire overflow;

    reg test_failed;
    reg [3:0] expected_count;
    reg expected_overflow;

    event_counter_alert dut (
        .clk(clk),
        .rst(rst),
        .event_valid(event_valid),
        .clear(clear),
        .count(count),
        .overflow(overflow)
    );

    always #5 clk = ~clk;

    task check_state;
        input [3:0] exp_count;
        input exp_overflow;
        input [8*40-1:0] label;
        begin
            if (count !== exp_count) begin
                $display("ERROR (%0s): count=%h expected=%h", label, count, exp_count);
                test_failed = 1'b1;
            end
            if (overflow !== exp_overflow) begin
                $display("ERROR (%0s): overflow=%b expected=%b", label, overflow, exp_overflow);
                test_failed = 1'b1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        event_valid = 1'b0;
        clear = 1'b0;
        test_failed = 1'b0;
        expected_count = 4'h0;
        expected_overflow = 1'b0;

        // Verify active-low asynchronous reset semantics.
        #2 rst = 1'b0;
        #1;
        check_state(4'h0, 1'b0, "async reset assert");

        #6 rst = 1'b1;
        @(posedge clk);
        #1;
        check_state(4'h0, 1'b0, "post reset release");

        // Count up to the maximum value without wrapping.
        repeat (15) begin
            @(negedge clk);
            event_valid = 1'b1;
            clear = 1'b0;
            @(posedge clk);
            #1;
            expected_count = expected_count + 4'h1;
            check_state(expected_count, expected_overflow, "increment");
            event_valid = 1'b0;
        end

        // One more event must saturate count and latch overflow.
        @(negedge clk);
        event_valid = 1'b1;
        @(posedge clk);
        #1;
        expected_count = 4'hF;
        expected_overflow = 1'b1;
        check_state(expected_count, expected_overflow, "saturating overflow");
        event_valid = 1'b0;

        // Additional events keep the counter saturated and overflow sticky.
        @(negedge clk);
        event_valid = 1'b1;
        @(posedge clk);
        #1;
        check_state(expected_count, expected_overflow, "sticky overflow");
        event_valid = 1'b0;

        // Clear must reset both the count and overflow flag.
        @(negedge clk);
        clear = 1'b1;
        @(posedge clk);
        #1;
        expected_count = 4'h0;
        expected_overflow = 1'b0;
        check_state(expected_count, expected_overflow, "clear only");
        clear = 1'b0;

        // If clear and event_valid happen together, clear must win.
        @(negedge clk);
        clear = 1'b1;
        event_valid = 1'b1;
        @(posedge clk);
        #1;
        check_state(4'h0, 1'b0, "clear priority");
        clear = 1'b0;
        event_valid = 1'b0;

        // Normal counting must still work after clear.
        @(negedge clk);
        event_valid = 1'b1;
        @(posedge clk);
        #1;
        expected_count = 4'h1;
        check_state(expected_count, expected_overflow, "count after clear");
        event_valid = 1'b0;

        // Verify asynchronous reset again mid-run.
        #2 rst = 1'b0;
        #1;
        expected_count = 4'h0;
        expected_overflow = 1'b0;
        check_state(expected_count, expected_overflow, "mid-run async reset");
        #6 rst = 1'b1;
        @(posedge clk);
        #1;
        check_state(expected_count, expected_overflow, "final reset release");

        if (test_failed == 1'b0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end

        $finish;
    end

endmodule
