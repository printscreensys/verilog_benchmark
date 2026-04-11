`timescale 1ns / 1ps

module tb_task_06;

    reg clk;
    reg rst_n;
    reg req_a;
    reg [31:0] data_a;
    reg req_b;
    reg [31:0] data_b;
    
    wire [31:0] read_data;

    reg test_failed = 0;

    // Instantiate DUT
    shared_reg dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_a(req_a),
        .data_a(data_a),
        .req_b(req_b),
        .data_b(data_b),
        .read_data(read_data)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        req_a = 0;
        data_a = 32'h00000000;
        req_b = 0;
        data_b = 32'h00000000;

        #10 rst_n = 1;

        // Test 1: Agent B writes alone
        #10;
        req_a = 0;
        req_b = 1;
        data_b = 32'hBBBBBBBB;
        #10;
        req_b = 0;
        #5;
        if (read_data !== 32'hBBBBBBBB) begin
            $display("ERROR: Agent B failed to write! Expected BBBBBBBB, got %h", read_data);
            test_failed = 1;
        end

        // Test 2: Agent A writes alone
        #5;
        req_a = 1;
        data_a = 32'hAAAAAAAA;
        req_b = 0;
        #10;
        req_a = 0;
        #5;
        if (read_data !== 32'hAAAAAAAA) begin
            $display("ERROR: Agent A failed to write! Expected AAAAAAAA, got %h", read_data);
            test_failed = 1;
        end

        // Test 3: RACE CONDITION (Both A and B request at the exact same time)
        #5;
        req_a = 1;
        data_a = 32'hA1A1A1A1;
        req_b = 1;
        data_b = 32'hB2B2B2B2;
        
        #10; // Clock tick completes
        req_a = 0;
        req_b = 0;
        
        #5; // Let outputs settle
        
        // Agent A has strict priority. Output MUST be A1A1A1A1.
        if (read_data === 32'hB2B2B2B2) begin
            $display("ERROR: RACE CONDITION FAILED! Priority inverted. Agent B overwrote Agent A.");
            test_failed = 1;
        end else if (read_data !== 32'hA1A1A1A1) begin
            $display("ERROR: RACE CONDITION FAILED! Corrupted state or unknown value: %h", read_data);
            test_failed = 1;
        end

        // Final Evaluation token
        if (test_failed == 0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end
        
        $finish;
    end
endmodule
