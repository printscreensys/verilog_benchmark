module ldpc_decoder_tail_map(
    input [3:0] entry,
    output reg [11:0] q1_index,
    output reg [11:0] q2_index,
    output reg [9:0] l_index,
    output reg [9:0] p_index
);
always @* begin
    q1_index = 12'd0;
    q2_index = 12'd0;
    l_index = 10'd0;
    p_index = 10'd0;
    case (entry)
        4'd0: begin q1_index = 12'd1300; q2_index = 12'd1456; l_index = 10'd515; p_index = 10'd514; end
        4'd1: begin q1_index = 12'd1307; q2_index = 12'd1462; l_index = 10'd516; p_index = 10'd515; end
        4'd2: begin q1_index = 12'd1314; q2_index = 12'd1468; l_index = 10'd517; p_index = 10'd516; end
        4'd3: begin q1_index = 12'd1321; q2_index = 12'd1474; l_index = 10'd518; p_index = 10'd517; end
        4'd4: begin q1_index = 12'd1328; q2_index = 12'd1480; l_index = 10'd519; p_index = 10'd518; end
        4'd5: begin q1_index = 12'd1335; q2_index = 12'd1486; l_index = 10'd520; p_index = 10'd519; end
        4'd6: begin q1_index = 12'd1342; q2_index = 12'd1492; l_index = 10'd521; p_index = 10'd520; end
        4'd7: begin q1_index = 12'd1349; q2_index = 12'd1498; l_index = 10'd522; p_index = 10'd521; end
        4'd8: begin q1_index = 12'd1356; q2_index = 12'd1504; l_index = 10'd523; p_index = 10'd522; end
        4'd9: begin q1_index = 12'd1363; q2_index = 12'd1510; l_index = 10'd524; p_index = 10'd523; end
        default: begin q1_index = 12'd0; q2_index = 12'd0; l_index = 10'd0; p_index = 10'd0; end
    endcase
end
endmodule
