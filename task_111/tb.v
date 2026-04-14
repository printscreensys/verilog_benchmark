`timescale 1ns / 1ps

module tb_task_111;

    reg clk;
    reg rst_n;
    reg start;
    reg [63:0] haystack;
    reg [7:0] needle;

    wire busy;
    wire done;
    wire found;
    wire [2:0] first_index;

    reg test_failed;

    consttime_byte_search dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .haystack(haystack),
        .needle(needle),
        .busy(busy),
        .done(done),
        .found(found),
        .first_index(first_index)
    );

    always #5 clk = ~clk;

    task check_outputs;
        input exp_busy;
        input exp_done;
        input exp_found;
        input [2:0] exp_first_index;
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
            if (found !== exp_found) begin
                $display("ERROR (%0s): found=%b expected=%b", label, found, exp_found);
                test_failed = 1'b1;
            end
            if (first_index !== exp_first_index) begin
                $display(
                    "ERROR (%0s): first_index=%0d expected=%0d",
                    label,
                    first_index,
                    exp_first_index
                );
                test_failed = 1'b1;
            end
        end
    endtask

    task start_request;
        input [63:0] in_haystack;
        input [7:0] in_needle;
        begin
            @(negedge clk);
            haystack = in_haystack;
            needle = in_needle;
            start = 1'b1;
            @(posedge clk);
            #1;
            check_outputs(1'b1, 1'b0, 1'b0, 3'd0, "accept request");
            start = 1'b0;
        end
    endtask

    task expect_constant_latency_result;
        input [63:0] in_haystack;
        input [7:0] in_needle;
        input exp_found;
        input [2:0] exp_first_index;
        input [8*48-1:0] label;
        integer cycle_idx;
        begin
            start_request(in_haystack, in_needle);

            for (cycle_idx = 0; cycle_idx < 7; cycle_idx = cycle_idx + 1) begin
                @(posedge clk);
                #1;
                check_outputs(1'b1, 1'b0, 1'b0, 3'd0, label);
            end

            @(posedge clk);
            #1;
            check_outputs(1'b1, 1'b1, exp_found, exp_first_index, label);

            @(posedge clk);
            #1;
            check_outputs(1'b0, 1'b0, 1'b0, 3'd0, "return to idle");
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        haystack = 64'h0000000000000000;
        needle = 8'h00;
        test_failed = 1'b0;

        #2;
        check_outputs(1'b0, 1'b0, 1'b0, 3'd0, "reset asserted");

        #8;
        rst_n = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 3'd0, "post reset idle");

        expect_constant_latency_result(
            64'h8877665544332211,
            8'h11,
            1'b1,
            3'd0,
            "match index 0"
        );
        expect_constant_latency_result(
            64'hA5B6C7D8E9F01234,
            8'hD8,
            1'b1,
            3'd4,
            "match index 4"
        );
        expect_constant_latency_result(
            64'h55AA55AA55AA55AA,
            8'hAA,
            1'b1,
            3'd0,
            "multiple matches choose first"
        );
        expect_constant_latency_result(
            64'h1020304050607080,
            8'hFF,
            1'b0,
            3'd0,
            "no match"
        );

        start_request(64'h1122334455667788, 8'h44);

        @(negedge clk);
        haystack = 64'hDEADBEEFCAFEBABE;
        needle = 8'hBE;
        start = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(1'b1, 1'b0, 1'b0, 3'd0, "ignore busy start");
        start = 1'b0;

        repeat (6) begin
            @(posedge clk);
            #1;
            check_outputs(1'b1, 1'b0, 1'b0, 3'd0, "ignore busy start progress");
        end

        @(posedge clk);
        #1;
        check_outputs(1'b1, 1'b1, 1'b1, 3'd4, "ignore busy start result");

        @(posedge clk);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 3'd0, "idle after ignored start");

        start_request(64'h0102030405060708, 8'h05);
        repeat (3) begin
            @(posedge clk);
            #1;
            check_outputs(1'b1, 1'b0, 1'b0, 3'd0, "mid-search before reset");
        end

        #2;
        rst_n = 1'b0;
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 3'd0, "async reset clears active search");

        #8;
        rst_n = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(1'b0, 1'b0, 1'b0, 3'd0, "idle after reset recovery");

        expect_constant_latency_result(
            64'hF0E0D0C0B0A09080,
            8'hC0,
            1'b1,
            3'd4,
            "final search"
        );

        if (test_failed == 1'b0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end

        $finish;
    end

endmodule
