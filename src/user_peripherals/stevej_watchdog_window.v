/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 41 and change tqvp_example to your chosen module name.
module tqvp_stevej_watchdog_window (
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

    reg [31:0] timer;
    reg [31:0] window_open;
    reg [31:0] window_close;
    reg watchdog_enabled; // has the user enabled the design
    reg saw_pat; // destination is an output pin, driving high means the watchdog was pat and reset.
    wire timer_expired;

    always @(posedge clk) begin
        if (!rst_n) begin
            window_open <= 32'b0;
            window_close <= 32'b0;
            watchdog_enabled <= 1'b0;
            saw_pat <= 1'b0;
            timer <= 32'b0;
        end else begin
            watchdog_enabled <= watchdog_enabled;
            timer <= timer;
            window_open <= window_open;
            window_close <= window_close;
            saw_pat <= saw_pat;

            if (address == 6'h0) begin // Address 0 is ENABLE
                if (data_write_n != 2'b11) begin
                    watchdog_enabled <= data_in[0];
                end
            end else if (address == 6'h1) begin // Address 1 is WINDOW_OPEN
                if (data_write_n != 2'b11) begin
                    if (!watchdog_enabled) window_open <= data_in;
                end
            end else if (address == 6'h2) begin // Address 2 is WINDOW_CLOSE
                if (data_write_n != 2'b11) begin
                    if (!watchdog_enabled) window_close <= data_in;
                end
            end else if (address == 6'h3) begin // Address 3 is PAT
                if (data_write_n != 2'b11) begin
                    // You aren't allowed to reset a watchdog that isn't enabled
                    if (watchdog_enabled) begin
                        saw_pat <= 1'b1;
                        timer <= 32'b0;
                    end
                end
            end

            // timer can only move when the watchdog is on and the timer hasn't expired yet.
            if (watchdog_enabled && !timer_expired) begin
                timer <= timer + 32'b1;
            end

            // Timer should always be 0 unless the watchdog is running.
            // Also reset saw_pat if the watchdog is disabled.
            if (!watchdog_enabled) begin
                saw_pat <= 0;
                timer <= 32'b0;
            end
        end
    end

    wire interrupt_high; // driving high means the window was missed.
    wire interrupt_low; // driving low means the window was missed.

    wire after_window_open;
    assign after_window_open = timer > window_open;

    wire after_window_close;
    assign after_window_close = timer > window_close;

    assign timer_expired = watchdog_enabled && after_window_open && after_window_close;

    assign interrupt_high = timer_expired;
    assign interrupt_low = !timer_expired;
    assign user_interrupt = timer_expired;

    assign uo_out = {interrupt_high, interrupt_low, saw_pat, watchdog_enabled, after_window_open, after_window_close, 2'b00};

    // Addresses for reads are the same as for writes except 0x4
    // 0x0: Enabled
    // 0x1: WINDOW_OPEN
    // 0x2: WINDOW_CLOSE
    // 0x3: PAT
    // 0x4: reflects ui_in
    // Default: 0
    assign data_out = (address == 6'h0) ? {31'h0, watchdog_enabled} :
                      (address == 6'h1) ? window_open :
                      (address == 6'h2) ? window_close :
                      (address == 6'h3) ? {31'h0, saw_pat} :
                      (address == 6'h4) ? {24'h0, ui_in} :
                      32'h0;

    // All reads complete in 1 clock
    assign data_ready = 1;

// In the repo of origin for this peripheral, there is a Github Action
// workflow for checking the formal properties along with a sby config
// and script for testing locally.
//
// https://github.com/stevej/ttsky25a-rv-watchdog
//
`ifdef FORMAL
    logic f_past_valid;

    initial begin
      f_past_valid = 1'b0;
    end

    // Setup `f_past_valid` so later properties can rely
    // on the design being out of reset and initialized.
    always @(posedge clk) begin
        if (!f_past_valid) begin
            assume (!rst_n);
        end

        f_past_valid <= 1'b1;
    end

    always @(posedge clk) begin
        if (f_past_valid) begin
            // A pat can't be registered if the watchdog was not enabled.
            if (saw_pat) begin
                assert($past(watchdog_enabled));
            end

            // the timer shouldn't move once the watchdog is disabled.
            if (!$past(watchdog_enabled)) begin
                assert(timer == 0);
            end

            // the timer can't expire if the window wasn't open.
            if (timer < window_open) begin
                assert(!timer_expired);
            end

            // the timer can only expire if the watchdog is enabled.
            if (timer_expired) begin
                assert (watchdog_enabled);
            end

            // the interrupt can only be pulled high by the timer expiring.
            if (interrupt_high) begin
                assert (timer_expired);
                assert (watchdog_enabled);
            end
        end
     end
`endif // FORMAL


    // List all unused inputs to prevent warnings
    // data_read_n is unused as none of our behaviour depends on whether
    // registers are being read.
    wire _unused = &{data_read_n, 1'b0};

endmodule
