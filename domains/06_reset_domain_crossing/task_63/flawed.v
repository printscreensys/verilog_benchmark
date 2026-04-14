module delayed_reset_release (
    input wire clk,
    input wire arst_n,
    input wire [1:0] release_delay,
    output reg srst_n,
    output reg init_pulse
);

    reg [1:0] sync_ff;

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            sync_ff <= 2'b00;
            srst_n <= 1'b0;
            init_pulse <= 1'b0;
        end else begin
            sync_ff <= {sync_ff[0], 1'b1};
            // INTENTIONAL FLAW: ignores the programmable delay and pulses init early.
            srst_n <= sync_ff[1];
            init_pulse <= sync_ff[1] & ~srst_n;
        end
    end

endmodule
