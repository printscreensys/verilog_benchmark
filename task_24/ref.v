module cdc_bus_sync (
    input wire clk_a,
    input wire rst_n_a,
    input wire [15:0] data_a,
    input wire valid_a,
    
    input wire clk_b,
    input wire rst_n_b,
    output reg [15:0] data_b,
    output reg valid_b
);

    // 3-flop synchronizer to handle metastability and edge detection
    reg [2:0] valid_sync_b;

    always @(posedge clk_b or negedge rst_n_b) begin
        if (!rst_n_b) begin
            valid_sync_b <= 3'b000;
        end else begin
            // Shift register for synchronization
            valid_sync_b <= {valid_sync_b[1:0], valid_a};
        end
    end

    // Data capture logic (MUX Synchronizer)
    always @(posedge clk_b or negedge rst_n_b) begin
        if (!rst_n_b) begin
            data_b <= 16'h0000;
            valid_b <= 1'b0;
        end else begin
            // Detect rising edge of the fully synchronized valid signal
            if (valid_sync_b[1] == 1'b1 && valid_sync_b[2] == 1'b0) begin
                // Safely capture data_a directly (it has been stable for multiple clock cycles)
                data_b <= data_a;
                valid_b <= 1'b1;
            end else begin
                valid_b <= 1'b0;
            end
        end
    end

endmodule
