`timescale 1ns / 1ps

module tb_task_41;

    reg clk;
    reg rst_n;
    
    reg [63:0] soc_data;
    reg soc_valid;
    wire soc_ready;
    
    wire [71:0] fdi_data;
    wire fdi_valid;
    reg fdi_ready;

    reg test_failed = 0;

    ucie_flit_packager dut (
        .clk(clk),
        .rst_n(rst_n),
        .soc_data(soc_data),
        .soc_valid(soc_valid),
        .soc_ready(soc_ready),
        .fdi_data(fdi_data),
        .fdi_valid(fdi_valid),
        .fdi_ready(fdi_ready)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst_n = 0;
        soc_data = 64'h0;
        soc_valid = 0;
        fdi_ready = 1;

        #12 rst_n = 1;

        // --- TEST 1: Normal Uninterrupted Streaming ---
        @(posedge clk);
        #1;
        soc_valid = 1;
        soc_data = 64'hAAAA;
        
        // Wait for evaluation. Seq should be 0.
        if (fdi_data[71:64] !== 8'h80) begin // 1'b1 + 7'b0000000
            $display("ERROR: Bad first flit header. Got %h, expected 80", fdi_data[71:64]);
            test_failed = 1;
        end
        
        @(posedge clk);
        #1;
        soc_data = 64'hBBBB;
        
        if (fdi_data[71:64] !== 8'h81) begin 
            $display("ERROR: Bad second flit header. Got %h, expected 81", fdi_data[71:64]);
            test_failed = 1;
        end

        // --- TEST 2: PHY Backpressure (fdi_ready = 0) ---
        @(posedge clk);
        #1;
        fdi_ready = 0;  // D2D adapter applies backpressure!
        soc_data = 64'hCCCC; // SoC is still trying to send a valid flit
        
        // Seq should currently be 2
        if (fdi_data[71:64] !== 8'h82) begin 
            $display("ERROR: Flit header corrupted upon immediate backpressure.");
            test_failed = 1;
        end

        // Wait another cycle with backpressure held.
        // A flawed seq_num counter will increment to 3 here because soc_valid is 1!
        @(posedge clk);
        #1;
        
        if (fdi_data[71:64] !== 8'h82) begin
            $display("ERROR: Sequence Runaway Detected! The wrapper incremented seq_num");
            $display("       even though fdi_ready was 0. Header is now %h, expected 82", fdi_data[71:64]);
            test_failed = 1;
        end

        // Release backpressure
        fdi_ready = 1;
        @(posedge clk);
        #1;
        soc_valid = 0; // End transmission
        
        // Final verify next cycle
        if (fdi_data[71:64] !== 8'h83) begin
            $display("ERROR: Sequence failed to resume properly after backpressure.");
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
