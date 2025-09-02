`default_nettype none

// an extra "nand" stage is not included
`define NUM_STAGES 8
`define BITS_PER_STAGE 4

module ring_osc (
    input wire [`NUM_STAGES*`BITS_PER_STAGE-1:0] digital_coarse,
    input wire [`NUM_STAGES*`BITS_PER_STAGE-1:0] digital_fine,
    input wire analog_coarse_dont_touch,
    input wire analog_fine_dont_touch,
    input wire en,
    output wire clk_out_tribuf
);

`ifndef SIM

wire [`BITS_PER_STAGE*`NUM_STAGES-1:0] digital_coarse_transposed;
wire [`BITS_PER_STAGE*`NUM_STAGES-1:0] digital_fine_transposed;

transpose_matrix i_tc (
    .input_matrix(digital_coarse),
    .output_matrix(digital_coarse_transposed)
);

transpose_matrix i_tf (
    .input_matrix(digital_fine),
    .output_matrix(digital_fine_transposed)
);

wire [`NUM_STAGES:0] ring;

/* verilator lint_off PINMISSING */

(* keep *)
sky130_fd_sc_hd__nand2_1 i_nand (
    .A(ring[`NUM_STAGES]),
    .B(en),
    .Y(clk_out_tribuf)
);

/* verilator lint_on PINMISSING */

assign ring[0] = clk_out_tribuf;

genvar i;
generate
    for (i=0; i<`NUM_STAGES; i=i+1) begin : g_stage

        ring_osc_stage i_stage (
            .digital_coarse(digital_coarse_transposed[i*`BITS_PER_STAGE +: `BITS_PER_STAGE]),
            .digital_fine(digital_fine_transposed[i*`BITS_PER_STAGE +: `BITS_PER_STAGE]),
            .analog_coarse_dont_touch(analog_coarse_dont_touch),
            .analog_fine_dont_touch(analog_fine_dont_touch),
            .clk_in(ring[i]),
            .clk_out_tribuf(ring[i+1])
        );

    end
endgenerate

`else

assign clk_out_tribuf = 1'b0;

`endif

endmodule
