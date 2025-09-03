`default_nettype none

module mux32 (
    input wire [31:0] a,
    input wire [4:0] s,
    output wire x
);

`ifndef SIM

wire [7:0] b;
wire [1:0] c;

/* verilator lint_off PINMISSING */

genvar i;
generate

    for (i=0; i<8; i=i+1) begin : g_b

        (* keep *)
        sky130_fd_sc_hd__mux4_1 i_b (
            .A0(a[4*i+0]),
            .A1(a[4*i+1]),
            .A2(a[4*i+2]),
            .A3(a[4*i+3]),
            .S0(s[0]),
            .S1(s[1]),
            .X(b[i])
        );

    end

    for (i=0; i<2; i=i+1) begin : g_c

        (* keep *)
        sky130_fd_sc_hd__mux4_1 i_c (
            .A0(b[4*i+0]),
            .A1(b[4*i+1]),
            .A2(b[4*i+2]),
            .A3(b[4*i+3]),
            .S0(s[2]),
            .S1(s[3]),
            .X(c[i])
        );

    end

endgenerate

(* keep *)
sky130_fd_sc_hd__mux2_1 i_x (
    .A0(c[0]),
    .A1(c[1]),
    .S(s[4]),
    .X(x)
);

/* verilator lint_on PINMISSING */

`else

assign x = 1'b0;

`endif

endmodule
