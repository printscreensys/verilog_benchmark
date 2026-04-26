module eth_txethmac_nibble_mux(
    input StatePreamble,
    input [1:0] StateData,
    input StateFCS,
    input StateJam,
    input NibCntEq15,
    input [7:0] TxData,
    input [31:0] Crc,
    output reg [3:0] MTxD_d
);
always @* begin
  if(StateData[0])
    MTxD_d[3:0] = TxData[3:0];
  else
  if(StateData[1])
    MTxD_d[3:0] = TxData[7:4];
  else
  if(StateFCS)
    MTxD_d[3:0] = {~Crc[28], ~Crc[29], ~Crc[30], ~Crc[31]};
  else
  if(StateJam)
    MTxD_d[3:0] = 4'h9;
  else
  if(StatePreamble)
    if(NibCntEq15)
      MTxD_d[3:0] = 4'hd;
    else
      MTxD_d[3:0] = 4'h5;
  else
    MTxD_d[3:0] = 4'h0;
end
endmodule
