module shared_reg (
    input wire clk,
    input wire rst_n,
    input wire req_a,
    input wire [31:0] data_a,
    input wire req_b,
    input wire [31:0] data_b,
    output wire [31:0] read_data
);

    reg [31:0] internal_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            internal_reg <= 32'b0;
        end else begin
            // INTENTIONAL FLAW: Lack of 'else' creates a priority inversion.
            // If both req_a and req_b are high, the bottom assignment overwrites 
            // the top assignment. Agent B wins the race instead of Agent A!
            if (req_a) internal_reg <= data_a;
            if (req_b) internal_reg <= data_b; 
        end
    end

    assign read_data = internal_reg;

endmodule
