/* verilator lint_off REALCVT */

// FROM General Instruments AY-3-8910 / 8912 Programmable Sound Generator (PSG) data Manual.
// Section 3.7 D/A Converter Operation
// 
// Steps from the diagram: 1V, .707V, .5V, .303V (?), .25V, .1515V (?), .125V .. (not specified) .. 0V

module attenuation #( parameter CONTROL_BITS = 4, parameter VOLUME_BITS = 15 ) (
    input  wire in,
    input  wire [CONTROL_BITS-1:0] control,
    output reg  [VOLUME_BITS-1:0] out
);
    localparam real MAX_VOLUME = (1 << VOLUME_BITS) - 1;
    `define ATLEAST1(i) ($rtoi(i)>1 ? $rtoi(i) : 1)
    always @(*) begin
        case(in ? control : 0)
            // YM2149, numbers from the manual, every 2nd step is taken
            // YM2149 32 steps: 1V, .841, .707, .595, .5, .42, .354, .297, .25, .21, .177, .149, .125
            15: out = `ATLEAST1(MAX_VOLUME * 1.0  );
            14: out = `ATLEAST1(MAX_VOLUME * 0.707);
            13: out = `ATLEAST1(MAX_VOLUME * 0.5  );
            12: out = `ATLEAST1(MAX_VOLUME * 0.354);
            11: out = `ATLEAST1(MAX_VOLUME * 0.25 );
            10: out = `ATLEAST1(MAX_VOLUME * 0.177);   
            9:  out = `ATLEAST1(MAX_VOLUME * 0.125);
            8:  out = `ATLEAST1(MAX_VOLUME * 0.089);
            7:  out = `ATLEAST1(MAX_VOLUME * 0.063);
            6:  out = `ATLEAST1(MAX_VOLUME * 0.045);
            5:  out = `ATLEAST1(MAX_VOLUME * 0.032);
            4:  out = `ATLEAST1(MAX_VOLUME * 0.023);
            3:  out = `ATLEAST1(MAX_VOLUME * 0.016);
            2:  out = `ATLEAST1(MAX_VOLUME * 0.012);
            1:  out = `ATLEAST1(MAX_VOLUME * 0.008);
            0:  out =                        0;
        endcase
        `undef ATLEAST1
    end
endmodule

