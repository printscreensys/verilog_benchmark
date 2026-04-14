`timescale 1ns / 1ps

module tb_task_71;

    reg clk;
    reg rst_n;
    reg psel;
    reg penable;
    reg pwrite;
    reg [7:0] paddr;
    reg [31:0] pwdata;
    reg [3:0] pstrb;
    reg hw_fault_evt;

    wire [31:0] prdata;
    wire pready;
    wire [1:0] mode;
    wire [7:0] limit;
    wire cfg_locked;
    wire fault_sticky;
    wire apply_pulse;

    reg [31:0] rd_data;
    reg test_failed = 0;

    apb_lock_cfg dut (
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
        .hw_fault_evt(hw_fault_evt),
        .mode(mode),
        .limit(limit),
        .cfg_locked(cfg_locked),
        .fault_sticky(fault_sticky),
        .apply_pulse(apply_pulse)
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
        hw_fault_evt = 0;

        #2;
        if (mode !== 2'b01 || limit !== 8'h20 || cfg_locked !== 1'b0 || fault_sticky !== 1'b0 || apply_pulse !== 1'b0) begin
            $display("ERROR: reset values are incorrect.");
            test_failed = 1;
        end

        #10 rst_n = 1;

        apb_write(8'h00, 32'h00003300, 4'b0010);
        apb_write(8'h00, 32'h00000002, 4'b0001);
        if (mode !== 2'b10 || limit !== 8'h33) begin
            $display("ERROR: CFG partial writes failed.");
            test_failed = 1;
        end

        apb_write(8'h04, 32'h00000001, 4'b0001);
        if (cfg_locked !== 1'b1) begin
            $display("ERROR: lock bit failed to set.");
            test_failed = 1;
        end

        apb_write(8'h00, 32'h00004403, 4'b0011);
        if (mode !== 2'b10 || limit !== 8'h33) begin
            $display("ERROR: CFG changed even though cfg_locked was asserted.");
            test_failed = 1;
        end

        @(negedge clk);
        hw_fault_evt = 1'b1;
        @(posedge clk);
        #1 hw_fault_evt = 1'b0;
        if (fault_sticky !== 1'b1) begin
            $display("ERROR: hw_fault_evt did not set fault_sticky.");
            test_failed = 1;
        end

        apb_write(8'h08, 32'h00000000, 4'b0001);
        if (fault_sticky !== 1'b1) begin
            $display("ERROR: writing 0 incorrectly cleared fault_sticky.");
            test_failed = 1;
        end

        apb_write(8'h08, 32'h00000001, 4'b0001);
        if (fault_sticky !== 1'b0) begin
            $display("ERROR: W1C clear of fault_sticky failed.");
            test_failed = 1;
        end

        apb_write(8'h0C, 32'h00000001, 4'b0001);
        if (apply_pulse !== 1'b1) begin
            $display("ERROR: apply_pulse did not assert.");
            test_failed = 1;
        end

        @(posedge clk);
        #1;
        if (apply_pulse !== 1'b0) begin
            $display("ERROR: apply_pulse lasted longer than one cycle.");
            test_failed = 1;
        end

        apb_read(8'h04, rd_data);
        if (rd_data !== 32'h00000001) begin
            $display("ERROR: LOCK register readback failed. Got %h", rd_data);
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
