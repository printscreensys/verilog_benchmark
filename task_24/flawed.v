module cdc_bus_sync (
    input wire clk_a, input wire rst_n_a,
    input wire [15:0] data_a, input wire valid_a,
    input wire clk_b, input wire rst_n_b,
    output reg [15:0] data_b, output reg valid_b
);

    reg [2:0] valid_sync_b;
    
    // INTENTIONAL FLAW: Multi-flop synchronization on a data bus!
    reg [15:0] data_sync0;
    reg [15:0] data_sync1;

    always @(posedge clk_b or negedge rst_n_b) begin
        if (!rst_n_b) begin
            valid_sync_b <= 0;
            data_sync0 <= 0;
            data_sync1 <= 0;
            data_b <= 0;
            valid_b <= 0;
        end else begin
            // Valid signal sync
            valid_sync_b <= {valid_sync_b[1:0], valid_a};
            
            // FLAW: Blindly throwing flops at the data bus
            data_sync0 <= data_a;
            data_sync1 <= data_sync0;

            if (valid_sync_b[1] && !valid_sync_b[2]) begin
                // Captures the delayed (and potentially skewed/corrupted) data
                data_b <= data_sync1;
                valid_b <= 1;
            end else begin
                valid_b <= 0;
            end
        end
    end

endmodule
