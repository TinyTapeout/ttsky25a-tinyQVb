`default_nettype none


// https://tomverbeure.github.io/2019/08/03/Video-Timings-Calculator.html
// https://tomverbeure.github.io/video_timings_calculator?horiz_pixels=1024&vert_pixels=768&refresh_rate=60&margins=false&interlaced=false&bpc=8&color_fmt=rgb444&video_opt=false&custom_hblank=80&custom_vblank=6

module vga_timing_rejunity (
    input wire clk,
    input wire rst_n,
    input wire cli,
    input wire enable_interrupt_on_hblank,
    input wire enable_interrupt_on_vblank,
    input wire narrow_960,
    output reg [10:0] x,
    output reg [ 9:0] y,
    output reg hsync,
    output reg vsync,
    output reg retrace,
    output wire blank,
    output reg interrupt
);

// 1024x768 60Hz CVT (63.5 MHz pixel clock, rounded to 64 MHz) - courtesy of RebelMike

// `define H_ROLL   31
// `define H_FPORCH (32 * 32)
// `define H_SYNC   (33 * 32 + 16)
// `define H_BPORCH (36 * 32 + 24)
// `define H_NEXT   (41 * 32 + 15)

// `define V_ROLL   47
// `define V_FPORCH (16 * 64)
// `define V_SYNC   (16 * 64 + 3)
// `define V_BPORCH (16 * 64 + 7)
// `define V_NEXT   (16 * 64 + 29)

// 1024
//  |          visible           |  blank |-=HSYNC=-|  blank  |
//  |<---------- 1024 ---------->|<--48-->|<--104-->|<--151-->|
//  0                            1024     1072      1176      1327

// 960, additional blanks left&right 32 = (1024-960)/2
//  |     visible    |     blank    |-=HSYNC=-|      blank    |
//  |<----- 960 ---->|<-32-><--48-->|<--104-->|<--151--><-32->|
//  0                960            1040      1144            1327

//`define H_FPORCH 1024
// `define H_SYNC   1072
// `define H_BPORCH 1176
`define H_FPORCH (narrow_960 ?  960 : 1024)
`define H_SYNC   (narrow_960 ? 1040 : 1072)
`define H_BPORCH (narrow_960 ? 1144 : 1176)
`define H_NEXT   1327

`define V_FPORCH 768
`define V_SYNC   771
`define V_BPORCH 775
`define V_NEXT   797 // 803 


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

// always @(posedge clk) begin
//     if (!rst_n) begin
//         x_hi <= 0;
//         x_lo <= 0;
//         y_hi <= 0;
//         y_lo <= 0;
//         hsync <= 0;
//         vsync <= 0;
//         interrupt <= 0;
//     end else begin
//         if ({x_hi, x_lo} == `H_NEXT) begin
//             x_hi <= 0;
//             x_lo <= 0;
//         end else if (x_lo == `H_ROLL) begin
//             x_hi <= x_hi + 1;
//             x_lo <= 0;
//         end else begin
//             x_lo <= x_lo + 1;
//         end
//         if ({x_hi, x_lo} == `H_SYNC) begin
//             if({y_hi, y_lo} == `V_NEXT) begin
//                 y_hi <= 0;
//                 y_lo <= 0;
//                 interrupt <= 1;
//             end else if (y_lo == `V_ROLL) begin
//                 y_hi <= y_hi + 1;
//                 y_lo <= 0;
//             end else begin
//                 y_lo <= y_lo + 1;
//             end
//         end
//         hsync <= !({x_hi, x_lo} >= `H_SYNC && {x_hi, x_lo} < `H_BPORCH);
//         vsync <= ({y_hi, y_lo} >= `V_SYNC && {y_hi, y_lo} < `V_BPORCH);
//         if (cli || {y_hi, y_lo} == 0) begin
//             interrupt <= 0;
//         end
//     end
// end

// assign blank = ({x_hi, x_lo} >= `H_FPORCH || {y_hi, y_lo} >= `V_FPORCH);

endmodule
