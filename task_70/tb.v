`timescale 1ns / 1ps

module tb_task_70;

    reg clk;
    reg rst_n;
    reg psel;
    reg penable;
    reg pwrite;
    reg [7:0] paddr;
    reg [31:0] pwdata;
    reg [3:0] pstrb;
    reg [7:0] hw_status;
    reg timer_done_evt;

    wire [31:0] prdata;
    wire pready;
    wire timer_enable;
    wire [7:0] threshold;
    wire clear_done_pulse;
    wire irq_pending;

    reg [31:0] rd_data;
    reg test_failed = 0;

    apb_timer_csr dut (
        .clk(clk),
        .rst_n(rst_n),
        .psel(psel),
        .penable(penable),
        .pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .pstrb(pstrb),
        .prdata(prdata),
        .pready(pready),
        .hw_status(hw_status),
        .timer_done_evt(timer_done_evt),
        .timer_enable(timer_enable),
        .threshold(threshold),
        .clear_done_pulse(clear_done_pulse),
        .irq_pending(irq_pending)
    );

    task apb_write;
        input [7:0] addr;
        input [31:0] data;
        input [3:0] strb;
        begin
            @(negedge clk);
            paddr = addr;
            pwdata = data;
            pstrb = strb;
            pwrite = 1'b1;
            psel = 1'b1;
            penable = 1'b0;

            @(posedge clk);
            #1 penable = 1'b1;

            @(posedge clk);
            #1;
            paddr = 8'h00;
            pwdata = 32'h00000000;
            pstrb = 4'b0000;
            pwrite = 1'b0;
            psel = 1'b0;
            penable = 1'b0;
        end
    endtask

    task apb_read;
        input [7:0] addr;
        output [31:0] data;
        begin
            @(negedge clk);
            paddr = addr;
            pwrite = 1'b0;
            psel = 1'b1;
            penable = 1'b0;

            @(posedge clk);
            #1 penable = 1'b1;

            @(posedge clk);
            #1;
            data = prdata;
            paddr = 8'h00;
            psel = 1'b0;
            penable = 1'b0;
        end
    endtask

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        psel = 0;
        penable = 0;
        pwrite = 0;
        paddr = 0;
        pwdata = 0;
        pstrb = 0;
        hw_status = 8'h00;
        timer_done_evt = 0;

        #2;
        if (timer_enable !== 1'b0 || threshold !== 8'h10 || irq_pending !== 1'b0 || clear_done_pulse !== 1'b0) begin
            $display("ERROR: reset values are incorrect.");
            test_failed = 1;
        end

        #10 rst_n = 1;

        apb_write(8'h00, 32'h00000001, 4'b0001);
        if (timer_enable !== 1'b1 || threshold !== 8'h10) begin
            $display("ERROR: partial write to CTRL byte 0 corrupted threshold or failed enable.");
            test_failed = 1;
        end

        apb_write(8'h00, 32'h00005500, 4'b0010);
        if (timer_enable !== 1'b1 || threshold !== 8'h55) begin
            $display("ERROR: partial write to CTRL byte 1 failed.");
            test_failed = 1;
        end

        apb_write(8'h00, 32'hABCD0000, 4'b1100);
        if (timer_enable !== 1'b1 || threshold !== 8'h55) begin
            $display("ERROR: reserved bytes unexpectedly modified CTRL.");
            test_failed = 1;
        end

        hw_status = 8'hC3;
        apb_read(8'h04, rd_data);
        if (rd_data !== 32'h000000C3) begin
            $display("ERROR: STATUS readback failed. Got %h", rd_data);
            test_failed = 1;
        end

        @(negedge clk);
        timer_done_evt = 1'b1;
        @(posedge clk);
        #1 timer_done_evt = 1'b0;
        if (irq_pending !== 1'b1) begin
            $display("ERROR: done sticky bit was not set by timer_done_evt.");
            test_failed = 1;
        end

        apb_write(8'h08, 32'h00000000, 4'b0001);
        if (irq_pending !== 1'b1) begin
            $display("ERROR: writing 0 incorrectly cleared a W1C bit.");
            test_failed = 1;
        end

        apb_write(8'h08, 32'h00000001, 4'b0001);
        if (irq_pending !== 1'b0) begin
            $display("ERROR: writing 1 failed to clear IRQ_STATUS.");
            test_failed = 1;
        end

        apb_write(8'h0C, 32'h00000001, 4'b0001);
        if (clear_done_pulse !== 1'b1) begin
            $display("ERROR: clear_done_pulse was not asserted on CMD write.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (clear_done_pulse !== 1'b0) begin
            $display("ERROR: clear_done_pulse lasted longer than one cycle.");
            test_failed = 1;
        end

        apb_read(8'h0C, rd_data);
        if (rd_data !== 32'h00000000) begin
            $display("ERROR: CMD register should read back as zero.");
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
