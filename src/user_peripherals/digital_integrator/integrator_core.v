// integrator_core.v
`timescale 1ns/1ps
module integrator_core #(
    parameter IN_W = 8,        // input sample width 
    parameter ACC_W = 16       // accumulator width 
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  enable,      // global enable
    input  wire                  sample_strobe,// 1 cycle pulse to accept input
    input  wire signed [IN_W-1:0] sample_in,
    // config
    input  wire                  leaky_mode,  // 0: pure accum, 1: leaky
    input  wire [7:0]            decay_shift, // k -> multiplier (1 - 1/2^k) implemented as y <- y - (y>>k)
    input  wire                  sat_enable,  // saturation ON
    input  wire signed [ACC_W-1:0] sat_pos,   // positive saturation
    input  wire signed [ACC_W-1:0] sat_neg,   // negative saturation
    // status / outputs
    output reg signed [ACC_W-1:0] acc_out,
    output reg                   overflow_flag
);

    // Internal sign-extended input
    wire signed [ACC_W-1:0] sample_ext;
    assign sample_ext = {{(ACC_W-IN_W){sample_in[IN_W-1]}}, sample_in};

    // Leaky calculation: y' = y - (y >> k) + x
    wire signed [ACC_W-1:0] y_decay;
    assign y_decay = acc_out - (acc_out >>> decay_shift);

    // Detect sample strobe rising edge
    reg sample_strobe_prev;
    wire sample_strobe_rise;
    assign sample_strobe_rise = sample_strobe & ~sample_strobe_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sample_strobe_prev <= 1'b0;
        else
            sample_strobe_prev <= sample_strobe;
    end

    // Compute next accumulator value
    wire signed [ACC_W-1:0] acc_calc = leaky_mode ? y_decay + sample_ext : acc_out + sample_ext;

    // Signed overflow detection
    // overflow if two operands same sign, and result different sign from operands
    wire signed same_sign = (acc_out[ACC_W-1] == sample_ext[ACC_W-1]);
    wire signed overflow_add = same_sign && (acc_calc[ACC_W-1] != acc_out[ACC_W-1]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_out <= {ACC_W{1'b0}};
            overflow_flag <= 1'b0;
        end else begin
            if (enable && sample_strobe_rise) begin
                if (sat_enable) begin
                    if (overflow_add) begin
                        acc_out <= acc_out[ACC_W-1] ? sat_neg : sat_pos;
                        overflow_flag <= 1'b1;
                    end else if (acc_calc > sat_pos) begin
                        acc_out <= sat_pos;
                        overflow_flag <= 1'b1;
                    end else if (acc_calc < sat_neg) begin
                        acc_out <= sat_neg;
                        overflow_flag <= 1'b1;
                    end else begin
                        acc_out <= acc_calc;
                        overflow_flag <= 1'b0;
                    end
                end else begin
                    acc_out <= acc_calc;
                    overflow_flag <= overflow_add;
                end
            end
        end
    end


endmodule


