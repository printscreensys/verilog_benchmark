module axi_stream_master (
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] tdata,
    output logic        tvalid,
    input  logic        tready,
    output logic        tlast,
    output logic [3:0]  tkeep,
    output logic        tstrb
);
    
    logic [31:0] data_reg;
    logic [7:0]  beat_count;
    logic        active;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= 32'hDEADBEEF;
            beat_count <= 8'd0;
            active <= 1'b0;
            tvalid <= 1'b0;
            tlast <= 1'b0;
        end else begin
            if (!active && beat_count < 8'd10) begin
                active <= 1'b1;
                tvalid <= 1'b1;
                data_reg <= $urandom;
                beat_count <= beat_count + 1;
            end else if (active && tvalid && tready) begin
                tvalid <= 1'b0;
                tlast <= (beat_count == 8'd4);
                if (tlast) begin
                    active <= 1'b0;
                end
            end
        end
    end
    
    assign tdata = data_reg;
    assign tkeep = 4'hF;
    assign tstrb = 1'b1;

endmodule