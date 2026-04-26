module dot11_tx_rate_decode(
    input [3:0] bram_rate,
    output reg [2:0] N_BPSC,
    output reg [8:0] N_DBPS,
    output reg [4:0] RATE
);
always @* begin
    case(bram_rate)
        4'b1011: begin  N_BPSC = 1;  N_DBPS = 24;  RATE = 5'b01011; end
        4'b1111: begin  N_BPSC = 1;  N_DBPS = 36;  RATE = 5'b01111; end
        4'b1010: begin  N_BPSC = 2;  N_DBPS = 48;  RATE = 5'b01010; end
        4'b1110: begin  N_BPSC = 2;  N_DBPS = 72;  RATE = 5'b01110; end
        4'b1001: begin  N_BPSC = 4;  N_DBPS = 96;  RATE = 5'b01001; end
        4'b1101: begin  N_BPSC = 4;  N_DBPS = 144; RATE = 5'b01101; end
        4'b1000: begin  N_BPSC = 6;  N_DBPS = 192; RATE = 5'b01000; end
        4'b1100: begin  N_BPSC = 6;  N_DBPS = 216; RATE = 5'b01100; end
        default: begin  N_BPSC = 1;  N_DBPS = 24;  RATE = 5'b01011; end
    endcase
end
endmodule
