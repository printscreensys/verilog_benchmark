`timescale 1ns / 1ps

module tb_task_81;

    reg clk;
    reg rst_n;
    reg write_en;
    reg read_en;
    reg [7:0] data_in;
    reg inject_single_fault;
    reg inject_double_fault;

    wire [7:0] data_out;
    wire data_valid;
    wire correctable_error;
    wire uncorrectable_error;
    wire fault_sticky;

    reg test_failed;

    ecc_guarded_byte dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .read_en(read_en),
        .data_in(data_in),
        .inject_single_fault(inject_single_fault),
        .inject_double_fault(inject_double_fault),
        .data_out(data_out),
        .data_valid(data_valid),
        .correctable_error(correctable_error),
        .uncorrectable_error(uncorrectable_error),
        .fault_sticky(fault_sticky)
    );

    always #5 clk = ~clk;

    task check_outputs;
        input [7:0] exp_data;
        input exp_valid;
        input exp_correctable;
        input exp_uncorrectable;
        input exp_sticky;
        input [8*40-1:0] label;
        begin
            if (data_out !== exp_data) begin
                $display("ERROR (%0s): data_out=%h expected=%h", label, data_out, exp_data);
                test_failed = 1'b1;
            end
            if (data_valid !== exp_valid) begin
                $display("ERROR (%0s): data_valid=%b expected=%b", label, data_valid, exp_valid);
                test_failed = 1'b1;
            end
            if (correctable_error !== exp_correctable) begin
                $display("ERROR (%0s): correctable_error=%b expected=%b", label, correctable_error, exp_correctable);
                test_failed = 1'b1;
            end
            if (uncorrectable_error !== exp_uncorrectable) begin
                $display("ERROR (%0s): uncorrectable_error=%b expected=%b", label, uncorrectable_error, exp_uncorrectable);
                test_failed = 1'b1;
            end
            if (fault_sticky !== exp_sticky) begin
                $display("ERROR (%0s): fault_sticky=%b expected=%b", label, fault_sticky, exp_sticky);
                test_failed = 1'b1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        write_en = 1'b0;
        read_en = 1'b0;
        data_in = 8'h00;
        inject_single_fault = 1'b0;
        inject_double_fault = 1'b0;
        test_failed = 1'b0;

        #2;
        check_outputs(8'h00, 1'b0, 1'b0, 1'b0, 1'b0, "async reset");

        #8 rst_n = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(8'h00, 1'b0, 1'b0, 1'b0, 1'b0, "post reset");

        @(negedge clk);
        write_en = 1'b1;
        data_in = 8'hA5;
        @(posedge clk);
        #1;
        check_outputs(8'h00, 1'b0, 1'b0, 1'b0, 1'b0, "write response idle");
        write_en = 1'b0;

        @(negedge clk);
        read_en = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(8'hA5, 1'b1, 1'b0, 1'b0, 1'b0, "clean read");
        read_en = 1'b0;

        @(posedge clk);
        #1;
        check_outputs(8'h00, 1'b0, 1'b0, 1'b0, 1'b0, "clean read pulse clear");

        @(negedge clk);
        read_en = 1'b1;
        inject_single_fault = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(8'hA5, 1'b1, 1'b1, 1'b0, 1'b1, "single fault corrected");
        read_en = 1'b0;
        inject_single_fault = 1'b0;

        @(posedge clk);
        #1;
        check_outputs(8'h00, 1'b0, 1'b0, 1'b0, 1'b1, "sticky after single fault");

        #2 rst_n = 1'b0;
        #1;
        check_outputs(8'h00, 1'b0, 1'b0, 1'b0, 1'b0, "reset clears sticky");
        #7 rst_n = 1'b1;

        @(negedge clk);
        write_en = 1'b1;
        read_en = 1'b1;
        inject_single_fault = 1'b1;
        data_in = 8'h3C;
        @(posedge clk);
        #1;
        check_outputs(8'h00, 1'b0, 1'b0, 1'b0, 1'b0, "write priority over read");
        write_en = 1'b0;
        read_en = 1'b0;
        inject_single_fault = 1'b0;

        @(negedge clk);
        read_en = 1'b1;
        inject_single_fault = 1'b1;
        inject_double_fault = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(8'h00, 1'b1, 1'b0, 1'b1, 1'b1, "double fault priority");
        read_en = 1'b0;
        inject_single_fault = 1'b0;
        inject_double_fault = 1'b0;

        @(posedge clk);
        #1;
        check_outputs(8'h00, 1'b0, 1'b0, 1'b0, 1'b1, "sticky after double fault");

        @(negedge clk);
        read_en = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(8'h3C, 1'b1, 1'b0, 1'b0, 1'b1, "stored data preserved");
        read_en = 1'b0;

        #2 rst_n = 1'b0;
        #1;
        check_outputs(8'h00, 1'b0, 1'b0, 1'b0, 1'b0, "final async reset");
        #7 rst_n = 1'b1;

        @(negedge clk);
        read_en = 1'b1;
        @(posedge clk);
        #1;
        check_outputs(8'h00, 1'b1, 1'b0, 1'b0, 1'b0, "storage cleared by reset");
        read_en = 1'b0;

        if (test_failed == 1'b0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end

        $finish;
    end

endmodule
