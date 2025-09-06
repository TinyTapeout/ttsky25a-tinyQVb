/*
 * Copyright (c) 2025 Dylan Toussaint, Justin Fok
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Cordic - trigonometry accelerator
module tqvp_baby_cordic (
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

    // Register map
    localparam [5:0] ADDR_THETA    = 6'h00; // float32 input
    localparam [5:0] ADDR_CONTROL  = 6'h01; // bit to switch the mode 1 = COS, 0 = SIN
    localparam [5:0] ADDR_RESULT   = 6'h02; // float32 result

    localparam [31:0] NAN = 32'h7FC0_0000;
    
    // Interface
    reg  [31:0] theta_reg;     //Input buffer
    reg         control_reg;   //Flag for cosine or sine mode -> 0 = COSINE, 1 = SINE
    reg         busy_reg;      //Indicates busy
    reg         start_reg;     //Signal to start
    reg         start_pending; //New Input, waiting to start
    reg  [31:0] result_reg;    //Output buffer
    reg         result_valid;  //Output valid flag

    wire        cordic_done;
    wire [31:0] cordic_result;
    wire        input_invalid_flag;

    // Useful wires for requests
    wire write_theta      = (data_write_n == 2'b10 && address == ADDR_THETA);
    wire write_control    = (data_write_n == 2'b00 && address == ADDR_CONTROL);
    wire read_result      = (data_read_n  == 2'b10 && address == ADDR_RESULT);
    
    // Cordic_instr_top
    // Assert start with a valid input on dataa to launch a cordic operation
    // output is valid when done is asserted.
    cordic_instr_top cit(
        .dataa             (theta_reg),
        .clk               (clk),
        .clk_en            (1'b1),
        .reset             (!rst_n),
        .start             (start_reg),
        .cos               (control_reg),
        .done              (cordic_done),
        .result            (cordic_result),
        .input_invalid_flag(input_invalid_flag)
    );

    // Handle requests
    always @(posedge clk) begin
        if(!rst_n) begin
            theta_reg     <= 32'd0;
            control_reg   <= 1'b0;
            result_reg    <= 32'd0;
            result_valid  <= 1'b0;
            busy_reg      <= 1'b0;
            start_pending <= 1'b0;
            start_reg     <= 1'b0;
        end else begin
            
            if(start_reg) begin
                start_reg <= 1'b0;
            end

            //Always accept writes to the control register
            if(write_control) begin
                control_reg <= data_in[0];
            end

            //Writes to theta are gated by the busy flag
            if(write_theta && !busy_reg) begin
                theta_reg     <= data_in;
                start_pending <= 1'b1;
                result_valid  <= 1'b0;
            end

            //Handle bad inputs by returning NAN
            if(start_pending) begin
                start_pending <= 1'b0;
                if(input_invalid_flag) begin
                    result_reg   <= NAN;
                    result_valid <= 1'b1;
                end else begin
                    start_reg <= 1'b1;
                    busy_reg  <= 1'b1;
                end
            end

            //Capture cordic result
            if(cordic_done) begin
                result_reg   <= cordic_result;
                result_valid <= 1'b1;
                busy_reg     <= 1'b0;
            end
        end
    end

    assign data_out   = read_result ? result_reg : 32'd0;
    assign data_ready = read_result && (result_valid || (!busy_reg && !start_pending));
    
    // List all unused inputs to prevent warnings
    // data_read_n is unused as none of our behaviour depends on whether
    // registers are being read.
    assign user_interrupt = 1'b0;
    assign uo_out = 8'b0;
    wire _unused = &{ui_in, 1'b0};
endmodule

