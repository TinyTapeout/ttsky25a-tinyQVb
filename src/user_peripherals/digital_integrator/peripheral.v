/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */
`timescale 1ns / 1ps
`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 38 and change tqvp_example to your chosen module name.
module tqvp_integrator (
    input         clk,          // Clock
    input         rst_n,        // Active-low reset

    input  [7:0]  ui_in,        // Input PMOD
    output [7:0]  uo_out,       // Output PMOD

    input  [3:0]  address,      // Address within this peripheral's address space
    input         data_write,   // Write strobe
    input  [7:0]  data_in,      // Data written
    output [7:0]  data_out      // Data read
);

    // Internal Registers
    reg [7:0] CTRL;         // addr 0x0
    reg [7:0] STATUS;       // addr 0x1 (read-only flags)
    reg [7:0] INPUT_REG;    // addr 0x2
    reg [7:0] THRESH;       // addr 0x5
    reg [7:0] DECAY_SHIFT;  // addr 0x6

    // Wires from Integrator Core
    wire signed [15:0] acc_out;
    wire               overflow_flag;

    // CTRL bit mapping for clarity
    wire enable_core   = CTRL[0];
    wire sample_strobe = CTRL[1];
    wire leaky_mode    = CTRL[2];
    wire sat_enable    = CTRL[3];

    // Integrator Core Instance
    integrator_core #(
        .IN_W(8), .ACC_W(16)
    ) core (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable_core),
        .sample_strobe(sample_strobe),
        .sample_in(INPUT_REG),
        .leaky_mode(leaky_mode),
        .decay_shift(DECAY_SHIFT),
        .sat_enable(sat_enable),
        .sat_pos(16'sh7FFF),
        .sat_neg(-16'h7FFF), // Corrected symmetrical limit
        .acc_out(acc_out),
        .overflow_flag(overflow_flag)
    );

    // Register write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            CTRL        <= 8'h0;
            INPUT_REG   <= 8'h0;
            THRESH      <= 8'h0;
            DECAY_SHIFT <= 8'd4; // Default decay
        end else if (data_write) begin
            case (address)
                4'h0: CTRL        <= data_in;
                4'h2: INPUT_REG   <= data_in;
                4'h5: THRESH      <= data_in;
                4'h6: DECAY_SHIFT <= data_in;
                default: ;
            endcase
        end
    end

    // Status register update (combinatorial)
    always @(*) begin
        STATUS = 8'h0;
        STATUS[0] = overflow_flag;
        STATUS[1] = (acc_out[7:0] > THRESH);
    end

    // Memory-mapped readback
    assign data_out = (address == 4'h0) ? CTRL :
                      (address == 4'h1) ? STATUS :
                      (address == 4'h2) ? INPUT_REG :
                      (address == 4'h3) ? acc_out[7:0] :
                      (address == 4'h4) ? acc_out[15:8] :
                      (address == 4'h5) ? THRESH :
                      (address == 4'h6) ? DECAY_SHIFT :
                      8'h0;

    // Output pins for demo
    assign uo_out = acc_out[7:0];

endmodule
