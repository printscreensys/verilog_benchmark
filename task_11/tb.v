`timescale 1ns / 1ps

module tb_task_11;

    reg clk, rst_n;
    // AXI
    reg [31:0] awaddr;
    reg awvalid;
    wire awready;
    reg [31:0] wdata;
    reg wvalid;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    reg bready;
    // APB
    wire [31:0] paddr;
    wire psel;
    wire penable;
    wire pwrite;
    wire [31:0] pwdata;
    reg pready;
    reg pslverr;

    reg test_failed = 0;

    axi2apb_write_bridge dut (
        .clk(clk), .rst_n(rst_n),
        .awaddr(awaddr), .awvalid(awvalid), .awready(awready),
        .wdata(wdata), .wvalid(wvalid), .wready(wready),
        .bresp(bresp), .bvalid(bvalid), .bready(bready),
        .paddr(paddr), .psel(psel), .penable(penable),
        .pwrite(pwrite), .pwdata(pwdata), .pready(pready), .pslverr(pslverr)
    );

    always #5 clk = ~clk;

    // MOCK APB SLAVE (Simulate 2-cycle delay)
    reg [2:0] apb_wait_cnt;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pready <= 0;
            apb_wait_cnt <= 0;
        end else begin
            if (psel && !penable) begin
                apb_wait_cnt <= 2; // Wait 2 cycles
                pready <= 0;
            end else if (psel && penable) begin
                if (apb_wait_cnt > 0) begin
                    apb_wait_cnt <= apb_wait_cnt - 1;
                    pready <= 0;
                end else begin
                    pready <= 1; // Assert ready ONLY after delay
                end
            end else begin
                pready <= 0;
            end
        end
    end

    // Protocol Violation Checker
    always @(posedge clk) begin
        if (bvalid && !pready && psel) begin
            $display("ERROR: Bridge returned AXI bvalid before APB slave asserted pready!");
            test_failed = 1;
        end
    end

    initial begin
        clk = 0; rst_n = 0;
        awaddr = 0; awvalid = 0; wdata = 0; wvalid = 0; bready = 0;
        pslverr = 0;

        #12 rst_n = 1;

        // Initiate AXI Write
        #10;
        awaddr = 32'h4000_1234;
        awvalid = 1;
        wdata = 32'hCAFE_BABE;
        wvalid = 1;
        bready = 1;

        // Wait for handshake
        wait(awready && wready);
        #10;
        awvalid = 0;
        wvalid = 0;

        // Wait for transaction complete
        wait(bvalid);
        
        #10;
        if (bresp !== 2'b00) begin
            $display("ERROR: Bad response, expected OKAY (00), got %b", bresp);
            test_failed = 1;
        end

        if (test_failed == 0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end
        $finish;
    end
endmodule
