module triple_reset_sequencer (
    input wire clk_cpu,
    input wire clk_bus,
    input wire clk_periph,
    input wire arst_n,
    output wire rst_cpu_n,
    output wire rst_bus_n,
    output wire rst_periph_n
);

    reg [1:0] cpu_sync;
    reg [1:0] bus_sync;
    reg [1:0] periph_sync;

    always @(posedge clk_cpu or negedge arst_n) begin
        if (!arst_n) begin
            cpu_sync <= 2'b00;
        end else begin
            cpu_sync <= {cpu_sync[0], 1'b1};
        end
    end

    assign rst_cpu_n = cpu_sync[1];

    always @(posedge clk_bus or negedge arst_n) begin
        if (!arst_n) begin
            bus_sync <= 2'b00;
        end else begin
            bus_sync <= {bus_sync[0], rst_cpu_n};
        end
    end

    assign rst_bus_n = bus_sync[1];

    always @(posedge clk_periph or negedge arst_n) begin
        if (!arst_n) begin
            periph_sync <= 2'b00;
        end else begin
            periph_sync <= {periph_sync[0], rst_bus_n};
        end
    end

    assign rst_periph_n = periph_sync[1];

endmodule
