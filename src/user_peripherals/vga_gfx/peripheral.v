/*
 * Copyright (c) 2025 Michael Bell
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tqvp_rebelmike_vga_gfx (
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

    wire [10:0] vga_x;
    wire [4:0] vga_y_hi;
    wire [5:0] vga_y_lo;
    wire       vga_blank;
    wire       vga_hsync;
    wire       vga_vsync;

    vga_timing_gfx i_timing (
        .clk(clk),
        .rst_n(rst_n),

        .x(vga_x),
        .y_hi(vga_y_hi),
        .y_lo(vga_y_lo),

        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .blank(vga_blank)
    );

    // Latch driving.
    // The scheme is to write to the latch using a one clock long wen
    // 0.5 to 1.5 clocks after the write command.
    // This means the bottom 8 bits of data_in must be registered,
    // but the top 24 bits can be assumed not to have changed.
    // The address is stable for 7 clocks after the write command.
    reg wen_p;
    reg wen;
    reg [7:0] data_in_r;
    wire is_write_txn = data_write_n != 2'b11;
    wire is_read_txn = data_read_n != 2'b11;

    always @(posedge clk) begin
        wen_p <= is_write_txn;
        if (is_write_txn) data_in_r <= data_in[7:0];
    end

    always @(negedge clk) begin
        wen <= wen_p;
    end

    // 64 bytes of latched pixel data
    wire [31:0] pixel_data [0:15];
    genvar i;
    generate
        for (i = 0; i < 16; i = i+1) begin : gen_pixel_data
            vga_latch_config i_pixel_data(
                .clk(clk),
                .wen(wen && (address[5:2] == i) && address[1:0] == 2'b00),
                .data_in({data_in[31:8], data_in_r}),
                .data_out(pixel_data[i])
            );
        end
    endgenerate

    // Colour configuration
    wire [5:0] colour [0:3];
    assign colour[0] = 6'h0;
    generate
        for (i = 1; i < 4; i = i+1) begin : gen_colour_config
            vga_latch_config #(.WIDTH(6)) i_colour(
                .clk(clk),
                .wen(wen && (address == i+4)),
                .data_in(data_in_r[5:0]),
                .data_out(colour[i])
            );
        end
    endgenerate

    // Interrupt configuration
    wire [3:0] interrupt_y_mask;
    wire [1:0] interrupt_x_offset;
    vga_latch_config #(.WIDTH(6)) i_interrupt_cfg(
        .clk(clk),
        .wen(wen && (address == 6'h1)),
        .data_in(data_in_r[5:0]),
        .data_out({interrupt_x_offset, interrupt_y_mask})
    );

    // Interrupt generation
    reg interrupt;
    reg interrupt_lock;
    always @(posedge clk) begin
        if (!rst_n) begin
            interrupt <= 0;
            interrupt_lock <= 0;
        end else begin
            if (wen && (address == 6'h1)) interrupt_lock <= 1;
            if (is_read_txn && address == 6'h1) begin
                interrupt <= 0;
            end else if (interrupt_lock && ((vga_y_lo[3:0] | interrupt_y_mask) == 4'hf)) begin
                if (vga_x == {interrupt_x_offset == 2'b00, interrupt_x_offset, 8'h0}) begin
                    interrupt <= 1;
                end
            end
        end
    end

    assign user_interrupt = interrupt;

    // Colour output
    reg [1:0] idx_out;
    wire [5:0] colour_out;
    always @(posedge clk) begin
        idx_out <= vga_blank ? 2'h0 : pixel_data[vga_x[9:6]][{vga_x[5:2], 1'b0} +: 2];
    end

    assign colour_out = colour[idx_out];

    // Connect outputs
    assign uo_out = {vga_hsync, colour_out[0], colour_out[2], colour_out[4],
                     vga_vsync, colour_out[1], colour_out[3], colour_out[5]};

    // Data output
    assign data_ready = 1'b1;
    assign data_out = (address[1:0] == 2'b00) ? pixel_data[address[5:2]] :
                      (address == 6'h1) ? {26'h0, interrupt_x_offset, interrupt_y_mask} :
                      (address == 6'h2) ? {18'h0, vga_y_hi, 3'h0, vga_y_lo} :
                      (address == 6'h3) ? {26'h0, vga_y_hi} :
                      (address == 6'h5) ? {26'h0, colour[1]} :
                      (address == 6'h6) ? {26'h0, colour[2]} :
                      (address == 6'h7) ? {26'h0, colour[3]} :
                      32'h0;

    // List all unused inputs to prevent warnings
    // data_read_n is unused as none of our behaviour depends on whether
    // registers are being read.
    wire _unused = &{ui_in, data_out, 1'b0};

endmodule
