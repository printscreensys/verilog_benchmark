module delayed_reset_release (
    input wire clk,
    input wire arst_n,
    input wire [1:0] release_delay,
    output reg srst_n,
    output reg init_pulse
);

    reg [1:0] sync_ff;
    reg [1:0] delay_cnt;
    reg delay_active;

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            sync_ff <= 2'b00;
            delay_cnt <= 2'b00;
            delay_active <= 1'b0;
            srst_n <= 1'b0;
            init_pulse <= 1'b0;
        end else begin
            sync_ff <= {sync_ff[0], 1'b1};
            init_pulse <= 1'b0;

            if (!srst_n) begin
                if (!delay_active) begin
                    if (sync_ff == 2'b01) begin
                        if (release_delay == 2'b00) begin
                            srst_n <= 1'b1;
                            init_pulse <= 1'b1;
                        end else begin
                            delay_active <= 1'b1;
                            delay_cnt <= release_delay;
                            srst_n <= 1'b0;
                        end
                    end else begin
                        delay_cnt <= 2'b00;
                        srst_n <= 1'b0;
                    end
                end else if (delay_cnt != 2'b00) begin
                    delay_cnt <= delay_cnt - 1'b1;
                    srst_n <= 1'b0;
                end else begin
                    srst_n <= 1'b1;
                    init_pulse <= 1'b1;
                    delay_active <= 1'b0;
                end
            end
        end
    end

endmodule
