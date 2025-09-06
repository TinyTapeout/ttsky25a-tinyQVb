/*
 * Copyright (c) 2025 Dylan Toussaint, Justin Fok
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/*
 Module fixed_to_fp
 Translates Q=3 F=16 fixed point to IEEE floating point format.
 */
module fixed_to_fp(
    input  wire signed [18:0] fp_in,
    output reg         [31:0] fp_out  
);

  wire        sign;
  wire [18:0] abs_val;

  assign sign    = fp_in[18];           
  assign abs_val = sign ? -fp_in : fp_in;  

  reg  [18:0] tmp;
  reg  [4:0]  count;  
  reg  [4:0]  msb;            
  reg  [7:0]  exp;            
  reg  [22:0] norm;
  reg  [18:0] imm;

  always @* begin

   fp_out = 32'd0;
   tmp    = 19'd0;
   count  = 5'd0;
   msb    = 5'd0;
   exp    = 8'd0;
   norm   = 23'd0;
   imm    = '0;
   
    if (abs_val == 0) begin
      fp_out = {sign, 31'b0}; 
    end else begin
      tmp   = abs_val;
      count = 0;

      if (tmp[18:9] == 10'b0) begin
         count = count + 9;
         tmp = tmp << 9;
      end

      if (tmp[18:14] == 5'b0) begin
         count = count + 5;
         tmp = tmp << 5;
      end

      if (tmp[18:16] == 3'b0) begin
         count = count + 3;
         tmp = tmp << 3;
      end

      if (tmp[18:17] == 2'b0) begin
         count = count + 2;
         tmp = tmp << 2;
      end

      if (tmp[18] == 1'b0) begin
         count = count + 1;
      end

      msb = 5'd18 - count;
      exp = ({3'd0, msb} - 8'd16) + 8'd127;
      
      imm = abs_val << (16 - msb);
      norm = {imm[15:0], 7'b0};

      fp_out = { sign, exp[7:0], norm[22:0] };
    end
  end

endmodule
