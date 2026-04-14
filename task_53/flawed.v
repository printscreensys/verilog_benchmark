module mbist_ram_wrapper (
    input wire clk,
    input wire rst_n,
    input wire func_we,
    input wire [1:0] func_addr,
    input wire [7:0] func_wdata,
    output wire [7:0] func_rdata,
    input wire mbist_en,
    input wire mbist_start,
    output wire mbist_busy,
    output reg mbist_done,
    output reg mbist_fail
);

    reg [7:0] mem [0:3];
    reg mbist_active;
    reg [2:0] mbist_phase;
    integer idx;

    function [7:0] mbist_pattern;
        input [1:0] addr;
        begin
            mbist_pattern = 8'hA0 | {6'b0, addr};
        end
    endfunction

    assign func_rdata = mem[func_addr];
    assign mbist_busy = mbist_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (idx = 0; idx < 4; idx = idx + 1) begin
                mem[idx] <= 8'h00;
            end
            mbist_active <= 1'b0;
            mbist_phase <= 3'd0;
            mbist_done <= 1'b0;
            mbist_fail <= 1'b0;
        end else begin
            mbist_done <= 1'b0;

            if (!mbist_en) begin
                mbist_active <= 1'b0;
                mbist_phase <= 3'd0;
                mbist_fail <= 1'b0;
                if (func_we) begin
                    mem[func_addr] <= func_wdata;
                end
            end else if (!mbist_active) begin
                if (mbist_start) begin
                    mbist_active <= 1'b1;
                    mbist_phase <= 3'd0;
                    mbist_fail <= 1'b0;
                end
            end else begin
                if (mbist_phase < 3'd4) begin
                    mem[mbist_phase[1:0]] <= mbist_pattern(mbist_phase[1:0]);
                end else if (mem[mbist_phase[1:0] - 2'd0] !== mbist_pattern(mbist_phase[1:0] - 2'd0)) begin
                    mbist_fail <= 1'b1;
                end

                // INTENTIONAL FLAW: functional writes are still allowed during MBIST.
                if (func_we) begin
                    mem[func_addr] <= func_wdata;
                end

                if (mbist_phase == 3'd7) begin
                    mbist_active <= 1'b0;
                    mbist_done <= 1'b1;
                end else begin
                    mbist_phase <= mbist_phase + 1'b1;
                end
            end
        end
    end

endmodule
