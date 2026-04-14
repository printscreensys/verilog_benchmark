`timescale 1ns / 1ps

module tb_task_72;

    reg clk;
    reg rst_n;
    reg [7:0] awaddr;
    reg awvalid;
    wire awready;
    reg [31:0] wdata;
    reg [3:0] wstrb;
    reg wvalid;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    reg bready;
    reg [7:0] araddr;
    reg arvalid;
    wire arready;
    wire [31:0] rdata;
    wire [1:0] rresp;
    wire rvalid;
    reg rready;
    reg [7:0] hw_level;
    reg irq_evt;

    wire block_enable;
    wire [7:0] gain;
    wire kick_pulse;
    wire irq_sticky;

    reg [31:0] rd_data;
    reg test_failed = 0;

    axil_sensor_csr dut (
        .clk(clk),
        .rst_n(rst_n),
        .awaddr(awaddr),
        .awvalid(awvalid),
        .awready(awready),
        .wdata(wdata),
        .wstrb(wstrb),
        .wvalid(wvalid),
        .wready(wready),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),
        .araddr(araddr),
        .arvalid(arvalid),
        .arready(arready),
        .rdata(rdata),
        .rresp(rresp),
        .rvalid(rvalid),
        .rready(rready),
        .hw_level(hw_level),
        .irq_evt(irq_evt),
        .block_enable(block_enable),
        .gain(gain),
        .kick_pulse(kick_pulse),
        .irq_sticky(irq_sticky)
    );

    task axi_write;
        input [7:0] addr;
        input [31:0] data;
        input [3:0] strb;
        begin
            @(negedge clk);
            awaddr = addr;
            awvalid = 1'b1;
            wdata = data;
            wstrb = strb;
            wvalid = 1'b1;
            #1;
            if (awready !== 1'b1 || wready !== 1'b1) begin
                $display("ERROR: AXI-Lite write channel was not ready in idle state.");
                test_failed = 1;
            end

            @(posedge clk);
            #1;
            awvalid = 1'b0;
            wvalid = 1'b0;
            bready = 1'b1;

            if (bvalid !== 1'b1 || bresp !== 2'b00) begin
                $display("ERROR: AXI-Lite write response was not generated correctly.");
                test_failed = 1;
            end

            @(posedge clk);
            #1;
            bready = 1'b0;
        end
    endtask

    task axi_read;
        input [7:0] addr;
        output [31:0] data;
        begin
            @(negedge clk);
            araddr = addr;
            arvalid = 1'b1;
            #1;
            if (arready !== 1'b1) begin
                $display("ERROR: AXI-Lite read channel was not ready in idle state.");
                test_failed = 1;
            end

            @(posedge clk);
            #1;
            arvalid = 1'b0;
            rready = 1'b1;

            if (rvalid !== 1'b1 || rresp !== 2'b00) begin
                $display("ERROR: AXI-Lite read response was not generated correctly.");
                test_failed = 1;
            end

            data = rdata;

            @(posedge clk);
            #1;
            rready = 1'b0;
        end
    endtask

    task axi_write_cmd;
        input [7:0] addr;
        input [31:0] data;
        input [3:0] strb;
        begin
            @(negedge clk);
            awaddr = addr;
            awvalid = 1'b1;
            wdata = data;
            wstrb = strb;
            wvalid = 1'b1;
            #1;
            if (awready !== 1'b1 || wready !== 1'b1) begin
                $display("ERROR: AXI-Lite write channel was not ready for CMD write.");
                test_failed = 1;
            end

            @(posedge clk);
            #1;
            awvalid = 1'b0;
            wvalid = 1'b0;
            bready = 1'b1;

            if (bvalid !== 1'b1 || bresp !== 2'b00) begin
                $display("ERROR: AXI-Lite CMD write response was not generated correctly.");
                test_failed = 1;
            end

            if (kick_pulse !== 1'b1) begin
                $display("ERROR: kick_pulse did not assert on CMD write.");
                test_failed = 1;
            end

            @(posedge clk);
            #1;
            bready = 1'b0;
        end
    endtask

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        awaddr = 0;
        awvalid = 0;
        wdata = 0;
        wstrb = 0;
        wvalid = 0;
        bready = 0;
        araddr = 0;
        arvalid = 0;
        rready = 0;
        hw_level = 8'h00;
        irq_evt = 0;

        #2;
        if (block_enable !== 1'b0 || gain !== 8'h08 || kick_pulse !== 1'b0 || irq_sticky !== 1'b0) begin
            $display("ERROR: reset values are incorrect.");
            test_failed = 1;
        end

        #10 rst_n = 1;

        axi_write(8'h00, 32'h00000001, 4'b0001);
        if (block_enable !== 1'b1 || gain !== 8'h08) begin
            $display("ERROR: byte-lane write to CTRL bit 0 failed.");
            test_failed = 1;
        end

        axi_write(8'h00, 32'h00002A00, 4'b0010);
        if (block_enable !== 1'b1 || gain !== 8'h2A) begin
            $display("ERROR: byte-lane write to CTRL gain field failed.");
            test_failed = 1;
        end

        hw_level = 8'h5C;
        axi_read(8'h04, rd_data);
        if (rd_data !== 32'h00005C00) begin
            $display("ERROR: STATUS read without IRQ bit set returned wrong value. Got %h", rd_data);
            test_failed = 1;
        end

        @(negedge clk);
        irq_evt = 1'b1;
        @(posedge clk);
        #1 irq_evt = 1'b0;
        if (irq_sticky !== 1'b1) begin
            $display("ERROR: irq_evt did not set irq_sticky.");
            test_failed = 1;
        end

        axi_read(8'h04, rd_data);
        if (rd_data !== 32'h00005C01) begin
            $display("ERROR: STATUS read with IRQ bit set returned wrong value. Got %h", rd_data);
            test_failed = 1;
        end

        axi_write(8'h04, 32'h00000000, 4'b0001);
        if (irq_sticky !== 1'b1) begin
            $display("ERROR: writing 0 incorrectly cleared irq_sticky.");
            test_failed = 1;
        end

        axi_write(8'h04, 32'h00000001, 4'b0001);
        if (irq_sticky !== 1'b0) begin
            $display("ERROR: W1C clear of irq_sticky failed.");
            test_failed = 1;
        end

        axi_write_cmd(8'h08, 32'h00000001, 4'b0001);

        @(posedge clk);
        #1;
        if (kick_pulse !== 1'b0) begin
            $display("ERROR: kick_pulse lasted longer than one cycle.");
            test_failed = 1;
        end

        axi_read(8'h08, rd_data);
        if (rd_data !== 32'h00000000) begin
            $display("ERROR: CMD register should read as zero. Got %h", rd_data);
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
