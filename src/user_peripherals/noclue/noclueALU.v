// Code your design here
/*
 * Copyright (c) 2025 Aditya Vikram Singh
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none


// ####mportant#### Then edit tt_wrapper.v line 38 and change tqvp_example to your chosen module name.
module noclueALU (
    input         clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input         rst_n,        // Reset_n - low to reset.

    input  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock, note this will introduce 2 cycles of delay on the inputs.

    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input [3:0]   address,      // Address within this peripheral's address space

    input         data_write,   // Data write request from the TinyQV core.
    input [7:0]   data_in,      // Data in to the peripheral, valid when data_write is high.
    
    output reg [7:0]  data_out      // Data out from the peripheral, set this in accordance with the supplied address
);

  reg [7:0] A; // operand 1
  reg [7:0] B; // operand 2
  reg [7:0] OPC; //opcode
  reg [7:0] RESULT; //result of operation (read only)
  
  // we need to update registers on write-
  always @(posedge clk)
    begin
      if(!rst_n)
        begin
          A<=8'h00;
          B<=8'h00;
          OPC<=8'h00;
        end
      else
        begin
          if (data_write)
            begin
              case (address)
                4'h0 : A<= data_in;    // write on A if address is 0 i.e. reg A is mapped to address 0
                4'h1 : B<= data_in;    // reg B is mapped to address 1
                4'h2 : OPC<= data_in;  // reg OPC is mapped to address 2
                default: ;			   // default do nothing eat a 5 star
              endcase
            end
        end
    end
  
  // ALU functional code
  always @(*)
    begin
      case(OPC[1:0])
        2'b00: RESULT=A+B; //Addition
        2'b01: RESULT=A-B; //Substraction
        2'b10: RESULT=A&B; //AND
        2'b11: RESULT=A|B; //OR
        default : RESULT=8'h00; // default do nothing, eat a you knoe what:)
      endcase
    end
  
  always @(*)
    begin
      case (address)
        4'h0 : data_out = A;
        4'h1 : data_out = B;
        4'h2 : data_out = OPC;
        4'h3 : data_out = RESULT;
        default : ;
      endcase
    end
  // above line puts result of operation to data out (from peripheral to cpu) if address is set to 4 bit hex 3 value
  // similarly we can give different values of address to get the value of operands and opcode
  

    // All output pins must be assigned. If not used, assign to 0.
    assign uo_out  = 8'h00;

endmodule
