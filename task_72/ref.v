module axil_sensor_csr (
    input wire clk,
    input wire rst_n,
    input wire [7:0] awaddr,
    input wire awvalid,
    output wire awready,
    input wire [31:0] wdata,
    input wire [3:0] wstrb,
    input wire wvalid,
    output wire wready,
    output wire [1:0] bresp,
    output reg bvalid,
    input wire bready,
    input wire [7:0] araddr,
    input wire arvalid,
    output wire arready,
    output reg [31:0] rdata,
    output wire [1:0] rresp,
    output reg rvalid,
    input wire rready,
    input wire [7:0] hw_level,
    input wire irq_evt,
    output wire block_enable,
    output wire [7:0] gain,
    output reg kick_pulse,
    output wire irq_sticky
);

    reg enable_reg;
    reg [7:0] gain_reg;
    reg irq_sticky_reg;

    wire write_fire;
    wire read_fire;

    assign awready = !bvalid;
    assign wready = !bvalid;
    assign bresp = 2'b00;
    assign arready = !rvalid;
    assign rresp = 2'b00;
    assign block_enable = enable_reg;
    assign gain = gain_reg;
    assign irq_sticky = irq_sticky_reg;

    assign write_fire = awvalid && wvalid && awready && wready;
    assign read_fire = arvalid && arready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enable_reg <= 1'b0;
            gain_reg <= 8'h08;
            irq_sticky_reg <= 1'b0;
            kick_pulse <= 1'b0;
            bvalid <= 1'b0;
            rvalid <= 1'b0;
            rdata <= 32'h00000000;
        end else begin
            kick_pulse <= 1'b0;

            if (irq_evt) begin
                irq_sticky_reg <= 1'b1;
            end

            if (write_fire) begin
                case (awaddr)
                    8'h00: begin
                        if (wstrb[0]) begin
                            enable_reg <= wdata[0];
                        end
                        if (wstrb[1]) begin
                            gain_reg <= wdata[15:8];
                        end
                    end
                    8'h04: begin
                        if (wstrb[0] && wdata[0]) begin
                            irq_sticky_reg <= 1'b0;
                        end
                    end
                    8'h08: begin
                        if (wstrb[0] && wdata[0]) begin
                            kick_pulse <= 1'b1;
                        end
                    end
                    default: begin
                    end
                endcase
                bvalid <= 1'b1;
            end else if (bvalid && bready) begin
                bvalid <= 1'b0;
            end

            if (read_fire) begin
                case (araddr)
                    8'h00: rdata <= {16'h0000, gain_reg, 7'b0000000, enable_reg};
                    8'h04: rdata <= {16'h0000, hw_level, 7'b0000000, irq_sticky_reg};
                    8'h08: rdata <= 32'h00000000;
                    default: rdata <= 32'h00000000;
                endcase
                rvalid <= 1'b1;
            end else if (rvalid && rready) begin
                rvalid <= 1'b0;
            end
        end
    end

endmodule
