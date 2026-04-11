`timescale 1ns / 1ps

module tb_task_01;

    reg clk;
    reg rst_n;
    reg write_en;
    reg [31:0] secret_data;
    
    wire [31:0] debug_out_secure;
    wire [31:0] debug_out_leak;

    reg test_failed = 0;

    // Instantiate DUT in SECURE mode (Expect no leakage)
    secure_reg #(.SECURE_MODE(1)) dut_secure (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .secret_data(secret_data),
        .debug_out(debug_out_secure)
    );

    // Instantiate DUT in DEBUG/LEAK mode (Expect leakage)
    secure_reg #(.SECURE_MODE(0)) dut_leak (
        .clk(clk),
        .rst_n(rst_n),
        .write_en(write_en),
        .secret_data(secret_data),
        .debug_out(debug_out_leak)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        write_en = 0;
        secret_data = 32'h00000000;

        #10 rst_n = 1;

        // Test 1: Write secret data
        #10;
        write_en = 1;
        secret_data = 32'hDEADBEEF;
        #10;
        write_en = 0;

        // Check conditions
        #10;
        if (debug_out_secure !== 32'b0) begin
            $display("ERROR: Secret leaked in SECURE_MODE! debug_out = %h", debug_out_secure);
            test_failed = 1;
        end

        if (debug_out_leak !== 32'hDEADBEEF) begin
            $display("ERROR: Debug output failed in DEBUG mode! debug_out = %h", debug_out_leak);
            test_failed = 1;
        end

        // Test 2: Write new data
        #10;
        write_en = 1;
        secret_data = 32'hCAFEBABE;
        #10;
        write_en = 0;
        
        #10;
        if (debug_out_secure !== 32'b0) test_failed = 1;
        if (debug_out_leak !== 32'hCAFEBABE) test_failed = 1;

        // Final Evaluation token
        if (test_failed == 0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end
        
        $finish;
    end
endmodule
