/*
    Project: TinyTapeStation
    Module: FPGA NES Reciever Module
    Original Author : Ludvig Strigeus
    Adapted by Kwashie Andoh

    Summary: The NES input receiever module takes input from the NES 7-pin output port and
    and inputs the individual button states.

    Description =============================================

*/

module NESTest_Top (

    // system
    input wire system_clk_64MHz, // System clock from TinyQV
    input wire rst_n,             // active low reset

    // controller interface [GPIO]
    input wire NES_Data, // NES controller data -> ui_in[1]
    output wire NES_Latch, // uo_out[1] -> NES controller latch
    output wire NES_Clk, // uo_out[2] -> NES controller clk

    // SNES PMOD interface [3 pins]
    input wire SNES_PMOD_Data,    // PMOD IO7 ->  ui_in[2] 
    input wire SNES_PMOD_Clk,     // PMOD IO6 ->  ui_in[3]
    input wire SNES_PMOD_Latch,   // PMOD IO5 ->  ui_in[4]

    // button states: to data_out[7:0] on address 0x0
    output wire A_out,
    output wire B_out,
    output wire select_out,
    output wire start_out,
    output wire up_out,
    output wire down_out,
    output wire left_out,
    output wire right_out,
    
    // Additional SNES buttons: to data_out[3:0] on address 0x1
    output wire X_out,
    output wire Y_out,
    output wire L_out,
    output wire R_out,
    
    // Status indicator: to data_out[7] on address 0x1
    output wire controller_status  // 1 = SNES active, 0 = NES active

);

    // NES Controller signals
    wire nes_A, nes_B, nes_select, nes_start;
    wire nes_up, nes_down, nes_left, nes_right;

    NES_Reciever nesRec (
        .clk(system_clk_64MHz),
        .reset(~rst_n), // have to invert this since it works on active high
        .data(NES_Data),
        .latch(NES_Latch),
        .nes_clk(NES_Clk),
        .A(nes_A),
        .B(nes_B),
        .select(nes_select),
        .start(nes_start),
        .up(nes_up),
        .down(nes_down),
        .left(nes_left),
        .right(nes_right)
    );

    // SNES Controller signals
    wire snes_A, snes_B, snes_select, snes_start;
    wire snes_up, snes_down, snes_left, snes_right;
    wire snes_X, snes_Y, snes_L, snes_R;
    wire snes_present;  // Auto-detection signal

    // SNES PMOD Interface (using the actual module from the repo)
    gamepad_pmod_single snes_controller (
        .rst_n(rst_n),                 // Active low reset
        .clk(system_clk_64MHz),         // 64MHz clock
        .pmod_data(SNES_PMOD_Data),     // Raw PMOD signals
        .pmod_clk(SNES_PMOD_Clk),
        .pmod_latch(SNES_PMOD_Latch),
        .a(snes_A),                 
        .b(snes_B),
        .x(snes_X),
        .y(snes_Y),
        .select(snes_select),
        .start(snes_start),
        .up(snes_up),
        .down(snes_down),
        .left(snes_left),
        .right(snes_right),
        .l(snes_L),
        .r(snes_R),
        .is_present(snes_present)
    );

    // AUTO-DETECTION MULTIPLEXER
    // If SNES controller is present, use it. Otherwise, fall back to NES.
    assign A_out = snes_present ? snes_A : nes_A;
    assign B_out = snes_present ? snes_B : nes_B;
    assign select_out = snes_present ? snes_select : nes_select;
    assign start_out = snes_present ? snes_start : nes_start;
    assign up_out = snes_present ? snes_up : nes_up;
    assign down_out = snes_present ? snes_down : nes_down;
    assign left_out = snes_present ? snes_left : nes_left;
    assign right_out = snes_present ? snes_right : nes_right;
    
    // SNES-only buttons (only active when SNES is present)
    assign X_out = snes_present ? snes_X : 1'b0;
    assign Y_out = snes_present ? snes_Y : 1'b0;
    assign L_out = snes_present ? snes_L : 1'b0;
    assign R_out = snes_present ? snes_R : 1'b0;
    
    // Status indicator (optional LED to show which controller is active)
    assign controller_status = snes_present;  // 1 = SNES, 0 = NES
    

endmodule


module NES_Reciever (

    input wire clk,
    input wire reset,
    input wire data,   // input data from nes controller to FPGA
    output reg latch,
    output reg nes_clk,  // outputs from FPGA to nes controller
    output wire A,
    output wire B,
    output wire select,
    output wire start,
    output wire up,
    output wire down,
    output wire left,
    output wire right  // output states of nes controller buttons
);

    // Timing constants (pre-computed for 64 MHz). Readjust based on clk freq
    // 64 MHz * 12 us = 768 cycles
    // 64 MHz * 6 us  = 384 cycles
    localparam [10:0] LATCH_CYCLES = 11'd768; 
    localparam [10:0] HALF_CLK_CYC = 11'd384;

    // FSM symbolic states
    localparam [3:0] latch_en = 4'h0;  // assert latch for 12 us
    localparam [3:0] read_A_wait = 4'h1;
    localparam [3:0] read_B = 4'h2;
    localparam [3:0] read_select  = 4'h3;
    localparam [3:0] read_start   = 4'h4;
    localparam [3:0] read_up      = 4'h5;
    localparam [3:0] read_down    = 4'h6;
    localparam [3:0] read_left    = 4'h7;
    localparam [3:0] read_right   = 4'h8;

    // register to count clock cycles to time latch assertion, nes_clk state, and FSM state transitions	 
    reg [10:0] count_reg, count_next;

    // FSM state register, and button state regs
    reg [3:0] state_reg, state_next;
    reg A_reg, B_reg, select_reg, start_reg, up_reg, down_reg, left_reg, right_reg;
    reg A_next, B_next, select_next, start_next, up_next, down_next, left_next, right_next;
    reg latch_next, nes_clk_next;

     // infer all the registers
    always @(posedge clk)

    if (reset) begin
        count_reg  <= 0;
        state_reg  <= 0;
        A_reg      <= 0;
        B_reg      <= 0;
        select_reg <= 0;
        start_reg  <= 0;
        up_reg     <= 0;
        down_reg   <= 0;
        left_reg   <= 0;
        right_reg  <= 0;
        nes_clk    <= 0;
        latch      <= 0;

    end else begin
        count_reg  <= count_next;
        state_reg  <= state_next;
        A_reg      <= A_next;
        B_reg      <= B_next;
        select_reg <= select_next;
        start_reg  <= start_next;
        up_reg     <= up_next;
        down_reg   <= down_next;
        left_reg   <= left_next;
        right_reg  <= right_next;
        nes_clk    <= nes_clk_next;
        latch      <= latch_next;
    end

    // FSM next-state logic and data path
    always @(posedge clk) begin

        // defaults
        count_next  <= count_reg;
        A_next      <= A_reg;
        B_next      <= B_reg;
        select_next <= select_reg;
        start_next  <= start_reg;
        up_next     <= up_reg;
        down_next   <= down_reg;
        left_next   <= left_reg;
        right_next  <= right_reg;
        state_next  <= state_reg;

        case (state_reg)

            latch_en: begin
                // assert latch pin
                latch_next <= 1;
                nes_clk_next <= 0;  // nes_clk state

                // count 12 us
                if (count_reg < LATCH_CYCLES)
                    count_next <= count_reg + 1;

                // once 12 us passed
                else if (count_reg == LATCH_CYCLES) begin
                    latch_next <= 0;  // deassert latch pin
                    count_next <= 0;  // reset latch_count
                    state_next <= read_A_wait;  // go to read_A_wait state
                end
            end

            read_A_wait: begin

                nes_clk_next <= 0;  // nes_clk state

                if (count_reg == 0) begin
                    A_next <= data;  // read A
                end

                if (count_reg < HALF_CLK_CYC)  // count clk cycles for 6 us
                count_next <= count_reg + 1;

                // once 6 us passed
                else if (count_reg == HALF_CLK_CYC) begin
                    count_next <= 0;  // reset latch_count
                    state_next <= read_B;  // go to read_B state
                end
            end

            read_B: begin

                // count clk cycles for 12 us
                if (count_reg < LATCH_CYCLES) begin
                    count_next <= count_reg + 1;
                end

                // nes_clk state
                if (count_reg <= HALF_CLK_CYC)
                    nes_clk_next<= 1;

                else if (count_reg > HALF_CLK_CYC)
                    nes_clk_next <= 0;

                // read B
                if (count_reg == HALF_CLK_CYC)
                    B_next <= data;

                // state over
                if (count_reg == LATCH_CYCLES) begin
                    count_next <= 0;  // reset latch_count
                    state_next <= read_select;  // go to read_select state
                end
            end

            read_select: begin

                // count clk cycles for 12 us
                if (count_reg < LATCH_CYCLES)
                    count_next <= count_reg + 1;

                // nes_clk state
                if (count_reg <= HALF_CLK_CYC)
                    nes_clk_next <= 1;
                else if (count_reg > HALF_CLK_CYC)
                    nes_clk_next <= 0;

                // read select
                if (count_reg == HALF_CLK_CYC)
                    select_next <= data;

                // state over
                if (count_reg == LATCH_CYCLES) begin
                    count_next <= 0;  // reset latch_count
                    state_next <= read_start;  // go to read_start state
                end

            end

            read_start: begin
                // count clk cycles for 12 us
                if (count_reg < LATCH_CYCLES)
                count_next <= count_reg + 1;

                // nes_clk state
                if (count_reg <= HALF_CLK_CYC)
                    nes_clk_next <= 1;
                else if (count_reg > HALF_CLK_CYC)
                    nes_clk_next <= 0;

                // read start
                if (count_reg == HALF_CLK_CYC)
                    start_next <= data;

                // state over
                if (count_reg == LATCH_CYCLES) begin
                    count_next <= 0;  // reset latch_count
                    state_next <= read_up;  // go to read_up state
                end
            end

            read_up: begin
                // count clk cycles for 12 us
                if (count_reg < LATCH_CYCLES)
                    count_next <= count_reg + 1;

                // nes_clk state
                if (count_reg <= HALF_CLK_CYC)
                    nes_clk_next <= 1;
                else if (count_reg > HALF_CLK_CYC)
                    nes_clk_next <= 0;

                // read up
                if (count_reg == HALF_CLK_CYC)
                    up_next <= data;

                // state over
                if (count_reg == LATCH_CYCLES) begin
                    count_next <= 0;  // reset latch_count
                    state_next <= read_down;  // go to read_down state
                end
            end

            read_down: begin
                // count clk cycles for 12 us
                if (count_reg < LATCH_CYCLES)
                    count_next <= count_reg + 1;

                // nes_clk state
                if (count_reg <= HALF_CLK_CYC) begin
                    nes_clk_next <= 1;
                end else if (count_reg > HALF_CLK_CYC) begin
                    nes_clk_next <= 0;
                end

                // read down
                if (count_reg == HALF_CLK_CYC) begin
                    down_next <= data;
                end

                // state over
                if (count_reg == LATCH_CYCLES) begin
                    count_next <= 0;  // reset latch_count
                    state_next <= read_left;  // go to read_left state
                end
            end

            read_left: begin
                // count clk cycles for 12 us
                if (count_reg < LATCH_CYCLES)
                    count_next <= count_reg + 1;

                // nes_clk state
                if (count_reg <= HALF_CLK_CYC) begin
                    nes_clk_next <= 1;
                end else if (count_reg > HALF_CLK_CYC) begin
                    nes_clk_next <= 0;
                end

                // read left
                if (count_reg == HALF_CLK_CYC)
                    left_next <= data;

                // state over
                if (count_reg == LATCH_CYCLES) begin
                    count_next <= 0;  // reset latch_count
                    state_next <= read_right;  // go to read_right state
                end

            end

            read_right: begin
                // count clk cycles for 12 us
                if (count_reg < LATCH_CYCLES) begin
                    count_next <= count_reg + 1;
                end

                // nes_clk state
                if (count_reg <= HALF_CLK_CYC) begin
                    nes_clk_next <= 1;
                end else if (count_reg > HALF_CLK_CYC) begin
                    nes_clk_next <= 0;
                end

                // read right
                if (count_reg == HALF_CLK_CYC)
                    right_next <= data;

                // state over
                if (count_reg == LATCH_CYCLES) begin
                    count_next <= 0;  // reset latch_count
                    state_next <= latch_en;  // go to latch_en state
                end
            end

            default: state_next <= latch_en;  // default state
        endcase
    end

    // assign outputs, *normally asserted when unpressed
    assign A      = ~A_reg;
    assign B      = ~B_reg;
    assign select = ~select_reg;
    assign start  = ~start_reg;
    assign up     = ~up_reg;
    assign down   = ~down_reg;
    assign left   = ~left_reg;
    assign right  = ~right_reg;

endmodule


/*
 * Copyright (c) 2025 Pat Deegan
 * https://psychogenic.com
 * SPDX-License-Identifier: Apache-2.0
 *
 * Interfacing code for the Gamepad Pmod from Psycogenic Technologies,
 * designed for Tiny Tapeout.
 *
 * There are two high-level modules that most users will be interested in:
 * - gamepad_pmod_single: for a single controller;
 * - gamepad_pmod_dual: for two controllers.
 * 
 * There are also two lower-level modules that you can use if you want to
 * handle the interfacing yourself:
 * - gamepad_pmod_driver: interfaces with the Pmod and provides the raw data;
 * - gamepad_pmod_decoder: decodes the raw data into button states.
 *
 * The docs, schematics, PCB files, and firmware code for the Gamepad Pmod
 * are available at https://github.com/psychogenic/gamepad-pmod.
 */

/**
 * gamepad_pmod_driver -- Serial interface for the Gamepad Pmod.
 *
 * This module reads raw data from the Gamepad Pmod *serially*
 * and stores it in a shift register. When the latch signal is received, 
 * the data is transferred into `data_reg` for further processing.
 *
 * Functionality:
 *   - Synchronizes the `pmod_data`, `pmod_clk`, and `pmod_latch` signals 
 *     to the system clock domain.
 *   - Captures serial data on each falling edge of `pmod_clk`.
 *   - Transfers the shifted data into `data_reg` when `pmod_latch` goes low.
 *
 * Parameters:
 *   - `BIT_WIDTH`: Defines the width of `data_reg` (default: 24 bits).
 *
 * Inputs:
 *   - `rst_n`: Active-low reset.
 *   - `clk`: System clock.
 *   - `pmod_data`: Serial data input from the Pmod.
 *   - `pmod_clk`: Serial clock from the Pmod.
 *   - `pmod_latch`: Latch signal indicating the end of data transmission.
 *
 * Outputs:
 *   - `data_reg`: Captured parallel data after shifting is complete.
 */
module gamepad_pmod_driver #(
    parameter BIT_WIDTH = 24
) (
    input wire rst_n,
    input wire clk,
    input wire pmod_data,
    input wire pmod_clk,
    input wire pmod_latch,
    output reg [BIT_WIDTH-1:0] data_reg
);

  reg pmod_clk_prev;
  reg pmod_latch_prev;
  reg [BIT_WIDTH-1:0] shift_reg;

  // Sync Pmod signals to the clk domain:
  reg [1:0] pmod_data_sync;
  reg [1:0] pmod_clk_sync;
  reg [1:0] pmod_latch_sync;

  always @(posedge clk) begin
    if (~rst_n) begin
      pmod_data_sync  <= 2'b0;
      pmod_clk_sync   <= 2'b0;
      pmod_latch_sync <= 2'b0;
    end else begin
      pmod_data_sync  <= {pmod_data_sync[0], pmod_data};
      pmod_clk_sync   <= {pmod_clk_sync[0], pmod_clk};
      pmod_latch_sync <= {pmod_latch_sync[0], pmod_latch};
    end
  end

  always @(posedge clk) begin
    if (~rst_n) begin
      /* set data and shift registers to all ones
       * such that it is detected as "not present" yet.
       */
      data_reg <= {BIT_WIDTH{1'b1}};
      shift_reg <= {BIT_WIDTH{1'b1}};
      pmod_clk_prev <= 1'b0;
      pmod_latch_prev <= 1'b0;
    end
    begin
      pmod_clk_prev   <= pmod_clk_sync[1];
      pmod_latch_prev <= pmod_latch_sync[1];

      // Capture data on rising edge of pmod_latch:
      if (pmod_latch_sync[1] & ~pmod_latch_prev) begin
        data_reg <= shift_reg;
      end

      // Sample data on rising edge of pmod_clk:
      if (pmod_clk_sync[1] & ~pmod_clk_prev) begin
        shift_reg <= {shift_reg[BIT_WIDTH-2:0], pmod_data_sync[1]};
      end
    end
  end

endmodule


/**
 * gamepad_pmod_decoder -- Decodes raw data from the Gamepad Pmod.
 *
 * This module takes a 12-bit parallel data register (`data_reg`) 
 * and decodes it into individual button states. It also determines
 * whether a controller is connected.
 *
 * Functionality:
 *   - If `data_reg` contains all `1's` (`0xFFF`), it indicates that no controller is connected.
 *   - Otherwise, it extracts individual button states from `data_reg`.
 *
 * Inputs:
 *   - `data_reg [11:0]`: Captured button state data from the gamepad.
 *
 * Outputs:
 *   - `b, y, select, start, up, down, left, right, a, x, l, r`: Individual button states (`1` = pressed, `0` = released).
 *   - `is_present`: Indicates whether a controller is connected (`1` = connected, `0` = not connected).
 */
module gamepad_pmod_decoder (
    input wire [11:0] data_reg,
    output wire b,
    output wire y,
    output wire select,
    output wire start,
    output wire up,
    output wire down,
    output wire left,
    output wire right,
    output wire a,
    output wire x,
    output wire l,
    output wire r,
    output wire is_present
);

  // When the controller is not connected, the data register will be all 1's
  wire reg_empty = (data_reg == 12'hfff);
  assign is_present = reg_empty ? 0 : 1'b1;

  // Fix issue with PMOD: irregular/unreliable data for every other latch cycle
  wire [11:0] button_data = reg_empty ? 12'b0 : data_reg;
  
  // Count number of pressed buttons (count 1's in button_data)
  wire [3:0] button_count = {3'b0, button_data[0]} + {3'b0, button_data[1]} + {3'b0, button_data[2]} +
                            {3'b0, button_data[3]} + {3'b0, button_data[4]} + {3'b0, button_data[5]} +
                            {3'b0, button_data[6]} + {3'b0, button_data[7]} + {3'b0, button_data[8]} +
                            {3'b0, button_data[9]} + {3'b0, button_data[10]} + {3'b0, button_data[11]};
  
  // If more than X buttons pressed, output all unpressed (adjust threshold as needed)
  wire too_many_buttons = (button_count > 4'd2);  // More than 2 buttons = suspicious
  
  // Output all zeros if too many buttons, otherwise use actual data
  wire [11:0] filtered_data = too_many_buttons ? 12'b0 : button_data;
  
  assign {b, y, select, start, up, down, left, right, a, x, l, r} = filtered_data;

endmodule


/**
 * gamepad_pmod_single -- Main interface for a single Gamepad Pmod controller.
 * 
 * This module provides button states for a **single controller**, reducing 
 * resource usage (fewer flip-flops) compared to a dual-controller version.
 * 
 * Inputs:
 *   - `pmod_data`, `pmod_clk`, and `pmod_latch` are the signals from the PMOD interface.
 * 
 * Outputs:
 *   - Each button's state is provided as a single-bit wire (e.g., `start`, `up`, etc.).
 *   - `is_present` indicates whether the controller is connected (`1` = connected, `0` = not detected).
 */
module gamepad_pmod_single (
    input wire rst_n,
    input wire clk,
    input wire pmod_data,
    input wire pmod_clk,
    input wire pmod_latch,

    output wire b,
    output wire y,
    output wire select,
    output wire start,
    output wire up,
    output wire down,
    output wire left,
    output wire right,
    output wire a,
    output wire x,
    output wire l,
    output wire r,
    output wire is_present
);

  wire [11:0] gamepad_pmod_data;

  gamepad_pmod_driver #(
      .BIT_WIDTH(12)
  ) driver (
      .rst_n(rst_n),
      .clk(clk),
      .pmod_data(pmod_data),
      .pmod_clk(pmod_clk),
      .pmod_latch(pmod_latch),
      .data_reg(gamepad_pmod_data)
  );

  gamepad_pmod_decoder decoder (
      .data_reg(gamepad_pmod_data),
      .b(b),
      .y(y),
      .select(select),
      .start(start),
      .up(up),
      .down(down),
      .left(left),
      .right(right),
      .a(a),
      .x(x),
      .l(l),
      .r(r),
      .is_present(is_present)
  );

endmodule