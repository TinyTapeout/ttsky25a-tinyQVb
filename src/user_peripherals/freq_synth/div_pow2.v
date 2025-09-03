`default_nettype none

`define DIV_BITS 32

module div_pow2 (
    input wire clk_in,
    output wire [`DIV_BITS-1:0] clk_out
);

`ifndef SIM

assign clk_out[0] = clk_in;

/* verilator lint_off PINMISSING */

genvar i;
generate
    for (i=1; i<`DIV_BITS; i=i+1) begin : g_div

        wire feedback;

        (* keep *)
        sky130_fd_sc_hd__dfxbp_1 i_div (
            .CLK(clk_out[i-1]),
            .D(feedback),
            .Q(clk_out[i]),
            .Q_N(feedback)
        );

    end
endgenerate

/* verilator lint_on PINMISSING */

`else

assign clk_out = {DIV_BITS{1'b0}};

`endif

endmodule
