//=========================================================================
// 5-Stage RISCV Reorder Buffer
//=========================================================================

`ifndef RISCV_CORE_REORDERBUFFER_V
`define RISCV_CORE_REORDERBUFFER_V

`include "riscvooo-InstMsg.v"

module riscv_CoreReorderBuffer
(
  input               clk,
  input               reset,

  // ---- Allocate (from D stage) ----
  input               rob_alloc_req_val,
  output              rob_alloc_req_rdy,
  input  [ 4:0]       rob_alloc_req_preg,      // 上游保證 rd != 0 再丟進來
  output [`LOG_S-1:0] rob_alloc_resp_slot,

  // ---- Fill (from W stage) ----
  input               rob_fill_val,
  input  [`LOG_S-1:0] rob_fill_slot,

  // ---- Commit (to ctrl/scoreboard) ----
  output              rob_commit_wen,
  output [`LOG_S-1:0] rob_commit_slot,
  output [ 4:0]       rob_commit_rf_waddr
);

  // --------------------------------------------------------------------
  // Params & State
  // --------------------------------------------------------------------
  localparam integer S = (1 << `LOG_S);   // ROB 深度，須為 2^k

  // 每格記：valid(已分配)、ready(已寫回)、waddr(目的暫存器)
  reg                valid [0:S-1];
  reg                ready [0:S-1];
  reg [4:0]          waddr [0:S-1];

  // 環形指標 + 使用數
  reg [`LOG_S-1:0]   head;                // 提交端
  reg [`LOG_S-1:0]   tail;                // 配置端
  reg [`LOG_S:0]     count;               // 0..S

  // --------------------------------------------------------------------
  // Handshakes
  // --------------------------------------------------------------------
  wire allocate_good = rob_alloc_req_val && rob_alloc_req_rdy;
  assign rob_alloc_req_rdy   = (count != S);     // not full
  assign rob_alloc_resp_slot = tail;

  // 嚴格 in-order commit：只看 head
  wire head_valid   = valid[head];
  wire head_ready   = ready[head];
  wire commit_good  = head_valid && head_ready;

  assign rob_commit_wen      = commit_good;
  assign rob_commit_slot     = head;
  assign rob_commit_rf_waddr = waddr[head];

  // --------------------------------------------------------------------
  // Sequential logic
  // --------------------------------------------------------------------
  integer i;
  always @(posedge clk) begin
    if (reset) begin
      head  <= {`LOG_S{1'b0}};
      tail  <= {`LOG_S{1'b0}};
      count <= {(`LOG_S+1){1'b0}};
      for (i = 0; i < S; i = i + 1) begin
        valid[i] <= 1'b0;
        ready[i] <= 1'b0;
        waddr[i] <= 5'b0;
      end
    end else begin
      // ---- Allocate ----
      if (allocate_good) begin
        valid[tail] <= 1'b1;
        ready[tail] <= 1'b0;
        waddr[tail] <= rob_alloc_req_preg;
        tail        <= tail + {{(`LOG_S-1){1'b0}}, 1'b1}; 
      end

      // ---- Fill (out of order) ----
      if (rob_fill_val) begin
        if (valid[rob_fill_slot]) begin
          ready[rob_fill_slot] <= 1'b1;
        end
      end

      // ---- Commit (in order) ----
      if (commit_good) begin
        valid[head] <= 1'b0;
        ready[head] <= 1'b0;
        head        <= head + {{(`LOG_S-1){1'b0}}, 1'b1};
      end

      // ---- Count ----
      case ({allocate_good, commit_good})
        2'b10: count <= count + {{`LOG_S{1'b0}}, 1'b1};  // onyl alloc
        2'b01: count <= count - {{`LOG_S{1'b0}}, 1'b1};  // only commit
        default: count <= count;                         // 00 or 11
      endcase
    end
  end


endmodule

`endif
