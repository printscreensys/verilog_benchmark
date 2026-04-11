`timescale 1ns / 1ps

module tb_task_12;

    reg clk, rst_n;
    // Slave IF
    reg [31:0] s_data;
    reg s_valid;
    wire s_ready;
    // Master IF
    wire [63:0] m_data;
    wire m_valid;
    reg m_ready;

    reg test_failed = 0;

    width_upsizer dut (
        .clk(clk), .rst_n(rst_n),
        .s_data(s_data), .s_valid(s_valid), .s_ready(s_ready),
        .m_data(m_data), .m_valid(m_valid), .m_ready(m_ready)
    );

    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0; rst_n = 0;
        s_data = 0; s_valid = 0; m_ready = 1;

        #12 rst_n = 1;

        // --- TEST 1: Basic Packing & Endianness ---
        // Send First Word
        @(posedge clk);
        s_valid = 1; s_data = 32'hAAAAAAAA;
        wait(s_ready);
        
        // Send Second Word
        @(posedge clk);
        s_data = 32'hBBBBBBBB;
        
        // Wait for pipeline evaluation
        #1; 
        if (!m_valid) begin
            $display("ERROR: m_valid should be asserted when 2nd word is driven.");
            test_failed = 1;
        end
        
        // Correct packed data should be {Word 2, Word 1} -> 64'hBBBBBBBBAAAAAAAA
        if (m_data === 64'hAAAAAAAABBBBBBBB) begin
            $display("ERROR: Endianness inverted! Word 1 is in the upper bits.");
            test_failed = 1;
        end else if (m_data !== 64'hBBBBBBBBAAAAAAAA) begin
            $display("ERROR: Data packing failed! m_data = %h", m_data);
            test_failed = 1;
        end

        // --- TEST 2: Backpressure (Master Stalls) ---
        @(posedge clk);
        m_ready = 0; // Master applies backpressure!
        s_data = 32'h11111111; // Send Word 1 of second transfer
        
        @(posedge clk);
        s_data = 32'h22222222; // Send Word 2 of second transfer
        
        #1;
        if (s_ready) begin
            $display("ERROR: Handshake violation! s_ready did not fall when backpressured by master on 2nd word.");
            test_failed = 1;
        end

        // Keep driving until master is ready
        @(posedge clk);
        @(posedge clk);
        m_ready = 1; // Unstall
        
        #1;
        if (m_data !== 64'h2222222211111111 || !m_valid) begin
            $display("ERROR: Data lost during backpressure stall! m_data = %h", m_data);
            test_failed = 1;
        end

        @(posedge clk);
        s_valid = 0;

        #10;
        if (test_failed == 0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end
        $finish;
    end
endmodule
