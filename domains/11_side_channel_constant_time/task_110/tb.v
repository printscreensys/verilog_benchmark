`timescale 1ns / 1ps

module tb_task_110;

    reg clk;
    reg rst_n;
    reg start;
    reg [31:0] lhs;
    reg [31:0] rhs;

    wire busy;
    wire done;
    wire match;

    reg test_failed;

    consttime_word_compare dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .lhs(lhs),
        .rhs(rhs),
        .busy(busy),
        .done(done),
        .match(match)
    );

    always #5 clk = ~clk;

    task check_outputs;
        input exp_busy;
        input exp_done;
        input exp_match;
        input [8*48-1:0] label;
        begin
            if (busy !== exp_busy) begin
                $display("ERROR (%0s): busy=%b expected=%b", label, busy, exp_busy);
                test_failed = 1'b1;
            end
            if (done !== exp_done) begin
                $display("ERROR (%0s): done=%b expected=%b", label, done, exp_done);
                test_failed = 1'b1;
            end
            if (match !== exp_match) begin
                $display("ERROR (%0s): match=%b expected=%b", label, match, exp_match);
                test_failed = 1'b1;
            end
        end
    endtask

    task start_request;
        input [31:0] in_lhs;
        input [31:0] in_rhs;
        begin
            @(negedge clk);
            lhs = in_lhs;
            rhs = in_rhs;
            start = 1'b1;
            @(posedge clk);
            #1;
            check_outputs(1'b1, 1'b0, 1'b0, "accept request");
            start = 1'b0;
        end
    endtask

    task expect_constant_latency_result;
        input [31:0] in_lhs;
        input [31:0] in_rhs;
        input exp_match;
        input [8*48-1:0] label;
        integer cycle_idx;
        begin
            start_request(in_lhs, in_rhs);

            for (cycle_idx = 0; cycle_idx < 3; cycle_idx = cycle_idx + 1) begin
                @(posedge clk);
                #1;
                check_outputs(1'b1, 1'b0, 1'b0, label);
            end

            @(posedge clk);
            #1;
            check_outputs(1'b1, 1'b1, exp_match, label);

            @(posedge clk);
            #1;
            check_outputs(1'b0, 1'b0, 1'b0, "return to idle");
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        lhs = 32'h00000000;
        rhs = 32'h00000000;
        test_failed = 1'b0;

        #2;
        check_outputs(1'b0, 1'b0, 1'b0, "reset asserted");

        #8;
        rst_n = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, "post reset idle");

        expect_constant_latency_result(32'h89ABCDEF, 32'h89ABCDEF, 1'b1, "equal words");
        expect_constant_latency_result(32'h01234567, 32'h01234560, 1'b0, "mismatch byte0");
        expect_constant_latency_result(32'hAABBCCDD, 32'hAA11CCDD, 1'b0, "mismatch byte2");

        start_request(32'h11223344, 32'h11223344);

        @(negedge clk);
        lhs = 32'hFFFFFFFF;
        rhs = 32'h00000000;
        start = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(1'b1, 1'b0, 1'b0, "ignore busy start");
        start = 1'b0;

        repeat (2) begin
            @(posedge clk);
            #1;
            check_outputs(1'b1, 1'b0, 1'b0, "ignore busy start progress");
        end

        @(posedge clk);
        #1;
        check_outputs(1'b1, 1'b1, 1'b1, "ignore busy start result");

        @(posedge clk);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, "idle after ignored start");

        start_request(32'hDEADBEEF, 32'hDEADBEEF);
        @(posedge clk);
        #1;
        check_outputs(1'b1, 1'b0, 1'b0, "mid-transaction before reset");

        #2;
        rst_n = 1'b0;
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, "async reset clears active op");

        #8;
        rst_n = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, "idle after reset recovery");

        expect_constant_latency_result(32'hCAFEBABE, 32'hCAFEBABB, 1'b0, "final mismatch");

        if (test_failed == 1'b0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end

        $finish;
    end

endmodule
