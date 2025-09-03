`default_nettype none

module freq_synth (
    input wire [31:0] digital_coarse,
    input wire [31:0] digital_fine,
    input wire [31:0] analog_coarse,
    input wire [31:0] analog_fine,
    input wire en_ro,
    input wire rail_coarse,
    input wire rail_fine,
    input wire [4:0] div_p0,
    input wire [4:0] div_p1,
    input wire [4:0] div_p2,
    output wire clk_p0,
    output wire clk_p1,
    output wire clk_p2
);

`ifndef SIM

wire analog_coarse_v_dont_touch;
wire analog_fine_v_dont_touch;
wire clk_ro;
wire [31:0] clk_div;

vdac i_vdc (
    .control(analog_coarse),
    .rail(rail_coarse),
    .vout_tribuf_dont_touch(analog_coarse_v_dont_touch)
);

vdac i_vdf (
    .control(analog_fine),
    .rail(rail_fine),
    .vout_tribuf_dont_touch(analog_fine_v_dont_touch)
);

ring_osc i_ro (
    .digital_coarse(digital_coarse),
    .digital_fine(digital_fine),
    .analog_coarse_dont_touch(analog_coarse_v_dont_touch),
    .analog_fine_dont_touch(analog_fine_v_dont_touch),
    .en(en_ro),
    .clk_out_tribuf(clk_ro)
);

div_pow2 i_div (
    .clk_in(clk_ro),
    .clk_out(clk_div)
);

mux32 i_mp0 (
    .a(clk_div),
    .s(div_p0),
    .x(clk_p0)
);

mux32 i_mp1 (
    .a(clk_div),
    .s(div_p1),
    .x(clk_p1)
);

mux32 i_mp2 (
    .a(clk_div),
    .s(div_p2),
    .x(clk_p2)
);

`else

assign clk_p0 = 1'b0;
assign clk_p1 = 1'b0;
assign clk_p2 = 1'b0;

`endif

endmodule
