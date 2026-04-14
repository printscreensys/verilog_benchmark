`timescale 1ns / 1ps

module tb_dual_mac_timing;
    reg clk;
    reg rst_n;
    reg in_valid;
    reg signed [15:0] a;
    reg signed [15:0] b;
    reg signed [15:0] c;
    reg signed [15:0] d;

    wire out_valid;
    wire signed [32:0] y;

    reg exp_valid_d;
    reg signed [32:0] exp_data_d;
    reg signed [32:0] held_y;
    integer fail_flag;

    dual_mac_timing dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .a(a),
        .b(b),
        .c(c),
        .d(d),
        .out_valid(out_valid),
        .y(y)
    );

    always #5 clk = ~clk;

    task drive_sample;
        input drive_valid;
        input signed [15:0] drive_a;
        input signed [15:0] drive_b;
        input signed [15:0] drive_c;
        input signed [15:0] drive_d;
        begin
            @(negedge clk);
            in_valid = drive_valid;
            a = drive_a;
            b = drive_b;
            c = drive_c;
            d = drive_d;
        end
    endtask

    task mark_failure;
        input [8*96-1:0] message;
        begin
            if (!fail_flag) begin
                $display("FAIL: %0s", message);
            end
            fail_flag = 1;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exp_valid_d = 1'b0;
            exp_data_d = 33'sd0;
            held_y = 33'sd0;
        end else begin
            #1;

            if (out_valid !== exp_valid_d) begin
                mark_failure("out_valid did not match the required 1-cycle latency.");
            end

            if (exp_valid_d) begin
                if (y !== exp_data_d) begin
                    mark_failure("y did not match the expected signed MAC result.");
                end
                held_y = y;
            end else if (y !== held_y) begin
                mark_failure("y changed while out_valid was low.");
            end

            exp_valid_d = in_valid;
            exp_data_d = ($signed(a) * $signed(b)) + ($signed(c) * $signed(d));
        end
    end

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        in_valid = 1'b0;
        a = 16'sd0;
        b = 16'sd0;
        c = 16'sd0;
        d = 16'sd0;
        fail_flag = 0;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        drive_sample(1'b1, 16'sd3, -16'sd4, 16'sd5, 16'sd2);
        drive_sample(1'b1, -16'sd8, -16'sd8, 16'sd7, -16'sd3);
        drive_sample(1'b0, 16'sd0, 16'sd0, 16'sd0, 16'sd0);
        drive_sample(1'b1, 16'sd12, 16'sd11, -16'sd9, 16'sd4);
        drive_sample(1'b1, -16'sd16, 16'sd7, -16'sd2, -16'sd15);
        drive_sample(1'b1, 16'sd127, -16'sd9, 16'sd13, 16'sd13);
        drive_sample(1'b0, 16'sd0, 16'sd0, 16'sd0, 16'sd0);
        drive_sample(1'b1, 16'sd31, 16'sd17, -16'sd21, 16'sd9);
        drive_sample(1'b0, 16'sd0, 16'sd0, 16'sd0, 16'sd0);
        drive_sample(1'b0, 16'sd0, 16'sd0, 16'sd0, 16'sd0);
        drive_sample(1'b0, 16'sd0, 16'sd0, 16'sd0, 16'sd0);

        @(posedge clk);
        #1;

        if (fail_flag) begin
            $display("TEST_FAILED");
        end else begin
            $display("TEST_PASSED");
        end

        $finish;
    end

endmodule
