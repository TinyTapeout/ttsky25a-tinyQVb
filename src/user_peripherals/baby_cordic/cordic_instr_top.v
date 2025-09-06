/*
 * Copyright (c) 2025 Dylan Toussaint, Justin Fok
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/*
 Module cordic_instr_top
 Puts it all together. FP -> FIXED -> Cordic Rotations -> FIXED -> FP
 */
module cordic_instr_top(
	input  wire [31:0] dataa,
	input  wire        clk,
	input  wire        clk_en,
	input  wire        reset,
	input  wire        start,
	input  wire	       cos,
	output reg         done,
	output reg  [31:0] result,
	output reg         input_invalid_flag
);	
	
	wire [18:0] fp_in;
	wire [18:0] fp_out;
	wire [31:0] temp_out;
	
	wire        cordic_done;
	reg         delay;

	fp_to_fixed fp_to_fixed_inst ( 
		.fp_in                (dataa),              //Input floating point
		.fp_out               (fp_in),              //Output fixed point
		.fp_input_invalid_flag(input_invalid_flag)  //Flag for invalid input.
	);

	cordic cordic_inst (
		.clk(clk),
		.clk_en(clk_en),
		.rst(reset),
		.start(start),
		.theta(fp_in),
		.cos(cos),
		.cos_o(fp_out),
		.done(cordic_done)
	);
	
	fixed_to_fp fixed_to_fp_inst (
		.fp_in(fp_out),
		.fp_out(temp_out)
	);
	
	
	//Align expected done signal with that of cordic_inst impl.
	//Buffer output until next done signal
	always @(posedge clk) begin
		if(reset) begin
			result <= 32'd0;
			done   <= 1'b0;
			delay  <= 1'b0;
		end else if (clk_en) begin
			delay <= cordic_done;
			done  <= delay;
			
			if(cordic_done) begin
				result <= temp_out;
			end
		end
	end
	


endmodule
