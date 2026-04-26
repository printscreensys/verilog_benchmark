module mor1kx_dmmu_way_select #(
    parameter OPTION_DMMU_WAYS = 4
)(
    input [OPTION_DMMU_WAYS-1:0] way_huge,
    input [OPTION_DMMU_WAYS-1:0] way_huge_hit,
    input [OPTION_DMMU_WAYS-1:0] way_hit,
    input [95:0] dtlb_trans_huge_flat,
    input [127:0] dtlb_trans_flat,
    input [23:0] virt_addr_low24,
    input [12:0] virt_addr_low13,
    input [1:0] spr_way_idx,
    input dtlb_match_reload_we,
    input dtlb_trans_reload_we,
    input dtlb_match_spr_cs,
    input dtlb_trans_spr_cs,
    input spr_bus_we_i,
    input tlb_reload_pagefault,
    output reg tlb_miss_o,
    output reg [31:0] phys_addr_o,
    output reg ure, uwe, sre, swe,
    output reg cache_inhibit_o,
    output reg [OPTION_DMMU_WAYS-1:0] dtlb_match_we,
    output reg [OPTION_DMMU_WAYS-1:0] dtlb_trans_we
);
integer j;
reg [23:0] huge_word;
reg [31:0] trans_word;
always @(*) begin
   tlb_miss_o = !tlb_reload_pagefault;
   phys_addr_o = {8'h00, virt_addr_low24};
   ure = 0;
   uwe = 0;
   sre = 0;
   swe = 0;
   cache_inhibit_o = 0;
   dtlb_match_we = 0;
   dtlb_trans_we = 0;

   for (j = 0; j < OPTION_DMMU_WAYS; j=j+1) begin
      huge_word = dtlb_trans_huge_flat[j*24 +: 24];
      trans_word = dtlb_trans_flat[j*32 +: 32];
      if (way_huge[j] & way_huge_hit[j] | !way_huge[j] & way_hit[j])
         tlb_miss_o = 0;

      if (way_huge[j] & way_huge_hit[j]) begin
         phys_addr_o = {huge_word[23:16], virt_addr_low24};
         ure = huge_word[6];
         uwe = huge_word[7];
         sre = huge_word[8];
         swe = huge_word[9];
         cache_inhibit_o = huge_word[1];
      end else if (!way_huge[j] & way_hit[j])begin
         phys_addr_o = {trans_word[31:13], virt_addr_low13};
         ure = trans_word[6];
         uwe = trans_word[7];
         sre = trans_word[8];
         swe = trans_word[9];
         cache_inhibit_o = trans_word[1];
      end

      dtlb_match_we[j] = 0;
      if (dtlb_match_reload_we)
        dtlb_match_we[j] = 1;
      if (j[1:0] == spr_way_idx)
        dtlb_match_we[j] = dtlb_match_spr_cs & spr_bus_we_i;

      dtlb_trans_we[j] = 0;
      if (dtlb_trans_reload_we)
        dtlb_trans_we[j] = 1;
      if (j[1:0] == spr_way_idx)
        dtlb_trans_we[j] = dtlb_trans_spr_cs & spr_bus_we_i;
   end
end
endmodule
