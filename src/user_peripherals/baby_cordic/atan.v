/*
 * Copyright (c) 2025 Dylan Toussaint, Justin Fok
 * SPDX-License-Identifier: Apache-2.0
 */

 /* MODULE atan
    Lookup table, provides necessary atan values for cordic.
 */

module atan(
    input  wire  [3:0]  stage,      
    output reg   [18:0] atan_out
);

  always @* begin
    case(stage)
      4'd0:  begin atan_out = 19'h0C910; end
      4'd1:  begin atan_out = 19'h076B2; end
      4'd2:  begin atan_out = 19'h03EB7; end
      4'd3:  begin atan_out = 19'h01FD6; end
      4'd4:  begin atan_out = 19'h00FFB; end
      4'd5:  begin atan_out = 19'h007FF; end
      4'd6:  begin atan_out = 19'h00400; end
      4'd7:  begin atan_out = 19'h00200; end
      4'd8:  begin atan_out = 19'h00100; end
      4'd9:  begin atan_out = 19'h00080; end
      4'd10: begin atan_out = 19'h00040; end
      4'd11: begin atan_out = 19'h00020; end
      default: begin atan_out = 19'h00000; end
    endcase
  end

endmodule
