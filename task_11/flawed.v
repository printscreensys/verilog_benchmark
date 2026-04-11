module axi2apb_write_bridge (
    input wire clk, input wire rst_n,
    input wire [31:0] awaddr, input wire awvalid, output reg awready,
    input wire [31:0] wdata, input wire wvalid, output reg wready,
    output reg [1:0] bresp, output reg bvalid, input wire bready,
    output reg [31:0] paddr, output reg psel, output reg penable,
    output reg pwrite, output reg [31:0] pwdata, input wire pready, input wire pslverr
);
    localparam IDLE = 2'b00, SETUP = 2'b01, ACCESS = 2'b10, RESP = 2'b11;
    reg [1:0] state, next_state;
    reg [31:0] addr_reg, data_reg; reg err_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_reg <= 0; data_reg <= 0; err_reg <= 0;
        end else if (state == IDLE && awvalid && wvalid) begin
            addr_reg <= awaddr; data_reg <= wdata;
        end else if (state == ACCESS) begin
            err_reg <= pslverr;
        end
    end

    always @(*) begin
        next_state = state;
        awready = 0; wready = 0; bvalid = 0; bresp = 0;
        psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;

        case (state)
            IDLE: begin
                if (awvalid && wvalid) begin awready = 1; wready = 1; next_state = SETUP; end
            end
            SETUP: begin
                psel = 1; pwrite = 1; paddr = addr_reg; pwdata = data_reg; next_state = ACCESS;
            end
            ACCESS: begin
                psel = 1; penable = 1; pwrite = 1; paddr = addr_reg; pwdata = data_reg;
                // INTENTIONAL FLAW: Bridge ignores `pready` wait state requirement.
                // Transitions instantly. Causes protocol violations on slow slaves!
                next_state = RESP; 
            end
            RESP: begin
                bvalid = 1; bresp = err_reg ? 2'b10 : 2'b00;
                if (bready) next_state = IDLE;
            end
        endcase
    end
endmodule
