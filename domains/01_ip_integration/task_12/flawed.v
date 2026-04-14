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

    reg word_idx;
    reg [31:0] first_word_reg;

    assign s_ready = (word_idx == 1'b0) || m_ready;
    assign m_valid = (word_idx == 1'b1) && s_valid;
    
    // INTENTIONAL FLAW 1: Endianness Reversal
    // LLM concatenated {Word 1, Word 2}. In Verilog, this puts Word 1 in the 
    // UPPER [63:32] bits, violating the little-endian specification!
    assign m_data = {first_word_reg, s_data};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            word_idx <= 1'b0;
            first_word_reg <= 32'b0;
        end else begin
            if (s_valid && s_ready) begin
                if (word_idx == 1'b0) begin
                    first_word_reg <= s_data;
                    word_idx <= 1'b1;
                end else begin
                    word_idx <= 1'b0;
                end
            end
        end
    end

endmodule
