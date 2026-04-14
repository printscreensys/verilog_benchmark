// pd_dsp identical to reference
module pd_dsp (
    input wire clk, input wire rst_n, input wire [31:0] data_in, output reg [31:0] data_out
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) data_out <= 32'b0;
        else data_out <= data_in;
    end
endmodule

module aon_ctrl (
    input wire clk,
    input wire rst_n,
    input wire sleep_req,
    output reg pwr_enable,
    output reg iso_en
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwr_enable <= 1'b1;
            iso_en <= 1'b0;
        end else begin
            // INTENTIONAL FLAW: Simultaneous toggling of UPF boundaries!
            // Fails to implement the safety staggering sequence.
            if (sleep_req) begin
                iso_en     <= 1'b1;
                pwr_enable <= 1'b0; 
            end else begin
                iso_en     <= 1'b0;
                pwr_enable <= 1'b1;
            end
        end
    end
endmodule

module soc_top (
    input wire clk, input wire rst_n, input wire sleep_req,
    input wire [31:0] data_in, output wire [31:0] data_out,
    output wire pwr_enable, output wire iso_en
);
    aon_ctrl u_aon_ctrl (.clk(clk), .rst_n(rst_n), .sleep_req(sleep_req), .pwr_enable(pwr_enable), .iso_en(iso_en));
    pd_dsp u_pd_dsp (.clk(clk), .rst_n(rst_n), .data_in(data_in), .data_out(data_out));
endmodule
