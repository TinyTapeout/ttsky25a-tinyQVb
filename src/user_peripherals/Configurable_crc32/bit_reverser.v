module bit_reverser (
    input  wire        en,       // enable signal
    input  wire [31:0] in_data,  // 32-bit input
    output wire [31:0] out_data  // 32-bit output
);

    assign out_data = (en) ? { in_data[0],  in_data[1],  in_data[2],  in_data[3],
                               in_data[4],  in_data[5],  in_data[6],  in_data[7],
                               in_data[8],  in_data[9],  in_data[10], in_data[11],
                               in_data[12], in_data[13], in_data[14], in_data[15],
                               in_data[16], in_data[17], in_data[18], in_data[19],
                               in_data[20], in_data[21], in_data[22], in_data[23],
                               in_data[24], in_data[25], in_data[26], in_data[27],
                               in_data[28], in_data[29], in_data[30], in_data[31] }
                             : in_data;

endmodule
