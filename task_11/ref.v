module axi2apb_write_bridge (
    input wire clk,
    input wire rst_n,
    
    // AXI4-Lite Write Channel
    input wire [31:0] awaddr,
    input wire awvalid,
    output reg awready,
    input wire [31:0] wdata,
    input wire wvalid,
    output reg wready,
    output reg [1:0] bresp,
    output reg bvalid,
    input wire bready,
    
    // APB4 Master Interface
    output reg [31:0] paddr,
    output reg psel,
    output reg penable,
    output reg pwrite,
    output reg [31:0] pwdata,
    input wire pready,
    input wire pslverr
);

    localparam IDLE   = 2'b00;
    localparam SETUP  = 2'b01;
    localparam ACCESS = 2'b10;
    localparam RESP   = 2'b11;

    reg [1:0] state, next_state;
    reg [31:0] addr_reg, data_reg;
    reg err_reg;

    // FSM sequential
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Data capture
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_reg <= 32'b0;
            data_reg <= 32'b0;
            err_reg <= 1'b0;
        end else begin
            if (state == IDLE && awvalid && wvalid) begin
                addr_reg <= awaddr;
                data_reg <= wdata;
            end else if (state == ACCESS && pready) begin
                err_reg <= pslverr;
            end
        end
    end

    // FSM combinatorial
    always @(*) begin
        next_state = state;
        
        // Default outputs
        awready = 1'b0;
        wready  = 1'b0;
        bvalid  = 1'b0;
        bresp   = 2'b00;
        
        psel    = 1'b0;
        penable = 1'b0;
        pwrite  = 1'b0;
        paddr   = 32'b0;
        pwdata  = 32'b0;

        case (state)
            IDLE: begin
                if (awvalid && wvalid) begin
                    awready = 1'b1;
                    wready  = 1'b1;
                    next_state = SETUP;
                end
            end
            SETUP: begin
                psel   = 1'b1;
                pwrite = 1'b1;
                paddr  = addr_reg;
                pwdata = data_reg;
                next_state = ACCESS;
            end
            ACCESS: begin
                psel    = 1'b1;
                penable = 1'b1;
                pwrite  = 1'b1;
                paddr   = addr_reg;
                pwdata  = data_reg;
                if (pready) begin
                    next_state = RESP;
                end
            end
            RESP: begin
                bvalid = 1'b1;
                bresp  = err_reg ? 2'b10 : 2'b00;
                if (bready) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

endmodule
