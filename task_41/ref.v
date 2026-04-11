module ucie_flit_packager (
    input wire clk,
    input wire rst_n,
    
    input wire [63:0] soc_data,
    input wire soc_valid,
    output wire soc_ready,
    
    output wire [71:0] fdi_data,
    output wire fdi_valid,
    input wire fdi_ready
);

    reg [6:0] seq_num;

    // Combinatorial passthrough for streaming flow control
    assign soc_ready = fdi_ready;
    assign fdi_valid = soc_valid;
    
    // Flit Assembly
    assign fdi_data = {1'b1, seq_num, soc_data};

    // Strict Sequence Number Generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_num <= 7'd0;
        end else begin
            // Only increment when a transfer is ACTUALLY consumed by the D2D PHY
            if (soc_valid && fdi_ready) begin
                seq_num <= seq_num + 1'b1;
            end
        end
    end

endmodule
