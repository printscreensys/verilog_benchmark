`timescale 1ns/1ps

module tb_axi_arbiter;

    logic clk;
    logic rst_n;
    
    always #5 clk = ~clk;
    
    // DUT instantiation
    axi_arbiter_wrapper u_dut (
        .clk   (clk),
        .rst_n (rst_n)
    );
    
    // Test metrics
    int master_packets[3] = '{0, 0, 0};
    int master_grants[3] = '{0, 0, 0};
    int total_packets = 0;
    int arbitration_latency_sum = 0;
    
    initial begin
        clk = 0;
        rst_n = 0;
        repeat(10) @(posedge clk);
        rst_n = 1;
        
        // Wait for simulation to complete
        repeat(1000) @(posedge clk);
        
        // Calculate fairness
        real fairness = 1.0;
        if (total_packets > 0) begin
            real expected = total_packets / 3.0;
            real variance = 0.0;
            for (int i = 0; i < 3; i++) begin
                variance += (master_packets[i] - expected) ** 2;
            end
            fairness = 1.0 / (1.0 + variance / total_packets);
        end
        
        // Report results
        $display("========================================");
        $display("ARBITRATION TEST SUMMARY");
        $display("========================================");
        $display("Master 0 packets: %0d (grants: %0d)", master_packets[0], master_grants[0]);
        $display("Master 1 packets: %0d (grants: %0d)", master_packets[1], master_grants[1]);
        $display("Master 2 packets: %0d (grants: %0d)", master_packets[2], master_grants[2]);
        $display("Total packets transmitted: %0d", total_packets);
        $display("Average arbitration latency: %0d cycles", 
                 total_packets > 0 ? arbitration_latency_sum / total_packets : 0);
        $display("Fairness score: %.3f", fairness);
        
        if (total_packets >= 30 && fairness >= 0.9) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED");
        end
        $display("========================================");
        
        $finish;
    end
    
    // Monitor grants (would need internal signal access)
    // This is a simplified version - actual testbench would probe internal signals
    
    initial begin
        $dumpfile("tb_axi_arbiter.vcd");
        $dumpvars(0, tb_axi_arbiter);
    end

endmodule