/*
 * Copyright (c) 2025 Dylan Toussaint, Justin Fok
 * SPDX-License-Identifier: Apache-2.0
 */

 `default_nettype none

 /*
 Module cordic_stage
 Performs a single cordic rotation.
 */

module cordic_stage (
    input  wire signed [18:0] x_in,
    input  wire signed [18:0] y_in,
    input  wire signed [18:0] z_in,
    input  wire signed [18:0] atan,
    input  wire        [3:0]  stage,
    output wire signed [18:0] x_out,
    output wire signed [18:0] y_out,
    output wire signed [18:0] z_out
);
		
    wire signed [18:0] x_shift, y_shift;
    
    assign x_shift = x_in >>> stage;
    assign y_shift = y_in >>> stage;

    assign x_out = z_in[18] ? (x_in + y_shift) : (x_in - y_shift);
    assign y_out = z_in[18] ? (y_in - x_shift) : (y_in + x_shift);
    assign z_out = z_in + (z_in[18] ? atan : -atan);

endmodule