`timescale 1ns/1ps

module fifo8_fwft(
    input  wire       clk,
    input  wire       rst_n,     // active-low synchronous reset

    // write side
    input  wire       en,        // write enable
    input  wire [7:0] din,       // data in

    // read side
    input  wire       done,      // consume/advance
    output wire [7:0] dout,      // always shows oldest data

    // optional status
    output reg  [3:0] count
);

    wire empty;
    wire full;
   
    // storage
    reg [7:0] mem [0:7];

    // pointers
    reg [2:0] wptr, rptr;

    // status
    assign empty = (count == 0);
    assign full = (count == 8);
    // continuous assignment: oldest entry is visible
    assign dout = (!empty) ? mem[rptr] : 8'h00;

    // write/read control
    wire do_write = en   && !full;
    wire do_read  = done && !empty;

    always @(posedge clk) begin
        if (!rst_n) begin
            wptr  <= 0;
            rptr  <= 0;
            count <= 0;
        end else begin
            if (do_write) begin
                mem[wptr] <= din;
                wptr <= (wptr == 7) ? 0 : wptr + 1'b1;
            end

            if (do_read) begin
                rptr <= (rptr == 7) ? 0 : rptr + 1'b1;
            end

            case ({do_write, do_read})
                2'b10: count <= count + 1'b1; // write only
                2'b01: count <= count - 1'b1; // read only
                default: count <= count;      // no change / both
            endcase
        end
    end

endmodule
