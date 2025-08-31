`default_nettype none

// Modified from htfab's version, https://github.com/htfab/tinyqv-baby-vga

module vga_timing_gfx (
    input wire clk,
    input wire rst_n,
    output reg [10:0] x,
    output reg [4:0] y_hi,
    output reg [5:0] y_lo,
    output reg hsync,
    output reg vsync,
    output wire blank
);

// 1024x768 60Hz DMT (65 MHz pixel clock, used at 64 MHz)

`define H_FPORCH (32 * 32)
`define H_SYNC   (32 * 32 + 24)
`define H_BPORCH (37 * 32)
`define H_NEXT   (41 * 32 + 31)

`define V_ROLL   47
`define V_FPORCH (16 * 64)
`define V_SYNC   (16 * 64 + 3)
`define V_BPORCH (16 * 64 + 9)
`define V_NEXT   (16 * 64 + 37)

always @(posedge clk) begin
    if (!rst_n) begin
        x <= 0;
        y_hi <= 0;
        y_lo <= 0;
        hsync <= 0;
        vsync <= 0;
    end else begin
        if (x == `H_NEXT) begin
            x <= 0;
        end else begin
            x <= x + 1;
        end
        if (x == `H_SYNC) begin
            if({y_hi, y_lo} == `V_NEXT) begin
                y_hi <= 0;
                y_lo <= 0;
            end else if (y_lo == `V_ROLL) begin
                y_hi <= y_hi + 1;
                y_lo <= 0;
            end else begin
                y_lo <= y_lo + 1;
            end
        end
        hsync <= !(x >= `H_SYNC && x < `H_BPORCH);
        vsync <= !({y_hi, y_lo} >= `V_SYNC && {y_hi, y_lo} < `V_BPORCH);
    end
end

assign blank = (x[10] || y_hi[4]);

endmodule