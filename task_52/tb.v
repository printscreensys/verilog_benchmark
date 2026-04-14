`timescale 1ns / 1ps

module tb_task_52;

    reg tck;
    reg trst_n;
    reg tms;
    reg tdi;
    reg [7:0] dbg_status;

    wire tdo;
    wire [7:0] dbg_control;

    reg [7:0] dr_readback;
    reg test_failed = 0;

    jtag_tap_debug dut (
        .tck(tck),
        .trst_n(trst_n),
        .tms(tms),
        .tdi(tdi),
        .tdo(tdo),
        .dbg_status(dbg_status),
        .dbg_control(dbg_control)
    );

    task jtag_step;
        input tms_value;
        input tdi_value;
        output tdo_value;
        begin
            tms = tms_value;
            tdi = tdi_value;
            #5 tck = 1'b1;
            #1 tdo_value = tdo;
            #4 tck = 1'b0;
        end
    endtask

    task shift_ir4;
        input [3:0] instruction;
        integer i;
        reg dummy_bit;
        begin
            jtag_step(1'b1, 1'b0, dummy_bit);
            jtag_step(1'b1, 1'b0, dummy_bit);
            jtag_step(1'b0, 1'b0, dummy_bit);
            jtag_step(1'b0, 1'b0, dummy_bit);
            for (i = 0; i < 4; i = i + 1) begin
                jtag_step(i == 3, instruction[i], dummy_bit);
            end
            jtag_step(1'b0, 1'b0, dummy_bit);
        end
    endtask

    task shift_dr8;
        input [7:0] dr_in;
        output [7:0] dr_out;
        integer i;
        reg sampled_bit;
        begin
            jtag_step(1'b1, 1'b0, sampled_bit);
            jtag_step(1'b0, 1'b0, sampled_bit);
            jtag_step(1'b0, 1'b0, sampled_bit);
            for (i = 0; i < 8; i = i + 1) begin
                jtag_step(i == 7, dr_in[i], sampled_bit);
                dr_out[i] = sampled_bit;
            end
            jtag_step(1'b0, 1'b0, sampled_bit);
        end
    endtask

    initial begin
        tck = 0;
        trst_n = 0;
        tms = 1;
        tdi = 0;
        dbg_status = 8'h96;
        dr_readback = 8'h00;

        #12 trst_n = 1;

        // Move from TEST_LOGIC_RESET to RUN_TEST_IDLE.
        jtag_step(1'b0, 1'b0, dr_readback[0]);

        // Test 1: default instruction after reset must be IDCODE.
        shift_dr8(8'h00, dr_readback);
        if (dr_readback !== 8'hA5) begin
            $display("ERROR: IDCODE readback failed. Expected A5, got %h", dr_readback);
            test_failed = 1;
        end
        if (dbg_control !== 8'h00) begin
            $display("ERROR: IDCODE scan unexpectedly modified dbg_control.");
            test_failed = 1;
        end

        // Test 2: program dbg_control through JTAG.
        shift_ir4(4'b0010);
        shift_dr8(8'h3C, dr_readback);
        if (dr_readback !== 8'h00) begin
            $display("ERROR: initial DBG_CTL scan should have shifted out 00, got %h", dr_readback);
            test_failed = 1;
        end
        if (dbg_control !== 8'h3C) begin
            $display("ERROR: DBG_CTL update failed. Expected 3C, got %h", dbg_control);
            test_failed = 1;
        end

        // Test 3: reading DBG_CTL back must return the current register value.
        shift_dr8(8'h3C, dr_readback);
        if (dr_readback !== 8'h3C) begin
            $display("ERROR: DBG_CTL readback failed. Expected 3C, got %h", dr_readback);
            test_failed = 1;
        end
        if (dbg_control !== 8'h3C) begin
            $display("ERROR: DBG_CTL readback corrupted dbg_control.");
            test_failed = 1;
        end

        // Test 4: DBG_STAT must be readable without changing dbg_control.
        shift_ir4(4'b0011);
        shift_dr8(8'h00, dr_readback);
        if (dr_readback !== 8'h96) begin
            $display("ERROR: DBG_STAT readback failed. Expected 96, got %h", dr_readback);
            test_failed = 1;
        end
        if (dbg_control !== 8'h3C) begin
            $display("ERROR: DBG_STAT access unexpectedly modified dbg_control.");
            test_failed = 1;
        end

        #10;
        if (test_failed == 0) begin
            $display("TEST_PASSED");
        end else begin
            $display("TEST_FAILED");
        end
        $finish;
    end

endmodule
