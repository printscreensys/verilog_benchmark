module axi_stream_slave (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] tdata,
    input  logic        tvalid,
    output logic        tready,
    input  logic        tlast,
    input  logic [3:0]  tkeep,
    input  logic        tstrb
);
    
    logic [31:0] received_data;
    logic        backpressure_en;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tready <= 1'b0;
            backpressure_en <= 1'b0;
        end else begin
            tready <= $urandom_range(0, 1);
            if (tvalid && tready) begin
                received_data <= tdata;
            end
        end
    end

endmodule