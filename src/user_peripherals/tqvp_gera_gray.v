/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 38 and change tqvp_example to your chosen module name.
module tqvp_gera_gray_coder (
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
    
    //Address map options
    localparam clear_output = 4'b0000;
    localparam Bin_2_Gray   = 4'b0001;
    localparam Gray_2_Bin   = 4'b0010;
    
    //Internal reg
    reg [7:0] gray_out;
    reg [7:0] bin_out;
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            gray_out <= 0;
            bin_out <= 0;
        end else begin
            if (data_write) begin
                case (address)
                    clear_output: begin
                        gray_out <= 0;
                        bin_out  <= 0;
                    end
                    Bin_2_Gray: begin
                        gray_out [7] <= data_in[7];
                        for (i = 0; i < 7; i = i + 1) begin
                            gray_out [i] <= data_in[i + 1] ^ data_in[i];
                        end
                    end
                    Gray_2_Bin: begin
                        bin_out [7] <= data_in[7];
                        for (i = 6; i >= 0; i = i - 1) begin
                            bin_out[i] = data_in[i] ^ bin_out[i + 1];
                        end
                    end
                    default: begin 
                        gray_out <= 0;
                        bin_out  <= 0;
                    end
                endcase
            end
        end
    end

    //Both output are written pmod and data out

    // All output pins must be assigned. If not used, assign to 0.
    assign uo_out  =  (address == Bin_2_Gray) ? gray_out :
                      (address == Gray_2_Bin) ? bin_out :
                      8'h0;

    assign data_out = (address == Bin_2_Gray) ? gray_out :
                      (address == Gray_2_Bin) ? bin_out :
                      8'h0;    
    // List all unused inputs to prevent warnings
    wire _unused = &{ui_in, 1'b0};

endmodule
