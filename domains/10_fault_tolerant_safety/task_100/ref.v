module ecc_guarded_byte (
    input wire clk,
    input wire rst_n,
    input wire write_en,
    input wire read_en,
    input wire [7:0] data_in,
    input wire inject_single_fault,
    input wire inject_double_fault,
    output reg [7:0] data_out,
    output reg data_valid,
    output reg correctable_error,
    output reg uncorrectable_error,
    output reg fault_sticky
);

    reg [12:0] stored_code;

    function [12:0] ecc_encode;
        input [7:0] data;
        reg [12:0] code;
        begin
            code = 13'b0;
            code[2] = data[0];
            code[4] = data[1];
            code[5] = data[2];
            code[6] = data[3];
            code[8] = data[4];
            code[9] = data[5];
            code[10] = data[6];
            code[11] = data[7];

            code[0] = code[2] ^ code[4] ^ code[6] ^ code[8] ^ code[10];
            code[1] = code[2] ^ code[5] ^ code[6] ^ code[9] ^ code[10];
            code[3] = code[4] ^ code[5] ^ code[6] ^ code[11];
            code[7] = code[8] ^ code[9] ^ code[10] ^ code[11];
            code[12] = ^code[11:0];
            ecc_encode = code;
        end
    endfunction

    function [3:0] ecc_syndrome;
        input [12:0] code;
        reg [3:0] syn;
        begin
            syn[0] = code[0] ^ code[2] ^ code[4] ^ code[6] ^ code[8] ^ code[10];
            syn[1] = code[1] ^ code[2] ^ code[5] ^ code[6] ^ code[9] ^ code[10];
            syn[2] = code[3] ^ code[4] ^ code[5] ^ code[6] ^ code[11];
            syn[3] = code[7] ^ code[8] ^ code[9] ^ code[10] ^ code[11];
            ecc_syndrome = syn;
        end
    endfunction

    function [7:0] ecc_decode_data;
        input [12:0] code;
        begin
            ecc_decode_data = {
                code[11],
                code[10],
                code[9],
                code[8],
                code[6],
                code[5],
                code[4],
                code[2]
            };
        end
    endfunction

    function [12:0] ecc_flip_bit;
        input [12:0] code;
        input [3:0] syndrome_value;
        reg [12:0] corrected;
        begin
            corrected = code;
            if (syndrome_value != 4'b0000) begin
                corrected[syndrome_value - 1'b1] = ~corrected[syndrome_value - 1'b1];
            end
            ecc_flip_bit = corrected;
        end
    endfunction

    wire [12:0] injected_code;
    wire [3:0] syndrome;
    wire overall_error;
    wire correctable_hit;
    wire uncorrectable_hit;
    wire [12:0] corrected_code;
    wire [7:0] read_data;

    assign injected_code = inject_double_fault ? (stored_code ^ 13'h024) :
                           inject_single_fault ? (stored_code ^ 13'h010) :
                           stored_code;
    assign syndrome = ecc_syndrome(injected_code);
    assign overall_error = ^injected_code;
    assign correctable_hit = overall_error;
    assign uncorrectable_hit = (syndrome != 4'b0000) && !overall_error;
    assign corrected_code = ((syndrome != 4'b0000) && overall_error) ?
        ecc_flip_bit(injected_code, syndrome) : injected_code;
    assign read_data = uncorrectable_hit ? 8'h00 : ecc_decode_data(corrected_code);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stored_code <= ecc_encode(8'h00);
            data_out <= 8'h00;
            data_valid <= 1'b0;
            correctable_error <= 1'b0;
            uncorrectable_error <= 1'b0;
            fault_sticky <= 1'b0;
        end else begin
            data_out <= 8'h00;
            data_valid <= 1'b0;
            correctable_error <= 1'b0;
            uncorrectable_error <= 1'b0;

            if (write_en) begin
                stored_code <= ecc_encode(data_in);
            end else if (read_en) begin
                data_valid <= 1'b1;
                data_out <= read_data;

                if (correctable_hit) begin
                    correctable_error <= 1'b1;
                    fault_sticky <= 1'b1;
                end else if (uncorrectable_hit) begin
                    uncorrectable_error <= 1'b1;
                    fault_sticky <= 1'b1;
                end
            end
        end
    end

endmodule
