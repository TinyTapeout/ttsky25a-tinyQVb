`default_nettype none

`define ROWS 4
`define COLUMNS 8

module transpose_matrix (
    input wire [`ROWS*`COLUMNS-1:0] input_matrix,
    output wire [`ROWS*`COLUMNS-1:0] output_matrix
);

genvar i, j;
generate

    for (j=0; j<`ROWS; j=j+1) begin : g_rows
        for (i=0; i<`COLUMNS; i=i+1) begin : g_columns
            assign output_matrix[i*`ROWS+j] = input_matrix[j*`COLUMNS+i];
        end
    end

endgenerate

endmodule
