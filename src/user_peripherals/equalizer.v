/*
 * Copyright (c) 2025 Tasmin Khan
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 41 and change tqvp_example to your chosen module name.

module tasmin_eq (
input clk,
input rst_n,
input  [7:0]  ui_in,
output [7:0]  uo_out,

input [5:0]   address,      // Address within this peripheral's address space
input [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

input [1:0] data_write_n,   // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
input [1:0] data_read_n,    // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits

output [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high
output data_ready,
output user_interrupt 
);

// fsm states
reg current_state; // 0 = IDLE, 1 = PROCESSING

//filtercoefficients
localparam signed [15:0] bL0 = 16'sd7;
localparam signed [15:0] bL1 = 16'sd15; 
localparam signed [15:0] bL2 = 16'sd7;
localparam signed [15:0] aL1 = -16'sd31776;
localparam signed [15:0] aL2 = 16'sd15421;

localparam signed [15:0] bM0 = 16'sd7429;
localparam signed [15:0] bM1 = 16'sd0;
localparam signed [15:0] bM2 = -16'sd7429;
localparam signed [15:0] aM1 = -16'sd17256;
localparam signed [15:0] aM2 = 16'sd1525;

localparam signed [15:0] bH0 = 16'sd5505;
localparam signed [15:0] bH1 = -16'sd11010;
localparam signed [15:0] bH2 = 16'sd5505;
localparam signed [15:0] aH1 = -16'sd2743;
localparam signed [15:0] aH2 = 16'sd2892;

//delay registers
reg signed [15:0] x [0:2];    // universal inputs
reg signed [15:0] yout_reg;   // Store final output 
reg signed [15:0] yL [1:2];   // Lowpass reg
reg signed [15:0] yM [1:2];   // Bandpass reg
reg signed [15:0] yH [1:2];   // Highpass reg

// Gain registers
reg [7:0] gL, gM, gH;              
// gL = 255: Unity gain (1.0×)  
// gL = 128: 0.5× (-6dB cut)
// gL = 64:  0.25× (-12dB cut)
// gL = 0:   Mute

//wire declarations
wire signed [15:0] youtL, youtM, youtH, yout;   //wire
wire signed [31:0] sumL, sumM, sumH, sumout;  //wire

// Filter computation (combinational)
assign sumL = bL0*x[0] + bL1*x[1] + bL2*x[2] - aL1*yL[1] - aL2*yL[2];
assign sumM = bM0*x[0] + bM1*x[1] + bM2*x[2] - aM1*yM[1] - aM2*yM[2];
assign sumH = bH0*x[0] + bH1*x[1] + bH2*x[2] - aH1*yH[1] - aH2*yH[2];

assign youtL = sumL[29:14]; 
assign youtM = sumM[29:14]; 
assign youtH = sumH[29:14];

assign sumout = (youtL * gL) + (youtM * gM) + (youtH * gH);
assign yout = sumout[23:8];

// Memory-mapped register interface
// Address Map:
// 0x00: yout_reg  (final combined output from last processing)
// 0x04: Gain/Control register [gH, gM, gL + control bits]
// 0x08: x[0]      (current input sample) - also write address
// 0x0C: yL[1]     (low-pass output from last processing) 
// 0x10: yM[1]     (mid-pass output from last processing)
// 0x14: yH[1]     (high-pass output from last processing) 


always @(posedge clk)
	if (!rst_n) begin
		x[2]  <= 16'h0000; x[1]  <= 16'h0000; x[0]  <= 16'h0000;
		yL[1] <= 16'h0000; yM[1] <= 16'h0000; yH[1] <= 16'h0000;
        yL[2] <= 16'h0000; yM[2] <= 16'h0000; yH[2] <= 16'h0000; 
        yout_reg <= 16'h0000;
        
        gL <= 8'd255;
        gM <= 8'd255;
        gH <= 8'd255;
        
        current_state <= 1'b0;
	end 
	  
	else begin // Handle memory-mapped writes
        if (~(&data_write_n)) begin
            if (address == 6'h08) begin
                x[2]  <= x[1];  x[1]  <= x[0];  x[0]  <= data_in[15:0];
                current_state <= 1'b1; // Go to PROCESSING state on new input write
            end

            else begin
                current_state <= 1'b0; // Not new input, go to IDLE state
                if (address == 6'h04) begin
                    if (data_in[24]) 
                        gL <= data_in[7:0]; 
                    if (data_in[25]) 
                        gM <= data_in[15:8];
                    if (data_in[26]) 
                        gH <= data_in[23:16];
                    if (data_in[28]) begin
                        x[2]  <= 16'h0000; x[1]  <= 16'h0000; x[0]  <= 16'h0000;
                        yL[1] <= 16'h0000; yM[1] <= 16'h0000; yH[1] <= 16'h0000;
                        yL[2] <= 16'h0000; yM[2] <= 16'h0000; yH[2] <= 16'h0000; 
                        yout_reg <= 16'h0000;
                    end
                end
            end  
        end

        else begin
            current_state <= 1'b0; // No write, go to IDLE state
        end

        if(current_state) begin // PROCESSING state
            yL[1] <= youtL; yM[1] <= youtM; yH[1] <= youtH;
            yL[2] <= yL[1]; yM[2] <= yM[1]; yH[2] <= yH[1]; 
            yout_reg <= yout;
        end
    end


assign data_out = (address == 6'h00) ? {{16{yout_reg[15]}}, yout_reg} :  // Sign extend
                  (address == 6'h04) ? {8'h0, gH, gM, gL} :        // Sign extend  
                  (address == 6'h08) ? {{16{x[0][15]}}, x[0]} :        // Sign extend
                  (address == 6'h0C) ? {{16{yL[1][15]}}, yL[1]} :        // Sign extend
                  (address == 6'h10) ? {{16{yM[1][15]}}, yM[1]} :          // Sign extend
                  (address == 6'h14) ? {{16{yH[1][15]}}, yH[1]} : 
                  32'h0;

assign data_ready = 1;
assign user_interrupt = 1'b0;
assign uo_out = 8'h00;
wire _unused = &{ui_in, data_read_n, 1'b0};   //suppress warnings
	  
endmodule
	

