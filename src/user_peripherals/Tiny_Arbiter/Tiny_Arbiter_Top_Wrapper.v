// Author: Aakarshitha Suresh

// =============================================================
// PAC‑RR Arbiter MVP — SystemVerilog Skeletons (EDA Playground Ready)
// Weighted RR + Burst Caps(later) + Simple Aging (later, +1 bump) + Optional Lock Cap(later)
// Backpressure‑safe (no ready comb loops)
// =============================================================


/////////////////////////
////TOP Module////

// ============================
// tqvp_pac_rr.sv (MVP wrapper)
// ============================

// Code your design here

// =============================================================
// PAC‑RR Arbiter MVP — SystemVerilog Skeletons (EDA Playground Ready)
// Weighted RR + Burst Caps(later) + Simple Aging (later, +1 bump) + Optional Lock Cap(later)
// Backpressure‑safe (no ready comb loops)
// =============================================================


/////////////////////////
////TOP Module////

// ============================
// tqvp_pac_rr.v (MVP wrapper)
// ============================
// Author: Aakarshitha Suresh

// =============================================================
// PAC‑RR Arbiter MVP — SystemVerilog Skeletons (EDA Playground Ready)
// Weighted RR + Burst Caps(later) + Simple Aging (later, +1 bump) + Optional Lock Cap(later)
// Backpressure‑safe (no ready comb loops)
// =============================================================


/////////////////////////
////TOP Module////

// ============================
// tqvp_pac_rr.sv (MVP wrapper) in Verilog
// ============================

`default_nettype none
`timescale 1ns/1ps

module tqvp_pac_rr (
    input         clk,
    input         rst_n,

    input  [7:0]  ui_in,
    output [7:0]  uo_out,

    input  [3:0]  address,
    input         data_write,
    input  [7:0]  data_in,
    output [7:0]  data_out
);

    // -----------------------------------------------------------------------
    // Parameter definitions
    // N: number of requesters, W: width of each weight, IDX_WIDTH: log2(N)
    localparam integer N  = 4;
    localparam integer W  = 3;
    localparam integer IDX_WIDTH = 2;

    // Weight registers and their shadow copies
    reg [W-1:0] weight      [0:N-1];
    reg [W-1:0] weight_shad [0:N-1];
    reg         commit_pulse;   // write 1 to a CTRL reg to pulse this

    // Status wires
    wire [N-1:0]        grant_vec;
    wire                busy;
    wire [IDX_WIDTH-1:0] grant_idx;

    // Configuration weight bus for the core
    reg [N*W-1:0] cfg_weight;

    // Test/SoC stubs (TB drives these hierarchically)
    reg [N-1:0] req_stub;
    reg         ready_stub;
    reg         valid_stub;

    integer i;

    // Sequential logic to update shadow weights and commit pulse
    always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
        for (i = 0; i < N; i = i + 1) begin
          weight[i]      <= 3'd1;
          weight_shad[i] <= 3'd1;
        end
      end else begin
        // normal single-address writes update the SHADOW
        if (data_write) begin
          case (address)
            4'h2: weight_shad[0] <= data_in[2:0];
            4'h3: weight_shad[1] <= data_in[2:0];
            4'h4: weight_shad[2] <= data_in[2:0];
            4'h5: weight_shad[3] <= data_in[2:0];
            4'h6: commit_pulse   <= data_in[0]; // CTRL: write 1 to commit
            default: ;
          endcase
        end

        // one-cycle later, apply atomically
        if (commit_pulse) begin
          for (i = 0; i < N; i = i + 1) begin
            weight[i] <= weight_shad[i];
          end
          commit_pulse <= 1'b0; // auto-clear (or clear via write)
        end
      end
    end

    // Pack weight array into a flattened bus for the core. Since N and W are
    // constant for this design (N=4, W=3), concatenation is used instead of
    // variable part-select.
    always @* begin
      cfg_weight = {weight[3], weight[2], weight[1], weight[0]};
    end

    // Instantiate the RR core
    pac_rr_core #(
      .N(N), .W(W), .IDX_WIDTH(IDX_WIDTH)
    ) u_core (
      .clk_i        (clk),
      .rst_ni       (rst_n),
      .req_i        (req_stub),
      .sink_ready_i (ready_stub),
      .src_valid_i  (valid_stub),
      .grant_o      (grant_vec),
      .grant_idx_o  (grant_idx),
      .busy_o       (busy),
      .cfg_weight_i (cfg_weight)
    );

    // Readback map
    assign data_out =
        (address == 4'h2) ? {5'b0, weight[0]} :
        (address == 4'h3) ? {5'b0, weight[1]} :
        (address == 4'h4) ? {5'b0, weight[2]} :
        (address == 4'h5) ? {5'b0, weight[3]} :
        (address == 4'hE) ? {5'b0, busy, grant_idx} :
        (address == 4'hF) ? {4'b0, grant_vec} :
        8'h0;

    assign uo_out = 8'h00; // unused PMOD pins

endmodule

