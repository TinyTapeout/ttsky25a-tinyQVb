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
    reg [7:0] bin_reg;
    reg [7:0] gray_reg;
    reg [3:0] out_flag;
    
    integer i;
    
    //Output wires
    wire [7:0] bin_out;
    wire [7:0] gray_out;

    always @(posedge clk) begin
        if (!rst_n) begin
            bin_reg <= 0;
            gray_reg <= 0;
            out_flag <= 0;
        end else begin
            if (data_write) begin
                case (address)
                    clear_output: begin
                        gray_reg <= 0;
                        bin_reg <= 0;
                        out_flag <= 0;
                    end
                    Bin_2_Gray: begin
                        gray_reg <= data_in;
                        out_flag <= Bin_2_Gray;
                    end
                    Gray_2_Bin: begin
                        bin_reg <= data_in;
                        out_flag <= Gray_2_Bin;
                    end

                    default: begin 
                        gray_reg <= 0;
                        bin_reg <= 0;
                    end
                endcase
            end
        end
    end

//Binary to Gray Encoder block
  genvar k;
  generate
    assign gray_out [7] = gray_reg[7];
        for (k = 0; k < 7; k = k + 1) begin
            assign gray_out[k] = gray_reg[k] ^ gray_reg[k + 1];
        end
  endgenerate

// Gray to Binary Decoder block:
  genvar j;
  generate
    assign bin_out [7] = bin_reg[7];
        for (j = 6; j >= 0; j = j - 1) begin
            assign bin_out[j] = bin_reg[j] ^ bin_out[j + 1];
        end
  endgenerate


    //Both output are written pmod and data out

    // All output pins must be assigned. If not used, assign to 0.
    assign uo_out  =  (out_flag == Bin_2_Gray) ? gray_out :
                      (out_flag == Gray_2_Bin) ? bin_out :
                      8'h0;

    assign data_out = (out_flag == Bin_2_Gray) ? gray_out :
                      (out_flag == Gray_2_Bin) ? bin_out :
                      8'h0;    
    // List all unused inputs to prevent warnings
    wire _unused = &{ui_in, 1'b0};

endmodule
