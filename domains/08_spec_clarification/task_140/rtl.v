module RsDecodeChien (
   input CLK,
   input RESET,
   input enable,
   input sync,
   input erasureIn,
   input [7:0] lambdaIn_0,
   input [7:0] lambdaIn_1,
   input [7:0] lambdaIn_2,
   input [7:0] lambdaIn_3,
   input [7:0] omegaIn_0,
   input [7:0] omegaIn_1,
   input [7:0] omegaIn_2,
   input [7:0] omegaIn_3,
   input [7:0] epsilonIn_0,
   input [7:0] epsilonIn_1,
   input [7:0] epsilonIn_2,
   input [7:0] epsilonIn_3,
   input [7:0] epsilonIn_4,
   output reg [7:0] errorOut,
   output [4:0] numError,
   output done
);

// Smaller-capability variant:
// lambda(x) limited to degree 3, omega(x) limited to degree 3,
// epsilon(x) limited to degree 4.
localparam integer LAMBDA_TERMS = 4;
localparam integer OMEGA_TERMS = 4;
localparam integer EPSILON_TERMS = 5;

reg [7:0] lambdaSum;
reg [7:0] lambdaEven;
reg [7:0] lambdaOdd;
reg [7:0] lambdaSumReg;
reg [7:0] lambdaEvenReg;
reg [7:0] lambdaEvenReg2;
reg [7:0] lambdaEvenReg3;
reg [7:0] lambdaOddReg;
reg [7:0] lambdaOddReg2;
reg [7:0] lambdaOddReg3;
reg [7:0] denomE0Reg;
reg [7:0] denomE1Reg;
reg [7:0] denomE0InvReg;
reg [7:0] denomE1InvReg;
reg [7:0] omegaSum;
reg [7:0] omegaSumReg;
reg [7:0] numeReg;
reg [7:0] numeReg2;
reg [7:0] epsilonSum;
reg [7:0] epsilonSumReg;
reg [7:0] epsilonOdd;
reg [7:0] epsilonOddReg;
reg [7:0] count;
reg [4:0] numErrorReg;
reg [4:0] numErrorReg2;

reg [7:0] lambdaReg [0:LAMBDA_TERMS-1];
reg [7:0] omegaReg [0:OMEGA_TERMS-1];
reg [7:0] epsilonReg [0:EPSILON_TERMS-1];

wire [7:0] lambdaIn [0:LAMBDA_TERMS-1];
wire [7:0] omegaIn [0:OMEGA_TERMS-1];
wire [7:0] epsilonIn [0:EPSILON_TERMS-1];
wire [7:0] lambdaIni [0:LAMBDA_TERMS-1];
wire [7:0] lambdaNext [0:LAMBDA_TERMS-1];
wire [7:0] omegaIni [0:OMEGA_TERMS-1];
wire [7:0] omegaNext [0:OMEGA_TERMS-1];
wire [7:0] epsilonIni [0:EPSILON_TERMS-1];
wire [7:0] epsilonNext [0:EPSILON_TERMS-1];

wire [7:0] denomE0;
wire [7:0] denomE1;
wire [7:0] denomE0Inv;
wire [7:0] denomE1Inv;
wire [7:0] errorValueE0;
wire [7:0] errorValueE1;
wire doneOrg;

assign {
   lambdaIn[3], lambdaIn[2], lambdaIn[1], lambdaIn[0]
} = {
   lambdaIn_3, lambdaIn_2, lambdaIn_1, lambdaIn_0
};

assign {
   omegaIn[3], omegaIn[2], omegaIn[1], omegaIn[0]
} = {
   omegaIn_3, omegaIn_2, omegaIn_1, omegaIn_0
};

assign {
   epsilonIn[4], epsilonIn[3], epsilonIn[2], epsilonIn[1], epsilonIn[0]
} = {
   epsilonIn_4, epsilonIn_3, epsilonIn_2, epsilonIn_1, epsilonIn_0
};

function [7:0] gfStep;
   input [7:0] value;
   begin
      gfStep = {
         value[6],
         value[5],
         value[4],
         value[3] ^ value[7],
         value[2] ^ value[7],
         value[1] ^ value[7],
         value[0],
         value[7]
      };
   end
endfunction

function [7:0] gfPow;
   input [7:0] value;
   input integer steps;
   integer idx;
   reg [7:0] acc;
   begin
      acc = value;
      for (idx = 0; idx < steps; idx = idx + 1)
         acc = gfStep(acc);
      gfPow = acc;
   end
endfunction

genvar g;
generate
   for (g = 0; g < LAMBDA_TERMS; g = g + 1) begin : gen_lambda
      localparam integer STEP = g;
      assign lambdaIni[g] = gfPow(lambdaIn[g], STEP);
      assign lambdaNext[g] = gfPow(lambdaReg[g], STEP);
      assign omegaIni[g] = gfPow(omegaIn[g], STEP);
      assign omegaNext[g] = gfPow(omegaReg[g], STEP);
   end
   for (g = 0; g < EPSILON_TERMS; g = g + 1) begin : gen_epsilon
      localparam integer STEP = g;
      assign epsilonIni[g] = gfPow(epsilonIn[g], STEP);
      assign epsilonNext[g] = gfPow(epsilonReg[g], STEP);
   end
endgenerate

always @(posedge CLK or negedge RESET) begin
   if (~RESET)
      count <= 8'd0;
   else if (enable) begin
      if (sync)
         count <= 8'd1;
      else if ((count == 8'd0) || (count == 8'd255))
         count <= 8'd0;
      else
         count <= count + 8'd1;
   end
end

assign doneOrg = count == 8'd255;
assign done = doneOrg;

integer lambdaIdx;
always @(posedge CLK or negedge RESET) begin
   if (~RESET) begin
      for (lambdaIdx = 0; lambdaIdx < LAMBDA_TERMS; lambdaIdx = lambdaIdx + 1)
         lambdaReg[lambdaIdx] <= 8'd0;
   end else if (enable) begin
      if (sync) begin
         for (lambdaIdx = 0; lambdaIdx < LAMBDA_TERMS; lambdaIdx = lambdaIdx + 1)
            lambdaReg[lambdaIdx] <= lambdaIni[lambdaIdx];
      end else begin
         for (lambdaIdx = 0; lambdaIdx < LAMBDA_TERMS; lambdaIdx = lambdaIdx + 1)
            lambdaReg[lambdaIdx] <= lambdaNext[lambdaIdx];
      end
   end
end

integer omegaIdx;
always @(posedge CLK or negedge RESET) begin
   if (~RESET) begin
      for (omegaIdx = 0; omegaIdx < OMEGA_TERMS; omegaIdx = omegaIdx + 1)
         omegaReg[omegaIdx] <= 8'd0;
   end else if (enable) begin
      if (sync) begin
         for (omegaIdx = 0; omegaIdx < OMEGA_TERMS; omegaIdx = omegaIdx + 1)
            omegaReg[omegaIdx] <= omegaIni[omegaIdx];
      end else begin
         for (omegaIdx = 0; omegaIdx < OMEGA_TERMS; omegaIdx = omegaIdx + 1)
            omegaReg[omegaIdx] <= omegaNext[omegaIdx];
      end
   end
end

integer epsilonIdx;
always @(posedge CLK or negedge RESET) begin
   if (~RESET) begin
      for (epsilonIdx = 0; epsilonIdx < EPSILON_TERMS; epsilonIdx = epsilonIdx + 1)
         epsilonReg[epsilonIdx] <= 8'd0;
   end else if (enable) begin
      if (sync) begin
         for (epsilonIdx = 0; epsilonIdx < EPSILON_TERMS; epsilonIdx = epsilonIdx + 1)
            epsilonReg[epsilonIdx] <= epsilonIni[epsilonIdx];
      end else begin
         for (epsilonIdx = 0; epsilonIdx < EPSILON_TERMS; epsilonIdx = epsilonIdx + 1)
            epsilonReg[epsilonIdx] <= epsilonNext[epsilonIdx];
      end
   end
end

integer sumIdx;
always @* begin
   lambdaSum = 8'd0;
   lambdaEven = 8'd0;
   lambdaOdd = 8'd0;
   for (sumIdx = 0; sumIdx < LAMBDA_TERMS; sumIdx = sumIdx + 1) begin
      lambdaSum = lambdaSum ^ lambdaReg[sumIdx];
      if (sumIdx[0])
         lambdaOdd = lambdaOdd ^ lambdaReg[sumIdx];
      else
         lambdaEven = lambdaEven ^ lambdaReg[sumIdx];
   end
end

integer omegaSumIdx;
always @* begin
   omegaSum = 8'd0;
   for (omegaSumIdx = 0; omegaSumIdx < OMEGA_TERMS; omegaSumIdx = omegaSumIdx + 1)
      omegaSum = omegaSum ^ omegaReg[omegaSumIdx];
end

integer epsilonSumIdx;
always @* begin
   epsilonSum = 8'd0;
   epsilonOdd = 8'd0;
   for (epsilonSumIdx = 0; epsilonSumIdx < EPSILON_TERMS; epsilonSumIdx = epsilonSumIdx + 1) begin
      epsilonSum = epsilonSum ^ epsilonReg[epsilonSumIdx];
      if (epsilonSumIdx[0])
         epsilonOdd = epsilonOdd ^ epsilonReg[epsilonSumIdx];
   end
end

RsDecodeMult RsDecodeMult_MuldE0 (.A(lambdaOddReg), .B(epsilonSumReg), .P(denomE0));
RsDecodeMult RsDecodeMult_MuldE1 (.A(lambdaSumReg), .B(epsilonOddReg), .P(denomE1));
RsDecodeInv RsDecodeInv_InvE0 (.B(denomE0Reg), .R(denomE0Inv));
RsDecodeInv RsDecodeInv_InvE1 (.B(denomE1Reg), .R(denomE1Inv));
RsDecodeMult RsDecodeMult_MulE0 (.A(numeReg2), .B(denomE0InvReg), .P(errorValueE0));
RsDecodeMult RsDecodeMult_MulE1 (.A(numeReg2), .B(denomE1InvReg), .P(errorValueE1));

always @(posedge CLK or negedge RESET) begin
   if (~RESET) begin
      lambdaSumReg <= 8'd0;
      lambdaEvenReg <= 8'd0;
      lambdaEvenReg2 <= 8'd0;
      lambdaEvenReg3 <= 8'd0;
      lambdaOddReg <= 8'd0;
      lambdaOddReg2 <= 8'd0;
      lambdaOddReg3 <= 8'd0;
      denomE0Reg <= 8'd0;
      denomE1Reg <= 8'd0;
      denomE0InvReg <= 8'd0;
      denomE1InvReg <= 8'd0;
      omegaSumReg <= 8'd0;
      numeReg <= 8'd0;
      numeReg2 <= 8'd0;
      epsilonSumReg <= 8'd0;
      epsilonOddReg <= 8'd0;
   end else if (enable) begin
      lambdaSumReg <= lambdaSum;
      lambdaEvenReg3 <= lambdaEvenReg2;
      lambdaEvenReg2 <= lambdaEvenReg;
      lambdaEvenReg <= lambdaEven;
      lambdaOddReg3 <= lambdaOddReg2;
      lambdaOddReg2 <= lambdaOddReg;
      lambdaOddReg <= lambdaOdd;
      denomE0Reg <= denomE0;
      denomE1Reg <= denomE1;
      denomE0InvReg <= denomE0Inv;
      denomE1InvReg <= denomE1Inv;
      numeReg2 <= numeReg;
      numeReg <= omegaSumReg;
      omegaSumReg <= omegaSum;
      epsilonSumReg <= epsilonSum;
      epsilonOddReg <= epsilonOdd;
   end
end

always @* begin
   if (erasureIn)
      errorOut = errorValueE1;
   else if (lambdaEvenReg3 == lambdaOddReg3)
      errorOut = errorValueE0;
   else
      errorOut = 8'd0;
end

always @(posedge CLK or negedge RESET) begin
   if (~RESET)
      numErrorReg <= 5'd0;
   else if (enable) begin
      if (sync)
         numErrorReg <= 5'd0;
      else if (lambdaEven == lambdaOdd)
         numErrorReg <= numErrorReg + 5'd1;
   end
end

always @(posedge CLK or negedge RESET) begin
   if (~RESET)
      numErrorReg2 <= 5'd0;
   else if (enable && doneOrg) begin
      if (lambdaEven == lambdaOdd)
         numErrorReg2 <= numErrorReg + 5'd1;
      else
         numErrorReg2 <= numErrorReg;
   end
end

assign numError = numErrorReg2;

endmodule
