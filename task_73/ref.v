module apb_sample_csr (
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
    input wire sample_push,
    input wire [7:0] sample_data,
    output wire [7:0] threshold,
    output wire irq_out,
    output reg ack_pulse
);

    reg [7:0] threshold_reg;
    reg [7:0] sample_latched;
    reg data_pending;

    wire apb_write;
    wire apb_read;

    assign apb_write = psel && penable && pwrite;
    assign apb_read = psel && penable && !pwrite;
    assign pready = 1'b1;
    assign threshold = threshold_reg;
    assign irq_out = data_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            threshold_reg <= 8'h20;
            sample_latched <= 8'h00;
            data_pending <= 1'b0;
            ack_pulse <= 1'b0;
        end else begin
            ack_pulse <= 1'b0;

            if (sample_push) begin
                sample_latched <= sample_data;
                data_pending <= 1'b1;
            end

            if (apb_write) begin
                case (paddr)
                    8'h00: begin
                        if (pstrb[0]) begin
                            threshold_reg <= pwdata[7:0];
                        end
                    end
                    8'h0C: begin
                        if (pstrb[0] && pwdata[0]) begin
                            ack_pulse <= 1'b1;
                        end
                    end
                    default: begin
                    end
                endcase
            end

            if (apb_read && paddr == 8'h08) begin
                data_pending <= 1'b0;
            end
        end
    end

    always @(*) begin
        case (paddr)
            8'h00: prdata = {24'h000000, threshold_reg};
            8'h04: prdata = {31'h00000000, data_pending};
            8'h08: prdata = {24'h000000, sample_latched};
            8'h0C: prdata = 32'h00000000;
            default: prdata = 32'h00000000;
        endcase
    end

endmodule
