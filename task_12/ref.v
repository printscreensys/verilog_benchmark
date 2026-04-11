module width_upsizer (
    input wire clk,
    input wire rst_n,
    
    input wire [31:0] s_data,
    input wire s_valid,
    output wire s_ready,
    
    output wire [63:0] m_data,
    output wire m_valid,
    input wire m_ready
);

    reg word_idx; // 0 = waiting for first word, 1 = waiting for second word
    reg [31:0] lower_data_reg;

    // Ready to accept the first word anytime. 
    // Ready to accept the second word ONLY if the master will consume the 64-bit word this cycle.
    assign s_ready = (word_idx == 1'b0) || m_ready;
    
    // Output is valid when we have the first word stored and the second word is currently on the input bus.
    assign m_valid = (word_idx == 1'b1) && s_valid;
    
    // First word is LOWER [31:0], Second word (current s_data) is UPPER [63:32]
    assign m_data = {s_data, lower_data_reg};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            word_idx <= 1'b0;
            lower_data_reg <= 32'b0;
        end else begin
            if (s_valid && s_ready) begin
                if (word_idx == 1'b0) begin
                    lower_data_reg <= s_data; // Store first word
                    word_idx <= 1'b1;         // Move to wait for second word
                end else begin
                    word_idx <= 1'b0;         // Master consumed data, reset index
                end
            end
        end
    end

endmodule
