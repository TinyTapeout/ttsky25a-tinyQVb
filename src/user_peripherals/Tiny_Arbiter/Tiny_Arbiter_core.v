// Author: Aakarshitha Suresh

// ============================
// pac_rr_core.v (MVP core logic)
// ============================

`timescale 1ns/1ps

module pac_rr_core #(
  parameter integer N  = 4,
  parameter integer W  = 3,
  // log2(N) bit width for requester index
  parameter integer IDX_WIDTH = 2
)(
  input                    clk_i,
  input                    rst_ni,

  input      [N-1:0]       req_i,
  input                    sink_ready_i,
  input                    src_valid_i,

  output reg [N-1:0]       grant_o,
  output reg [IDX_WIDTH-1:0] grant_idx_o,
  output reg               busy_o,

  // flattened weight configuration bus (N*W bits)
  input      [N*W-1:0]     cfg_weight_i
);

  // Beat accepted when handshake succeeds
  wire beat_accepted = sink_ready_i & src_valid_i & grant_o[grant_idx_o];

  // Size of requester index is log2(N)
  //parameter integer IDX_WIDTH = 2;

  // Registered winner/current grant
  reg [IDX_WIDTH-1:0] curr_q, curr_d;

  // RR pointer
  reg [IDX_WIDTH-1:0] rr_ptr_q, rr_ptr_d;

  // FSM state encoded with localparams
  localparam [1:0] IDLE   = 2'd0;
  localparam [1:0] PICK   = 2'd1;
  localparam [1:0] SERVE  = 2'd2;
  localparam [1:0] ROTATE = 2'd3;
  reg [1:0] st_q, st_d;

  // Contenders and selector
  reg [N-1:0] contenders;

  // Selected index
  reg [IDX_WIDTH-1:0] sel_idx;

  always_comb begin
    contenders = req_i;
    sel_idx    = rr_argmax(contenders, cfg_weight_i, rr_ptr_q);
  end
  
  // Rotate‑first‑one: return the first set bit in mask after rr_ptr (wrap around)
  function [IDX_WIDTH-1:0] rr_pick_first;
    input [N-1:0]         mask;
    input [IDX_WIDTH-1:0] rr_ptr;
    integer i;
    reg [2*N-1:0] rot;
    begin
      rot = {mask, mask};
      rr_pick_first = rr_ptr; // default
      for (i = 0; i < N; i = i + 1)
        if (rot[rr_ptr + i]) begin
          rr_pick_first = (rr_ptr + i) % N;
          return rr_pick_first;
        end
    end
  endfunction

  // Weighted argmax with round‑robin tie‑break.  Accepts a flattened weight bus.
  function [IDX_WIDTH-1:0] rr_argmax;
    input [N-1:0]          contenders_in;
    input [N*W-1:0]        weight_bus;
    input [IDX_WIDTH-1:0]  rr_ptr;
    integer k;
    integer idx;
    reg [W-1:0] max_w, w;
    reg [N-1:0] tie_mask;
    begin
      max_w = {W{1'b0}};
      // find the maximum weight among contenders
      for (k = 0; k < N; k = k + 1)
        if (contenders_in[k]) begin
          //idx = k * W;
          w = (weight_bus >> (k * W)) & {W{1'b1}};
          if (w > max_w)
            max_w = w;
        end
      // build a mask of contenders with the maximum weight
      for (k = 0; k < N; k = k + 1) begin
       // idx = k * W;
        w = (weight_bus >> (k * W)) & {W{1'b1}};
        tie_mask[k] = contenders_in[k] && (w == max_w);
      end
      // use rotate‑first‑one to select among ties
      rr_argmax = rr_pick_first(tie_mask, rr_ptr);
    end
  endfunction

  // FSM
  always_comb begin
    st_d        = st_q;
    curr_d      = curr_q;
    rr_ptr_d    = rr_ptr_q;

    grant_o     = '0;
    grant_idx_o = curr_q;
    busy_o      = (st_q != IDLE);

    case (st_q)
      IDLE: begin
        if (|contenders) st_d = PICK;
      end

      PICK: begin
        if (|contenders) begin
          curr_d = sel_idx;
          st_d   = SERVE;
        end else begin
          st_d = IDLE;
        end
      end

	  SERVE: begin
        // only drive grant when it actually makes sense
        if (req_i[curr_q] && src_valid_i)
          grant_o[curr_q] = 1'b1;

        // leave SERVE if request vanished or a beat was accepted
        if (!req_i[curr_q] || (sink_ready_i && src_valid_i && grant_o[curr_q]))
          st_d = ROTATE;
      end


      ROTATE: begin
        rr_ptr_d = (curr_q + 1) % N;
        st_d     = PICK;
      end
    endcase
  end

  // Registers
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      st_q     <= IDLE;
      curr_q   <= '0;
      rr_ptr_q <= '0;
    end else begin
      st_q     <= st_d;
      curr_q   <= curr_d;
      rr_ptr_q <= rr_ptr_d;
    end
  end

endmodule : pac_rr_core
