module pd_dsp (
    input wire clk,
    input wire rst_n,
    input wire [31:0] data_in,
    output reg [31:0] data_out
);
    // Standard logic; UPF synthesis will insert isolation on the outputs physically
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= 32'b0;
        else
            data_out <= data_in;
    end
endmodule

module aon_ctrl (
    input wire clk,
    input wire rst_n,
    input wire sleep_req,
    output reg pwr_enable,
    output reg iso_en
);
    localparam ST_ACTIVE = 2'd0;
    localparam ST_ISO_ON = 2'd1;
    localparam ST_SLEEP  = 2'd2;
    localparam ST_PWR_ON = 2'd3;

    reg [1:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= ST_ACTIVE;
        else state <= next_state;
    end

    always @(*) begin
        // Default outputs
        pwr_enable = 1'b1;
        iso_en = 1'b0;
        next_state = state;

        case (state)
            ST_ACTIVE: begin
                pwr_enable = 1'b1;
                iso_en = 1'b0;
                if (sleep_req) next_state = ST_ISO_ON;
            end
            ST_ISO_ON: begin
                pwr_enable = 1'b1; // Wait 1 cycle for ISO safety
                iso_en = 1'b1;
                next_state = ST_SLEEP;
            end
            ST_SLEEP: begin
                pwr_enable = 1'b0; // Safely powered off
                iso_en = 1'b1;
                if (!sleep_req) next_state = ST_PWR_ON;
            end
            ST_PWR_ON: begin
                pwr_enable = 1'b1; // Power restored, wait 1 cycle to stabilize
                iso_en = 1'b1;
                next_state = ST_ACTIVE;
            end
            default: next_state = ST_ACTIVE;
        endcase
    end
endmodule

module soc_top (
    input wire clk,
    input wire rst_n,
    input wire sleep_req,
    input wire [31:0] data_in,
    output wire [31:0] data_out,
    output wire pwr_enable,
    output wire iso_en
);

    aon_ctrl u_aon_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .sleep_req(sleep_req),
        .pwr_enable(pwr_enable),
        .iso_en(iso_en)
    );

    pd_dsp u_pd_dsp (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .data_out(data_out)
    );

endmodule
