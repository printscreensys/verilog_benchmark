`timescale 1ns / 1ps

module tb_task_24;

    reg clk_a, rst_n_a;
    reg [15:0] data_a;
    reg valid_a;

    reg clk_b, rst_n_b;
    wire [15:0] data_b;
    wire valid_b;

    reg test_failed = 0;

    cdc_bus_sync dut (
        .clk_a(clk_a), .rst_n_a(rst_n_a), .data_a(data_a), .valid_a(valid_a),
        .clk_b(clk_b), .rst_n_b(rst_n_b), .data_b(data_b), .valid_b(valid_b)
    );

    // TX Clock (Source)
    initial clk_a = 0;
    always #10 clk_a = ~clk_a;   // Period = 20ns

    // RX Clock (Destination) - Asynchronous
    initial clk_b = 0;
    always #6 clk_b = ~clk_b;    // Period = 12ns

    initial begin
        rst_n_a = 0; rst_n_b = 0;
        data_a = 16'h0000; valid_a = 0;

        #25; 
        rst_n_a = 1; rst_n_b = 1;

        #50;
        
        // --- INJECT ROUTING SKEW ---
        // We simulate trace length mismatches on the PCB or FPGA fabric.
        // We align this specifically right before a clk_b rising edge to trigger the vulnerability.
        
        @(posedge clk_a);
        #4.5; // Walk right up to a critical clk_b sampling edge
        
        // The valid signal and the LOWER 8 bits arrive fast
        valid_a = 1;
        data_a[7:0] = 8'hFF;
        
        // The UPPER 8 bits have physical routing delays, arriving 5ns slower!
        #5; 
        data_a[15:8] = 8'hFF;
        
        // Next cycle cleanup
        @(posedge clk_a);
        #5;
        valid_a = 0;

        // --- VERIFY RECEPTION ---
        // Wait for CDC logic to report valid data
        wait(valid_b);

        // MUX Synchronizer safely bypassed the skew because it waited for `valid_a` 
        // to sync (which takes >24ns). By then, data_a was fully stable at 0xFFFF.
        // FLAWED Synchronizer captured the initial 0x00FF intermediate state immediately 
        // into its pipeline and outputs it here!
        if (data_b === 16'h00FF) begin
            $display("ERROR: CDC Data Incoherency Vulnerability Detected!");
            $display("The module improperly synced the data bus with a shift register instead of a MUX sync.");
            $display("Output data = %h", data_b);
            test_failed = 1;
        end else if (data_b !== 16'hFFFF) begin
            $display("ERROR: Data corrupted during transfer. Expected FFFF, got %h", data_b);
            test_failed = 1;
        end

        #20;
        if (test_failed == 0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end
        $finish;
    end
    
    // Watchdog
    initial begin
        #1000;
        $display("ERROR: Simulation timed out. valid_b was never asserted.");
        $display("TEST_FAILED");
        $finish;
    end
endmodule
