`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/02/2025 01:09:14 PM
// Design Name: 
// Module Name: crc32_v
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module crc32_v(
    input  clk, rst, 
    input  crc_trigger,
    input  data_done,
    input  [7:0] crc_32_in,
    input  RefIn,
    input  Xor_out,
    input  Init,
    input  [31:0] POLY_in,
    output crc_busy,
    output done_pulse,
    output [31:0] crc_out32_xor
);

    wire [31:0] POLY;

    wire [31:0] crc_out32;
    reg [31:0] crc_out32_reg;
    assign crc_out32 = crc_out32_reg;

    assign crc_out32_xor = (Xor_out) ? (crc_out32 ^ 32'hFFFF_FFFF) : (crc_out32 ^ 32'd0);

    parameter IDLE = 3'b000;
    parameter Byte_Xor = 3'b001;
    parameter Byte_Xor_ref = 3'b010;
    parameter Poly_Xor_ref = 3'b011;
    parameter Poly_Xor = 3'b100;
    parameter Done = 3'b101;

    reg [2:0] state,next_state;

    bit_reverser bit_reverser_inst (
        .en(RefIn),
        .in_data(POLY_in),
        .out_data(POLY)
    );

    reg crc_busy_reg;
    reg crc_finished_reg;
    wire crc_finished;
    assign crc_busy = crc_busy_reg;
    assign crc_finished = crc_finished_reg;

    always @(*) begin
        crc_busy_reg = 'b0;
        crc_finished_reg = 'b0;
        next_state = state;

        case (state)
            IDLE: begin
                if(crc_trigger)begin
                    if(RefIn)
                        next_state = Byte_Xor_ref;
                    else
                        next_state = Byte_Xor;
                end
            end

            Byte_Xor: begin
                crc_busy_reg = 'b1;
                next_state = Poly_Xor;
            end

            Poly_Xor: begin
                crc_busy_reg = 'b1;
                if(counter == 3'h7)
                    next_state = Done;
            end

            Byte_Xor_ref: begin
                crc_busy_reg = 'b1;
                next_state = Poly_Xor_ref;
            end

            Poly_Xor_ref: begin
                crc_busy_reg = 'b1;
                if(counter == 3'h7)
                    next_state = Done;
            end

            Done: begin
                crc_finished_reg = 'b1;
                if(crc_trigger) begin
                    next_state = (RefIn) ? Byte_Xor_ref : Byte_Xor;
                end
                else if(data_done) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;

        endcase
    end

    always @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    reg [31:0] crc32_next;

    always @(*) begin 
        crc32_next = crc_out32;

        case(state)
            IDLE: begin
                crc32_next = (Init) ? 32'hFFFF_FFFF : 32'd0;
            end

            Byte_Xor_ref: begin
                crc32_next = crc_out32 ^ crc_32_in;
            end

            Poly_Xor_ref: begin
                crc32_next = (crc_out32[0]) ? ((crc_out32 >> 1) ^ POLY) : (crc_out32 >> 1);
            end

            Byte_Xor: begin
                crc32_next = {(crc_out32[31:24] ^ crc_32_in), crc_out32[23:0]};
            end

            Poly_Xor: begin
                crc32_next = (crc_out32[31]) ? ((crc_out32 << 1) ^ POLY) : (crc_out32 << 1);
            end

            default: begin
            end
            
        endcase
    end

    reg [2:0] counter, counter_next;

    always @(*) begin 
        if(state == Poly_Xor | state == Poly_Xor_ref)
            counter_next = counter+1;
        else
            counter_next = counter;
    end

    always @(posedge clk) begin 
        if(rst) begin
            counter <= 0;
            crc_out32_reg <= (Init) ? 32'hFFFF_FFFF : 32'd0;
        end
        else begin
            counter <= counter_next;   
            crc_out32_reg <= crc32_next;
        end
    end

    reg done_pulse_reg, done_prev;

    always @(posedge clk) begin 
        if(rst) begin
            done_pulse_reg <= 0;
            done_prev <= 0;
        end
        else if(done_prev != crc_finished) begin
            done_pulse_reg <= crc_finished;
            done_prev <= crc_finished;
        end
        else begin
            done_pulse_reg <= 0;
            done_prev <= crc_finished;
        end
    end

    assign done_pulse = done_pulse_reg;

endmodule
