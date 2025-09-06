/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 38 and change tqvp_example to your chosen module name.
module tqvp_rejunity_ay8913 (
    input         clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input         rst_n,        // Reset_n - low to reset.

    input  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock, note this will introduce 2 cycles of delay on the inputs.

    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input [3:0]   address,      // Address within this peripheral's address space

    input         data_write,   // Data write request from the TinyQV core.
    input [7:0]   data_in,      // Data in to the peripheral, valid when data_write is high.
    
    output [7:0]  data_out      // Data out from the peripheral, set this in accordance with the supplied address
);

    wire pwm_out;
    ay8913 ay8913(
        .clk,
        .rst_n,
        .write(data_write),
        .latched_register(address),
        .data(data_in),
        // .master_clock_control(master_clock_control),
        .master_clock_control(2'b10),
        // .master_out(data_out),
        .pwm_out(pwm_out)
    );

    // reg [1:0] master_clock_control;
    // always @(posedge clk) begin
    //     if (!rst_n) begin
    //         master_clock_control <= 2'b10; // default: div 256 for 64 MHz
    //     end else begin
    //         if (address == 4'hF) begin
    //             if (data_write) master_clock_control <= data_in[1:0];
    //         end
    //     end
    // end

    assign data_out = 0;
    assign uo_out = {8{pwm_out}};

endmodule
