`timescale 1ns / 1ps

module tb_task_82;

    reg clk;
    reg rst_n;
    reg load;
    reg step;
    reg [3:0] load_value;
    reg inject_shadow_fault;

    wire [3:0] count;
    wire count_valid;
    wire fault_flag;
    wire halted;

    reg test_failed;

    lockstep_event_counter dut (
        .clk(clk),
        .rst_n(rst_n),
        .load(load),
        .step(step),
        .load_value(load_value),
        .inject_shadow_fault(inject_shadow_fault),
        .count(count),
        .count_valid(count_valid),
        .fault_flag(fault_flag),
        .halted(halted)
    );

    always #5 clk = ~clk;

    task check_state;
        input [3:0] exp_count;
        input exp_valid;
        input exp_fault;
        input exp_halted;
        input [8*40-1:0] label;
        begin
            if (count !== exp_count) begin
                $display("ERROR (%0s): count=%h expected=%h", label, count, exp_count);
                test_failed = 1'b1;
            end
            if (count_valid !== exp_valid) begin
                $display("ERROR (%0s): count_valid=%b expected=%b", label, count_valid, exp_valid);
                test_failed = 1'b1;
            end
            if (fault_flag !== exp_fault) begin
                $display("ERROR (%0s): fault_flag=%b expected=%b", label, fault_flag, exp_fault);
                test_failed = 1'b1;
            end
            if (halted !== exp_halted) begin
                $display("ERROR (%0s): halted=%b expected=%b", label, halted, exp_halted);
                test_failed = 1'b1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        load = 1'b0;
        step = 1'b0;
        load_value = 4'h0;
        inject_shadow_fault = 1'b0;
        test_failed = 1'b0;

        #2;
        check_state(4'h0, 1'b0, 1'b0, 1'b0, "async reset");

        #8 rst_n = 1'b1;
        @(posedge clk);
        #1;
        check_state(4'h0, 1'b1, 1'b0, 1'b0, "post reset");

        @(negedge clk);
        step = 1'b1;
        @(posedge clk);
        #1;
        check_state(4'h1, 1'b1, 1'b0, 1'b0, "step 1");
        step = 1'b0;

        @(negedge clk);
        step = 1'b1;
        @(posedge clk);
        #1;
        check_state(4'h2, 1'b1, 1'b0, 1'b0, "step 2");
        step = 1'b0;

        @(negedge clk);
        load = 1'b1;
        step = 1'b1;
        load_value = 4'hC;
        @(posedge clk);
        #1;
        check_state(4'hC, 1'b1, 1'b0, 1'b0, "load priority");
        load = 1'b0;
        step = 1'b0;

        @(negedge clk);
        step = 1'b1;
        inject_shadow_fault = 1'b1;
        @(posedge clk);
        #1;
        check_state(4'h0, 1'b0, 1'b1, 1'b1, "fault detection and safe state");
        step = 1'b0;
        inject_shadow_fault = 1'b0;

        @(negedge clk);
        load = 1'b1;
        load_value = 4'h7;
        @(posedge clk);
        #1;
        check_state(4'h0, 1'b0, 1'b1, 1'b1, "frozen after fault");
        load = 1'b0;

        #2 rst_n = 1'b0;
        #1;
        check_state(4'h0, 1'b0, 1'b0, 1'b0, "reset clears fault");
        #7 rst_n = 1'b1;

        @(posedge clk);
        #1;
        check_state(4'h0, 1'b1, 1'b0, 1'b0, "healthy after reset");

        @(negedge clk);
        load = 1'b1;
        load_value = 4'h5;
        @(posedge clk);
        #1;
        check_state(4'h5, 1'b1, 1'b0, 1'b0, "reload after reset");
        load = 1'b0;

        @(negedge clk);
        step = 1'b1;
        @(posedge clk);
        #1;
        check_state(4'h6, 1'b1, 1'b0, 1'b0, "step after reset");
        step = 1'b0;

        if (test_failed == 1'b0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end

        $finish;
    end

endmodule
