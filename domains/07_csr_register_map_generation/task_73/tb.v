`timescale 1ns / 1ps

module tb_task_73;

    reg clk;
    reg rst_n;
    reg psel;
    reg penable;
    reg pwrite;
    reg [7:0] paddr;
    reg [31:0] pwdata;
    reg [3:0] pstrb;
    reg sample_push;
    reg [7:0] sample_data;

    wire [31:0] prdata;
    wire pready;
    wire [7:0] threshold;
    wire irq_out;
    wire ack_pulse;

    reg [31:0] rd_data;
    reg test_failed = 0;

    apb_sample_csr dut (
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
        .sample_push(sample_push),
        .sample_data(sample_data),
        .threshold(threshold),
        .irq_out(irq_out),
        .ack_pulse(ack_pulse)
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
        sample_push = 0;
        sample_data = 0;

        #2;
        if (threshold !== 8'h20 || irq_out !== 1'b0 || ack_pulse !== 1'b0) begin
            $display("ERROR: reset values are incorrect.");
            test_failed = 1;
        end

        #10 rst_n = 1;

        apb_write(8'h00, 32'h00000044, 4'b0001);
        if (threshold !== 8'h44) begin
            $display("ERROR: threshold write failed.");
            test_failed = 1;
        end

        @(negedge clk);
        sample_data = 8'hAB;
        sample_push = 1'b1;
        @(posedge clk);
        #1 sample_push = 1'b0;
        if (irq_out !== 1'b1) begin
            $display("ERROR: sample_push did not set data_pending.");
            test_failed = 1;
        end

        apb_read(8'h04, rd_data);
        if (rd_data !== 32'h00000001) begin
            $display("ERROR: STATUS readback failed. Got %h", rd_data);
            test_failed = 1;
        end
        if (irq_out !== 1'b1) begin
            $display("ERROR: STATUS read incorrectly cleared data_pending.");
            test_failed = 1;
        end

        apb_read(8'h08, rd_data);
        if (rd_data !== 32'h000000AB) begin
            $display("ERROR: DATA readback failed. Got %h", rd_data);
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (irq_out !== 1'b0) begin
            $display("ERROR: DATA read did not clear data_pending.");
            test_failed = 1;
        end

        apb_read(8'h04, rd_data);
        if (rd_data !== 32'h00000000) begin
            $display("ERROR: STATUS should be clear after DATA read. Got %h", rd_data);
            test_failed = 1;
        end

        apb_write(8'h0C, 32'h00000001, 4'b0001);
        if (ack_pulse !== 1'b1) begin
            $display("ERROR: ack_pulse did not assert.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (ack_pulse !== 1'b0) begin
            $display("ERROR: ack_pulse lasted longer than one cycle.");
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
