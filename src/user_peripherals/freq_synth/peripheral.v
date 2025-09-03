/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 41 and change tqvp_example to your chosen module name.
module tqvp_htfab_freq_synth (
    input         clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input         rst_n,        // Reset_n - low to reset.

    input  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock, note this will introduce 2 cycles of delay on the inputs.

    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input [5:0]   address,      // Address within this peripheral's address space
    input [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    
    output [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output        data_ready,

    output        user_interrupt  // Dedicated interrupt request for this peripheral
);

reg [31:0] digital_coarse;
reg [31:0] digital_fine;
reg [31:0] analog_coarse;
reg [31:0] analog_fine;
reg en_ro;
reg en_interrupt;
reg rail_coarse;
reg rail_fine;
reg [4:0] div_out;
reg [4:0] div_counter;
reg [4:0] div_interrupt;
wire clk_out;
wire clk_counter;
wire clk_interrupt;

freq_synth i_fs (
    .digital_coarse,
    .digital_fine,
    .analog_coarse,
    .analog_fine,
    .en_ro,
    .rail_coarse,
    .rail_fine,
    .div_p0(div_out),
    .div_p1(div_counter),
    .div_p2(div_interrupt),
    .clk_p0(clk_out),
    .clk_p1(clk_counter),
    .clk_p2(clk_interrupt)
);

always @(posedge clk) begin
    if (!rst_n) begin
        digital_coarse <= {~16'b0, 16'b0};
        digital_fine[31:0] <= {~16'b0, 16'b0};
        analog_coarse[31:0] <= 32'b0;
        analog_fine[31:0] <= 32'b0;
        rail_coarse <= 1'b0;
        rail_fine <= 1'b0;
        en_ro <= 1'b0;
        en_interrupt <= 1'b0;
        div_out <= 5'd31;
        div_counter <= 5'd15;
        div_interrupt <= 5'd31;
    end else if (data_write_n == 2'b10) begin
        case (address[5:2])
            4'd0: digital_coarse <= data_in;
            4'd1: digital_fine <= data_in;
            4'd2: analog_coarse <= data_in;
            4'd3: analog_fine <= data_in;
            4'd4: {rail_fine, rail_coarse, en_interrupt, en_ro} <= data_in[3:0];
            4'd5: div_out <= data_in[4:0];
            4'd6: div_counter <= data_in[4:0];
            4'd7: div_interrupt <= data_in[4:0];
            default: ;
        endcase
    end
end

reg last_clk_counter;
reg last_clk_interrupt;

reg [31:0] counter;
reg interrupt;

always @(posedge clk) begin
    if(!rst_n) begin
        last_clk_counter <= 1'b0;
        last_clk_interrupt <= 1'b0;
        counter <= 32'b0;
        interrupt <= 1'b0;
    end else begin
        if (clk_counter && !last_clk_counter) begin
            counter <= counter + 1;
        end
        if (data_read_n == 2'b10) begin
            interrupt <= 1'b0;
        end else if (en_interrupt && clk_interrupt && !last_clk_interrupt) begin
            interrupt <= 1'b1;
        end
        last_clk_counter <= clk_counter;
        last_clk_interrupt <= clk_interrupt;
    end
end

reg [31:0] readback;

always_comb begin
    if (!rst_n) begin
        readback = 32'b0;
    end else begin
        case (address[5:2])
            4'd0: readback = digital_coarse;
            4'd1: readback = digital_fine;
            4'd2: readback = analog_coarse;
            4'd3: readback = analog_fine;
            4'd4: readback = {28'b0, rail_fine, rail_coarse, en_interrupt, en_ro};
            4'd5: readback = {27'b0, div_out};
            4'd6: readback = {27'b0, div_counter};
            4'd7: readback = {27'b0, div_interrupt};
            4'd8: readback = counter;
            default: readback = 32'b0;
        endcase
    end
end

assign data_out = readback;
assign data_ready = 1'b1;
assign uo_out = {8{clk_out}};
assign user_interrupt = interrupt;

wire _unused = &{ui_in, address[1:0], 1'b0};

endmodule
