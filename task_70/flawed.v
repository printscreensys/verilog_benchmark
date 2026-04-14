module apb_timer_csr (
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
    input wire [7:0] hw_status,
    input wire timer_done_evt,
    output wire timer_enable,
    output wire [7:0] threshold,
    output reg clear_done_pulse,
    output wire irq_pending
);

    reg enable_reg;
    reg [7:0] threshold_reg;
    reg done_sticky;

    wire apb_write;

    assign apb_write = psel && penable && pwrite;
    assign pready = 1'b1;
    assign timer_enable = enable_reg;
    assign threshold = threshold_reg;
    assign irq_pending = done_sticky;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enable_reg <= 1'b0;
            threshold_reg <= 8'h10;
            done_sticky <= 1'b0;
            clear_done_pulse <= 1'b0;
        end else begin
            if (timer_done_evt) begin
                done_sticky <= 1'b1;
            end

            if (apb_write) begin
                case (paddr)
                    8'h00: begin
                        // INTENTIONAL FLAW: ignores byte enables and reserved-bit masking.
                        enable_reg <= pwdata[0];
                        threshold_reg <= pwdata[15:8];
                    end
                    8'h08: begin
                        // INTENTIONAL FLAW: clears on any write, not write-one-to-clear.
                        if (pstrb[0]) begin
                            done_sticky <= 1'b0;
                        end
                    end
                    8'h0C: begin
                        // INTENTIONAL FLAW: pulse becomes sticky once written.
                        if (pstrb[0] && pwdata[0]) begin
                            clear_done_pulse <= 1'b1;
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
            8'h00: prdata = {16'h0000, threshold_reg, 7'b0000000, enable_reg};
            8'h04: prdata = {24'h000000, hw_status};
            8'h08: prdata = {31'h00000000, done_sticky};
            8'h0C: prdata = 32'h00000000;
            default: prdata = 32'h00000000;
        endcase
    end

endmodule
