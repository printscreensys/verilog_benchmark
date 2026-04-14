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

    reg [7:0] stored_data;
    reg parity_bit;
    reg parity_error;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stored_data <= 8'h00;
            parity_bit <= 1'b0;
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
                stored_data <= data_in;
                parity_bit <= ^data_in;
            end else if (read_en) begin
                parity_error = ((^stored_data) ^ parity_bit) | inject_single_fault | inject_double_fault;
                data_valid <= 1'b1;

                if (parity_error) begin
                    data_out <= 8'h00;
                    uncorrectable_error <= 1'b1;
                    fault_sticky <= 1'b1;
                end else begin
                    data_out <= stored_data;
                end
            end
        end
    end

endmodule
