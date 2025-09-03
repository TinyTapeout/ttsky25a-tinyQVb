/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype wire

 // Change the name of this module to something that reflects its functionality and includes your name for uniqueness
 // For example tqvp_yourname_spi for an SPI peripheral.
 // Then edit tt_wrapper.v line 41 and change tqvp_example to your chosen module name.
module crc_wrapper (
    input         clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input         rst_n,        // Reset_n - low to reset.

    input  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock, note this will introduce 2 cycles of delay on the inputs.

    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input [5:0]   address,      // Address within this peripheral's address space
    input [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    
    output [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output        data_ready,

    output        user_interrupt  // Dedicated interrupt request for this peripheral
);

    always @(posedge clk) begin
        if (!rst_n==1) begin
            Enable_reg <= 0;
            Config_reg <= 0;
            input_data <= 0;
            Poly <= 32'h04C11DB7;
            Config_reg <= 8'hFF;
            data_en_reg <= 0;
        end 
        else begin
            data_en_reg <= 0;
            if (address == 6'h0) begin
                if (data_write_n != 2'b11)  
                    Enable_reg[7:0]   <= data_in[7:0];
            end
            if (address == 6'h4) begin
                if (data_write_n != 2'b11)              
                    Config_reg[7:0]   <= data_in[7:0];
            end
            if (address == 6'h8) begin
                if (data_write_n != 2'b11) begin
                    input_data[7:0]   <= data_in[7:0];
                    data_en_reg <= 1;
                end
            end
            if (address == 6'h10) begin
                if (data_write_n != 2'b11)              Poly[7:0]   <= data_in[7:0];
                if (data_write_n[1] != data_write_n[0]) Poly[15:8]  <= data_in[15:8];
                if (data_write_n == 2'b10)              Poly[31:16] <= data_in[31:16];
            end
        end
    end
     
    reg [7:0] Enable_reg;
    reg [7:0] Config_reg;
    reg [7:0] input_data;
    wire [31:0] output_data;
    reg [31:0] Poly;

    reg [31:0] data_out_reg;
    // All other addresses read 0.
    assign data_out = (address == 6'h0) ? {24'h0, Enable_reg} :
                      (address == 6'h4) ? {24'h0, Config_reg} :
                      (address == 6'hC) ? output_data :
                      (address == 6'h10) ? Poly :
                      32'h0;
 
    // All reads complete in 1 clock
    always @(*) begin
        case (address)
                6'h0:    data_ready_reg = 1;
                6'h4:    data_ready_reg = 1;
                6'hC:    data_ready_reg = (count == 0) ? 1 : 0;
                6'h10:   data_ready_reg = 1;
                default: data_ready_reg = 1;
        endcase
    end

    reg data_ready_reg;
    assign data_ready = data_ready_reg;

    wire data_en;
    reg data_en_reg;

    wire crc_trigger;
    reg crc_trigger_reg;

    assign crc_trigger = crc_trigger_reg;
    assign data_en = data_en_reg;

    always @(posedge clk) begin // Este bloque se cambia por logica mas precisa despues
        if((data_en)&(count==0))
            crc_trigger_reg<=1;
        else if((count > 1) & (!crc_busy))
            crc_trigger_reg <= 1;
        else
            crc_trigger_reg <= 0;
    end

    wire [3:0] count;

    fifo8_fwft fifo8_fwft_inst (
        .clk(clk),
        .rst_n(rst_n),
        .en(data_en),
        .din(input_data),
        .done(crc_done),
        .dout(lsb_out),
        .count(count)
    );

    wire [7:0] lsb_out;

    wire crc_done;
    wire crc_busy;
    
    reg data_done; // goes high for a cycle after the enable register goes low
    reg prev_en0;

    always @(posedge clk) begin
        if (~rst_n) begin
            data_done <= 1'b0;
            prev_en0  <= 1'b0;
        end 
        else begin
            data_done <= (prev_en0 && !Enable_reg[0]);
            prev_en0  <= Enable_reg[0];
        end
    end


    crc32_v crc32_inst (
        .clk(clk),
        .rst(~rst_n),
        .crc_trigger(crc_trigger_reg),
        .data_done(data_done),
        .crc_32_in(lsb_out),
        .RefIn(Config_reg[0]),
        .Xor_out(Config_reg[1]),
        .Init(Config_reg[2]),
        .POLY_in(Poly),
        .crc_busy(crc_busy),
        .done_pulse(crc_done),
        .crc_out32_xor(output_data)
    );

    // List all unused inputs to prevent warnings
    // data_read_n is unused as none of our behaviour depends on whether
    // registers are being read.
    reg last_ui_in_6;
    reg example_interrupt;
    always @(posedge clk) begin
        if (!rst_n) begin
            example_interrupt <= 0;
        end
        if (ui_in[0] && !last_ui_in_6) begin
            example_interrupt <= 1;
        end 
        else if (address == 6'h8 && data_write_n != 2'b11 && data_in[7]) begin
            example_interrupt <= 0;
        end

        last_ui_in_6 <= ui_in[0];
    end

    assign user_interrupt = example_interrupt;
    wire _unused = &{ui_in[7:1], data_read_n, 1'b0,uo_out};
    assign uo_out=0;
     
 endmodule