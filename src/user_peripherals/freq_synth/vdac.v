`default_nettype none

`define VDAC_BITS 32

module vdac (
    input wire [`VDAC_BITS-1:0] control,
    input wire rail,
    output wire vout_tribuf_dont_touch
);

`ifndef SIM
wire [`VDAC_BITS-1:0] control_n;

/* verilator lint_off PINMISSING */

genvar i;
generate
    for (i=0; i<`VDAC_BITS; i=i+1) begin : g_bits

        (* keep *)
        sky130_fd_sc_hd__einvn_0 i_pupd (
            .A(rail),
            .Z(vout_tribuf_dont_touch),
            .TE_B(control[i])
        );

        (* keep *)
        sky130_fd_sc_hd__inv_1 i_cn (
            .A(control[i]),
            .Y(control_n[i])
        );

        (* keep *)
        sky130_fd_sc_hd__einvn_0 i_vref (
            .A(vout_tribuf_dont_touch),
            .Z(vout_tribuf_dont_touch),
            .TE_B(control_n[i])
        );

    end
endgenerate

/* verilator lint_on PINMISSING */

`else

assign vout_tribuf_dont_touch = 1'b0;

`endif

endmodule
