module apb_lock_cfg (
    input wire clk,
    input wire rst_n,
    input wire psel,
    input wire penable,
    input wire pwrite,
    input wire [7:0] paddr,
    input wire [31:0] pwdata,
    input wire [3:0] pstrb,
    output reg [31:0] prdata,
    output wire pready,
    input wire hw_fault_evt,
    output wire [1:0] mode,
    output wire [7:0] limit,
    output wire cfg_locked,
    output wire fault_sticky,
    output reg apply_pulse
);

    reg [1:0] mode_reg;
    reg [7:0] limit_reg;
    reg lock_reg;
    reg fault_reg;

    wire apb_write;

    assign apb_write = psel && penable && pwrite;
    assign pready = 1'b1;
    assign mode = mode_reg;
    assign limit = limit_reg;
    assign cfg_locked = lock_reg;
    assign fault_sticky = fault_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode_reg <= 2'b01;
            limit_reg <= 8'h20;
            lock_reg <= 1'b0;
            fault_reg <= 1'b0;
            apply_pulse <= 1'b0;
        end else begin
            apply_pulse <= 1'b0;

            if (hw_fault_evt) begin
                fault_reg <= 1'b1;
            end

            if (apb_write) begin
                case (paddr)
                    8'h00: begin
                        if (!lock_reg) begin
                            if (pstrb[0]) begin
                                mode_reg <= pwdata[1:0];
                            end
                            if (pstrb[1]) begin
                                limit_reg <= pwdata[15:8];
                            end
                        end
                    end
                    8'h04: begin
                        if (pstrb[0] && pwdata[0]) begin
                            lock_reg <= 1'b1;
                        end
                    end
                    8'h08: begin
                        if (pstrb[0] && pwdata[0]) begin
                            fault_reg <= 1'b0;
                        end
                    end
                    8'h0C: begin
                        if (pstrb[0] && pwdata[0]) begin
                            apply_pulse <= 1'b1;
                        end
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

    always @(*) begin
        case (paddr)
            8'h00: prdata = {16'h0000, limit_reg, 6'b000000, mode_reg};
            8'h04: prdata = {31'h00000000, lock_reg};
            8'h08: prdata = {31'h00000000, fault_reg};
            8'h0C: prdata = 32'h00000000;
            default: prdata = 32'h00000000;
        endcase
    end

endmodule
