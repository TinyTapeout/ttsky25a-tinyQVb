`default_nettype none

`define DIGITAL_BITS 4
`define COARSE_MULTIPLIER 4

module ring_osc_stage (
    input wire [`DIGITAL_BITS-1:0] digital_coarse,
    input wire [`DIGITAL_BITS-1:0] digital_fine,
    input wire analog_coarse_dont_touch,
    input wire analog_fine_dont_touch,
    input wire clk_in,
    output wire clk_out_tribuf
);

`ifndef SIM

/* verilator lint_off PINMISSING */

genvar i, j;
generate

    for (i=0; i<`DIGITAL_BITS; i=i+1) begin : g_d

        for (j=0; j<`COARSE_MULTIPLIER; j=j+1) begin : g_dc

            (* keep *)
            sky130_fd_sc_hd__einvn_0 i_dc (
                .A(clk_in),
                .Z(clk_out_tribuf),
                .TE_B(digital_coarse[i])
            );

        end

        (* keep *)
        sky130_fd_sc_hd__einvn_0 i_df (
            .A(clk_in),
            .Z(clk_out_tribuf),
            .TE_B(digital_fine[i])
        );

    end

    for (j=0; j<`COARSE_MULTIPLIER; j=j+1) begin : g_ac

        (* keep *)
        sky130_fd_sc_hd__einvn_0 i_ac (
            .A(clk_in),
            .Z(clk_out_tribuf),
            .TE_B(analog_coarse_dont_touch)
        );

    end

endgenerate

(* keep *)
sky130_fd_sc_hd__einvn_0 i_af (
    .A(clk_in),
    .Z(clk_out_tribuf),
    .TE_B(analog_fine_dont_touch)
);

/* verilator lint_on PINMISSING */

`else

assign clk_out_tribuf = 1'b0;

`endif

endmodule
