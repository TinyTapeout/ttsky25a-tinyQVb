`default_nettype none

// VGA timing for 64 MHz base clock.
//
// This code is based on the previous implementations by RebelMike, hftab and ccattuto,
// as well as informative discussions on TinyTapeout discord channels.

// Graphics mode: 1024x768 60Hz CVT
// 63.5 MHz pixel clock, rounded to 64 MHz
// (courtesy of RebelMike)

// Timing calculations were made with:
//      https://tomverbeure.github.io/2019/08/03/Video-Timings-Calculator.html
// Parameters:
//      horiz_pixels=1024
//      vert_pixels=768
//      refresh_rate=60
//      margins=false
//      interlaced=false
//      bpc=8
//      color_fmt=rgb444
//      video_opt=false
//      custom_hblank=80
//      custom_vblank=6


// NOTES:
// 1) SCREEN WIDTH. Although ~64 MHz clock provides standard 1024 clock / pixel wide screen,
// 1024 wide does not suit lower 320 / 640 pixel resolutions - no simple divisor.
// The closest divisable 960 can be achieved by adding 32 clock borders:
//      (1024 - 960) / 2 = 32 additional border clocks
// thus the optional 'narrow_960' mode.
//
// 2) SCANLINE COUNT. 64 MHz clock is slightly higher than 
// the nominal 63.5 MHz pixel clock mandated by 1024x768 60Hz CVT.
// As a stopgap solution extra scanlines can be added during the vertical blanking period:
//      798 total vertical lines / 63.5 * 64 = 804 total vertical lines
// thus the optional `extra_scanlines_for_64mhz` mode.


module vga_timing (
    input wire clk,
    input wire rst_n,
    input wire cli,
    input wire enable_interrupt_on_hblank,
    input wire enable_interrupt_on_vblank,
    input wire narrow_960,
    input wire extra_vblank_lines_for_64mhz,
    output reg [10:0] x,
    output reg [ 9:0] y,
    output reg hsync,
    output reg vsync,
    output reg retrace,
    output wire blank,
    output reg interrupt
);


// 1024
//  |          visible           |  blank |-=HSYNC=-|  blank  |
//  |<---------- 1024 ---------->|<--48-->|<--104-->|<--151-->|
//  0                            1024     1072      1176      1327

// 960, additional blanks left & right 32 = (1024-960)/2
//  |     visible    |     blank    |-=HSYNC=-|      blank    |
//  |<----- 960 ---->|<-32-><--48-->|<--104-->|<--151--><-32->|
//  0                960            1040      1144            1327

`define H_FPORCH (narrow_960 ?  960 : 1024)
`define H_SYNC   (narrow_960 ? 1040 : 1072)
`define H_BPORCH (narrow_960 ? 1144 : 1176)
`define H_NEXT   1327

`define V_FPORCH 768
`define V_SYNC   771
`define V_BPORCH 775
`define V_NEXT   (extra_vblank_lines_for_64mhz ? 803 : 797)

always @(posedge clk) begin
    if (!rst_n) begin
        x <= 0;
        y <= 0;
        hsync <= 0;
        vsync <= 0;
        interrupt <= 0;
        retrace <= 0;
    end else begin
        if (x == `H_NEXT) begin
            x <= 0;
        end else begin
            x <= x + 1;
        end
        retrace <= 0;
        if (x == `H_SYNC) begin
            if (y == `V_NEXT) begin
                y <= 0;
            end else begin
                y <= y + 1;
                retrace <= 1;
            end
        end
        hsync <= !(x >= `H_SYNC && x < `H_BPORCH);
        vsync <=  (y >= `V_SYNC && y < `V_BPORCH);
        if ((y == `V_FPORCH && enable_interrupt_on_vblank) ||
            (x == `H_FPORCH && enable_interrupt_on_hblank)) begin
            interrupt <= 1;
        end
        if (cli || !blank) begin
            interrupt <= 0;
        end
    end
end

assign blank = (x >= `H_FPORCH || y >= `V_FPORCH);

endmodule
