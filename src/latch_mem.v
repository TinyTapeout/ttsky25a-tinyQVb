/*
 * Copyright (c) 2025 Michael Bell
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module latch_mem #(
    parameter RAM_BYTES = 32,
    parameter ADDR_BITS = 5
) (
    input         clk,
    input         rstn,

    input [ADDR_BITS-1:0]   addr_in,   // Address within the RAM
    input [31:0]  data_in,             // Data in to the RAM, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    
    output reg [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output reg  data_ready
);

    wire [RAM_BYTES - 1:0] wen;
    wire [7:0] latch_data_in;
    wire [7:0] latch_data_out[RAM_BYTES - 1:0];

    genvar i;
    generate
    for (i = 0; i < RAM_BYTES; i = i+1) begin
        latch_reg_n #(.WIDTH(8)) l_ram (clk, wen[i], latch_data_in, latch_data_out[i]);
    end
    endgenerate

    reg [1:0] cycle;
    wire [ADDR_BITS-1:0] addr;
    assign addr = addr_in + {{(ADDR_BITS-3){1'b0}},cycle};

    wire [1:0] txn_n = data_read_n & data_write_n;
    always @(posedge clk) begin
        if (txn_n[1] == txn_n[0]) cycle <= 0;
        else if (cycle[0] == 0) cycle[0] <= 1;
        else if (txn_n[1] == 1 && cycle == 2'b01) cycle <= 2'b10;
    end

    always @(posedge clk) begin
        data_out[{cycle,3'b000}+:8] <= latch_data_out[addr];
    end

    always @(posedge clk) begin
        if (txn_n == 2'b00) data_ready <= 1;
        else if (txn_n == 2'b01 && cycle[0]) data_ready <= 1;
        else if (txn_n == 2'b10 && cycle == 2'b11) data_ready <= 1;
        else data_ready <= 0;
    end

    wire any_write = data_write_n != 2'b11;
    generate
    for (i = 0; i < RAM_BYTES; i = i+1) begin
        assign wen[i] = (i == addr) && any_write;
    end
    endgenerate
    assign latch_data_in = data_in[{cycle,3'b000}+:8];

    wire _unused = &{rstn, 1'b0};

endmodule
