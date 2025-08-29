// create a 1 clock wide pulse every cmp << 6 clock cycles
module pwm_strobe_gen #(
    parameter WIDTH = 8
    ) (
    input wire clk,
    input wire reset,
    input wire [7:0] cmp,
    output reg out
    );

    reg [WIDTH-1:0] count;

    always @(posedge clk) begin
        if(reset) begin
            count <= 1'b0;
            out   <= 1'b0;
        end else if (count >= cmp) begin
            out   <= 1'b1;
	    count <= 1'b0;
	end else begin
            count <= count + 1'b1;
	    out   <= 1'b0;
        end
    end

endmodule
