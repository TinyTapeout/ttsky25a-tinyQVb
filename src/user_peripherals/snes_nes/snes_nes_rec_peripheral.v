/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 38 and change tqvp_example to your chosen module name.
module tqvp_nes_snes_controller (
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

    wire [7:0] standard_buttons;
    wire [3:0] extra_snes_buttons;
    wire is_snes;

    NESTest_Top nes_snes_module (

        // system
        .system_clk_64MHz(clk), // System clock from TinyQV (64MHz)
        .rst_n(rst_n),         // active low reset

        // NES controller interface [GPIO]. We generate latch and clock internally and send to controller. Data returns.
        .NES_Data(ui_in[1]), // NES controller data -> ui_in[1]
        .NES_Latch(uo_out[6]), // uo_out[6] -> NES controller latch
        .NES_Clk(uo_out[7]), // uo_out[7] -> NES controller clk

        // SNES PMOD interface [3 pins]
        .SNES_PMOD_Data(ui_in[2]),    // PMOD IO7 ->  ui_in[2] 
        .SNES_PMOD_Clk(ui_in[3]),     // PMOD IO6 ->  ui_in[3]
        .SNES_PMOD_Latch(ui_in[4]),   // PMOD IO5 ->  ui_in[4]

        // button states: to data_out[7:0] on address 0x1
        .A_out(standard_buttons[7]),
        .B_out(standard_buttons[6]),
        .select_out(standard_buttons[5]),
        .start_out(standard_buttons[4]),
        .up_out(standard_buttons[3]),
        .down_out(standard_buttons[2]),
        .left_out(standard_buttons[1]),
        .right_out(standard_buttons[0]),
        
        // Additional SNES buttons: to data_out[3:0] on address 0x2
        .X_out(extra_snes_buttons[3]),
        .Y_out(extra_snes_buttons[2]),
        .L_out(extra_snes_buttons[1]),
        .R_out(extra_snes_buttons[0]),
        
        // Status indicator: to data_out[0] on address 0x0
        .controller_status(is_snes)  // 1 = SNES active, 0 = NES active
    );

    // IO connections so far:

    // ui_in
    // NES controller data -> ui_in[1]
    // SNES_PMOD_Data ->  ui_in[2] 
    // SNES_PMOD_Clk ->  ui_in[3]
    // SNES_PMOD_Latch ->  ui_in[4]

    // uo_out
    // uo_out[6] -> NES controller latch
    // uo_out[7] -> NES controller clk

    // All output pins must be assigned. If not used, assign to 0.
    
    reg [7:0] std_btn_reg;
    reg [7:0] ext_btn_reg;
    reg [7:0] status_reg;
    
    reg latch;
    reg n_clk;

    always @(*) begin
        if (is_snes) begin
            n_clk = ui_in[3];
            latch = ui_in[4];
        end else begin
            n_clk = uo_out[7]; // Use NES_Clk signal assigned to uo_out[7]
            latch = uo_out[6]; // Use NES_Latch signal assigned to uo_out[6]
        end
    end
    
        // FSM to detect a sequence: negative edge followed by positive edge on latch signal
        localparam READY = 1'b0;  
        localparam TRIGGER = 1'b1;

        reg latch_prev;
        reg n_clk_prev;
        reg  fsm_state;
        reg enable_button_regs;
        reg [3:0] clk_count;

        always @(posedge clk) begin
            latch_prev <= latch;
            n_clk_prev <= n_clk;
        end

        // capture inputs at the end of frames
        always @(posedge clk) begin
            if (~rst_n) begin
                fsm_state <= READY;
                enable_button_regs <= 0;
              
                if (is_snes) begin
                    clk_count <= 11;
                end else begin
                    clk_count <= 7;
                end

            end else begin
                case (fsm_state)
                    READY:
                    begin
                        if (n_clk_prev &~ n_clk) begin
                            clk_count <= clk_count - 1;
                        end
                        if (clk_count == 0) begin
                            fsm_state <= TRIGGER;
                            enable_button_regs <= 1;
                        end
                    end
                    TRIGGER: begin
                        enable_button_regs <= 0;
                        fsm_state <= READY;
                        if (is_snes) begin
                            clk_count <= 11;
                        end else begin
                            clk_count <= 7;
                        end
                    end
                endcase
            end
        end

    always @(posedge clk ) begin
        if (~rst_n) begin
            std_btn_reg <= 8'b0;
            ext_btn_reg <= 8'b0;
            status_reg <= 8'b0;
        end else begin
            status_reg  <= {7'b0000000, is_snes};
           
            if (enable_button_regs) begin // refresh at the end of a complete cycle
                std_btn_reg <= standard_buttons;
                ext_btn_reg <= {4'b0000, extra_snes_buttons};
            end
        end
    end

    assign uo_out[5:0] = 6'b000000;

    //  BUG: TT-RV-0001 - NO_INVERT
    assign data_out = (address == 4'h0) ? std_btn_reg :
                      (address == 4'h1) ? ext_btn_reg :
                      (address == 4'h2) ? status_reg  :
                      8'h0;

endmodule
