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

    assign soc_ready = fdi_ready;
    assign fdi_valid = soc_valid;
    assign fdi_data = {1'b1, seq_num, soc_data};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_num <= 7'd0;
        end else begin
            // INTENTIONAL FLAW: Sequence tracker ignores backpressure!
            // If the D2D adapter stalls (fdi_ready=0), seq_num increments anyway.
            // This drops sequence IDs and permanently shifts the payload-to-ID mapping.
            if (soc_valid) begin
                seq_num <= seq_num + 1'b1;
            end
        end
    end

endmodule
