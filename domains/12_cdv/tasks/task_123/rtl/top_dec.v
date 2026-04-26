module top_dec  (clk, reset, dinW, dinE, dinS, dinN, dinLocal, dinBypass, PVBypass, PVLocal, doutW, doutE, doutS, doutN, doutLocal, doutBypass, pv_bypass_out);


input clk, reset;
input [`WIDTH_PORT-1:0] dinW, dinE, dinS, dinN;
input [`WIDTH_PORT-1:0] dinLocal, dinBypass;
input [`WIDTH_PV-1:0]   PVBypass, PVLocal;

output [`WIDTH_PORT-1:0] doutW, doutE, doutS, doutN;
output [`WIDTH_PORT-1:0]  doutLocal, doutBypass;
output [`WIDTH_PV-1:0]  pv_bypass_out;


// Pipeline register: stage 1
wire [`WIDTH_PORT-1:0] r_dinW, r_dinE, r_dinS, r_dinN;
dff_async_reset # (`WIDTH_PORT) pipeline_reg_1_west     (dinW, clk, reset, dinW[`POS_VALID], r_dinW);
dff_async_reset # (`WIDTH_PORT) pipeline_reg_1_east     (dinE, clk, reset, dinE[`POS_VALID], r_dinE); 
dff_async_reset # (`WIDTH_PORT) pipeline_reg_1_south    (dinS, clk, reset, dinS[`POS_VALID], r_dinS);
dff_async_reset # (`WIDTH_PORT) pipeline_reg_1_north    (dinN, clk, reset, dinN[`POS_VALID], r_dinN);

// for passing enable to zero out the data in case the enable of register is low
reg r_pipeline_1_n_en, r_pipeline_1_e_en, r_pipeline_1_s_en, r_pipeline_1_w_en;
always @ (posedge clk)  begin
  r_pipeline_1_n_en <= dinN[`POS_VALID];
  r_pipeline_1_e_en <= dinE[`POS_VALID];
  r_pipeline_1_s_en <= dinS[`POS_VALID];
  r_pipeline_1_w_en <= dinW[`POS_VALID];
end
 
// Select the value based on the enable of the input flits
wire [`WIDTH_PORT-1:0] w_dinN, w_dinE, w_dinS, w_dinW;
mux2to1 #(`WIDTH_PORT) din_mux_sel_n ({`WIDTH_PORT{1'b0}}, r_dinN, r_pipeline_1_n_en, w_dinN);
mux2to1 #(`WIDTH_PORT) din_mux_sel_e ({`WIDTH_PORT{1'b0}}, r_dinE, r_pipeline_1_e_en, w_dinE);
mux2to1 #(`WIDTH_PORT) din_mux_sel_s ({`WIDTH_PORT{1'b0}}, r_dinS, r_pipeline_1_s_en, w_dinS);
mux2to1 #(`WIDTH_PORT) din_mux_sel_w ({`WIDTH_PORT{1'b0}}, r_dinW, r_pipeline_1_w_en, w_dinW);

// Route computation
wire [`WIDTH_PV-1:0] prodVector [0:3];

rc #(`CORD_X, `CORD_Y) routeCompNorth ({w_dinN[`POS_X_DST], w_dinN[`POS_Y_DST]}, prodVector[0]);
rc #(`CORD_X, `CORD_Y) routeCompEast ({w_dinE[`POS_X_DST], w_dinE[`POS_Y_DST]}, prodVector[1]);
rc #(`CORD_X, `CORD_Y) routeCompSouth ({w_dinS[`POS_X_DST], w_dinS[`POS_Y_DST]}, prodVector[2]);
rc #(`CORD_X, `CORD_Y) routeCompWest ({w_dinW[`POS_X_DST], w_dinW[`POS_Y_DST]}, prodVector[3]);

wire [`WIDTH_INTERNAL_PV-1:0] pn_in  [0:3];
wire [`WIDTH_INTERNAL_PV-1:0] pn_out [0:3];

assign pn_in[0] = {prodVector[0], w_dinN};
assign pn_in[1] = {prodVector[1], w_dinE};
assign pn_in[2] = {prodVector[2], w_dinS};
assign pn_in[3] = {prodVector[3], w_dinW};

permutationNetwork permutationNetwork (pn_in[0], pn_in[1], pn_in[2], pn_in[3], pn_out[0], pn_out[1], pn_out[2], pn_out[3]);


// ----------------------------------------------------------------- //
//                 Pipeline Stage 2 - PA + XT;
// ----------------------------------------------------------------- //

wire [`WIDTH_PORT-1:0] r_dinBypass, r_dinL;
wire [`WIDTH_PV-1:0] r_PVLocal;
wire [`WIDTH_PV-1:0] r_PVBypass;
wire [`WIDTH_INTERNAL_PV-1:0] pn_out_reg [0:3];
reg r_pipeline_1_bypass_en; 

dff_async_reset # (`WIDTH_INTERNAL_PV) pipeline_reg_2_0 (pn_out[0], clk, reset, pn_out[0][`POS_VALID], pn_out_reg[0]);
dff_async_reset # (`WIDTH_INTERNAL_PV) pipeline_reg_2_1 (pn_out[1], clk, reset, pn_out[1][`POS_VALID], pn_out_reg[1]);
dff_async_reset # (`WIDTH_INTERNAL_PV) pipeline_reg_2_2 (pn_out[2], clk, reset, pn_out[2][`POS_VALID], pn_out_reg[2]);
dff_async_reset # (`WIDTH_INTERNAL_PV) pipeline_reg_2_3 (pn_out[3], clk, reset, pn_out[3][`POS_VALID], pn_out_reg[3]);
dff_async_reset # (`WIDTH_PORT) pipeline_reg_1_local    (dinLocal, clk, reset, dinLocal[`POS_VALID], r_dinL);
dff_async_reset # (`WIDTH_PV)   pipeline_reg_1_pv_local (PVLocal, clk, reset, dinLocal[`POS_VALID], r_PVLocal);
dff_async_reset # (`WIDTH_PORT) pipeline_reg_2_4  (dinBypass, clk, reset, dinBypass[`POS_VALID], r_dinBypass); // Directly connect with input port
dff_async_reset # (`WIDTH_PV) pipeline_reg_2_5 (PVBypass, clk, reset, dinBypass[`POS_VALID], r_PVBypass); // Directly connect with input port


// for passing enable to zero out the data in case the enable of register is low
reg r_pipeline_2_en [0:5];
always @ (posedge clk) begin
  r_pipeline_2_en[0] <= pn_out[0][`POS_VALID];
  r_pipeline_2_en[1] <= pn_out[1][`POS_VALID];
  r_pipeline_2_en[2] <= pn_out[2][`POS_VALID];
  r_pipeline_2_en[3] <= pn_out[3][`POS_VALID];
  r_pipeline_2_en[4] <= dinBypass[`POS_VALID];
  r_pipeline_2_en[5] <= dinLocal[`POS_VALID];
end

// Select the value based on the enable of the input flits
wire [`WIDTH_INTERNAL_PV-1:0] w_pipeline_2_reg [0:3];
wire [`WIDTH_PORT-1:0] w_dinBypass, w_dinLocal;
wire [`WIDTH_PV-1:0] w_PVBypass;
wire [`WIDTH_PV-1:0] w_PVLocal;
mux2to1 #(`WIDTH_INTERNAL_PV) mux_sel_st2_0 ({`WIDTH_INTERNAL_PV{1'b0}}, pn_out_reg[0], r_pipeline_2_en[0], w_pipeline_2_reg[0]);
mux2to1 #(`WIDTH_INTERNAL_PV) mux_sel_st2_1 ({`WIDTH_INTERNAL_PV{1'b0}}, pn_out_reg[1], r_pipeline_2_en[1], w_pipeline_2_reg[1]);
mux2to1 #(`WIDTH_INTERNAL_PV) mux_sel_st2_2 ({`WIDTH_INTERNAL_PV{1'b0}}, pn_out_reg[2], r_pipeline_2_en[2], w_pipeline_2_reg[2]);
mux2to1 #(`WIDTH_INTERNAL_PV) mux_sel_st2_3 ({`WIDTH_INTERNAL_PV{1'b0}}, pn_out_reg[3], r_pipeline_2_en[3], w_pipeline_2_reg[3]);
mux2to1 #(`WIDTH_PORT) mux_sel_st2_4 ({`WIDTH_PORT{1'b0}}, r_dinBypass, r_pipeline_2_en[4], w_dinBypass);
mux2to1 #(`WIDTH_PORT) mux_sel_st2_5 ({`WIDTH_PORT{1'b0}}, r_dinL, r_pipeline_2_en[5], w_dinLocal);
mux2to1 #(`WIDTH_PV) mux_sel_st2_PVBypass ({`WIDTH_PV{1'b0}}, r_PVBypass, r_pipeline_2_en[4], w_PVBypass);
mux2to1 #(`WIDTH_PV) mux_sel_st2_PVLocal ({`WIDTH_PV{1'b0}}, r_PVLocal, r_pipeline_2_en[5], w_PVLocal);

// Port Allocation
wire [`NUM_CHANNEL*`WIDTH_PV-1:0] reqVector;
wire [`NUM_CHANNEL*`NUM_PORT-1:0] allocVector;
wire [`NUM_CHANNEL-1:0] validVector1;
wire vld_bypass;

assign vld_bypass = (w_dinBypass[`POS_VALID] == 0) ? 1'b0 : 1'b1;

assign reqVector = {w_PVBypass,w_pipeline_2_reg[3][`POS_PV],w_pipeline_2_reg[2][`POS_PV],w_pipeline_2_reg[1][`POS_PV],w_pipeline_2_reg[0][`POS_PV]};
assign validVector1 = {vld_bypass, w_pipeline_2_reg[3][`POS_VALID],w_pipeline_2_reg[2][`POS_VALID],w_pipeline_2_reg[1][`POS_VALID],w_pipeline_2_reg[0][`POS_VALID]};

portAllocParallel portAllocParallel (reqVector, validVector1, allocVector);

wire [`WIDTH_PORT-1:0] localOut; // ejection to local port
wire [`WIDTH_PORT-1:0] XbarPktIn [0:`NUM_CHANNEL-1];
wire [`NUM_CHANNEL*`WIDTH_PV-1:0] XbarPVIn;

local local (
.allocVector     (allocVector), 
.validVector1    (validVector1), 
.pipeline_reg1_0 (w_pipeline_2_reg[0][`WIDTH_PORT-1:0]),
.pipeline_reg1_1 (w_pipeline_2_reg[1][`WIDTH_PORT-1:0]),
.pipeline_reg1_2 (w_pipeline_2_reg[2][`WIDTH_PORT-1:0]),
.pipeline_reg1_3 (w_pipeline_2_reg[3][`WIDTH_PORT-1:0]), 
.dinBypass       (w_dinBypass), 
.dinLocal        (w_dinLocal), 
.PVLocal         (w_PVLocal), 
// output
.XbarPktIn0      (XbarPktIn[0]),
.XbarPktIn1      (XbarPktIn[1]), 
.XbarPktIn2      (XbarPktIn[2]), 
.XbarPktIn3      (XbarPktIn[3]), 
.XbarPktIn4      (XbarPktIn[4]), 
.localOut        (localOut), 
.XbarPVIn        (XbarPVIn)     // port allocation result going to Xbar
);


// Switch Traversal
wire [`WIDTH_PORT-1:0] XbarOutW, XbarOutE, XbarOutS, XbarOutN, XbarOutBypass;

xbar5Ports xbar5Ports (XbarPVIn, XbarPktIn[0], XbarPktIn[1], XbarPktIn[2], XbarPktIn[3], XbarPktIn[4], XbarOutN, XbarOutE, XbarOutS, XbarOutW, XbarOutBypass);

// forward PV of bypass flit
reg [`WIDTH_PV-1:0] pv_bypass_o;
always @ * begin
   if (XbarPVIn[4]) pv_bypass_o = XbarPVIn[0*`WIDTH_PV+:`WIDTH_PV];
   else if (XbarPVIn[9]) pv_bypass_o = XbarPVIn[1*`WIDTH_PV+:`WIDTH_PV];
   else if (XbarPVIn[14]) pv_bypass_o = XbarPVIn[2*`WIDTH_PV+:`WIDTH_PV];
   else if (XbarPVIn[19]) pv_bypass_o = XbarPVIn[3*`WIDTH_PV+:`WIDTH_PV];
   else if (XbarPVIn[24]) pv_bypass_o = w_PVBypass;
   else
      pv_bypass_o = 0;
end

// ----------------------------------------------------------------- //
//                 Pipeline Stage 3 - LT;
// ----------------------------------------------------------------- //
wire [`WIDTH_PORT-1:0] r_doutW, r_doutE, r_doutS, r_doutN, r_doutLocal, r_doutBypass;
wire [`WIDTH_PV-1:0]  r_pv_bypass;

dff_async_reset # (`WIDTH_PORT) pipeline_reg_3_west (XbarOutW, clk, reset, XbarOutW[`POS_VALID], r_doutW);
dff_async_reset # (`WIDTH_PORT) pipeline_reg_3_south (XbarOutS, clk, reset, XbarOutS[`POS_VALID], r_doutS);
dff_async_reset # (`WIDTH_PORT) pipeline_reg_3_east (XbarOutE, clk, reset, XbarOutE[`POS_VALID], r_doutE);
dff_async_reset # (`WIDTH_PORT) pipeline_reg_3_north (XbarOutN, clk, reset, XbarOutN[`POS_VALID], r_doutN);
dff_async_reset # (`WIDTH_PORT) pipeline_reg_3_local (localOut, clk, reset, localOut[`POS_VALID], r_doutLocal);
dff_async_reset # (`WIDTH_PORT) pipeline_reg_3_bypass (XbarOutBypass, clk, reset, XbarOutBypass[`POS_VALID], r_doutBypass);
dff_async_reset # (`WIDTH_PV) pipeline_reg_3_bypass_ppv (pv_bypass_o, clk, reset, XbarOutBypass[`POS_VALID], r_pv_bypass);

// for passing enable to zero out the data in case the enable of register is low
reg r_pipeline_3_en [0:5];
always @ (posedge clk) begin
  r_pipeline_3_en[0] <= XbarOutN[`POS_VALID];
  r_pipeline_3_en[1] <= XbarOutE[`POS_VALID];
  r_pipeline_3_en[2] <= XbarOutS[`POS_VALID];
  r_pipeline_3_en[3] <= XbarOutW[`POS_VALID];
  r_pipeline_3_en[4] <= XbarOutBypass[`POS_VALID];
  r_pipeline_3_en[5] <= localOut[`POS_VALID];
end

// Mux the correct data to output link
mux2to1 #(`WIDTH_PORT) mux_out_sel_n ({`WIDTH_PORT{1'b0}}, r_doutN, r_pipeline_3_en[0], doutN);
mux2to1 #(`WIDTH_PORT) mux_out_sel_e ({`WIDTH_PORT{1'b0}}, r_doutE, r_pipeline_3_en[1], doutE);
mux2to1 #(`WIDTH_PORT) mux_out_sel_s ({`WIDTH_PORT{1'b0}}, r_doutS, r_pipeline_3_en[2], doutS);
mux2to1 #(`WIDTH_PORT) mux_out_sel_w ({`WIDTH_PORT{1'b0}}, r_doutW, r_pipeline_3_en[3], doutW);
mux2to1 #(`WIDTH_PORT) mux_out_sel_b ({`WIDTH_PORT{1'b0}}, r_doutBypass, r_pipeline_3_en[4], doutBypass);
mux2to1 #(`WIDTH_PORT) mux_out_sel_l ({`WIDTH_PORT{1'b0}}, r_doutLocal, r_pipeline_3_en[5], doutLocal);
mux2to1 #(`WIDTH_PV) mux_out_sel_pv_bypass ({`WIDTH_PV{1'b0}}, r_pv_bypass, r_pipeline_3_en[4], pv_bypass_out);

endmodule
