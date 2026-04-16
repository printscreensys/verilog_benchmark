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

    reg have_lower_word;
    reg [31:0] lower_data_reg;
    reg [31:0] s_data_sampled_reg;
    reg s_valid_sampled_reg;
    reg m_ready_sampled_reg;

    // The assembled 64-bit beat is visible as soon as the second 32-bit word
    // is presented while the first word is buffered.
    assign s_ready = !have_lower_word || m_ready;
    assign m_valid = have_lower_word && s_valid;
    assign m_data = {s_data, lower_data_reg};

    // Stage the live handshake inputs away from the state-update edge so the
    // sequential packing logic consumes a stable word/ready observation.
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_data_sampled_reg <= 32'b0;
            s_valid_sampled_reg <= 1'b0;
            m_ready_sampled_reg <= 1'b0;
        end else begin
            s_data_sampled_reg <= s_data;
            s_valid_sampled_reg <= s_valid;
            m_ready_sampled_reg <= m_ready;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            have_lower_word <= 1'b0;
            lower_data_reg <= 32'b0;
        end else begin
            if (!have_lower_word) begin
                if (s_valid_sampled_reg) begin
                    lower_data_reg <= s_data_sampled_reg;
                    have_lower_word <= 1'b1;
                end
            end else if (s_valid_sampled_reg && m_ready_sampled_reg) begin
                have_lower_word <= 1'b0;
            end
        end
    end

endmodule
