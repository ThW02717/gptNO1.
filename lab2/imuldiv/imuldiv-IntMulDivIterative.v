//========================================================================
// Lab 1 - Iterative Mul/Div Unit
//========================================================================

`ifndef RISCV_INT_MULDIV_ITERATIVE_V
`define RISCV_INT_MULDIV_ITERATIVE_V

`include "imuldiv-MulDivReqMsg.v"
`include "imuldiv-IntMulIterative.v"
`include "imuldiv-IntDivIterative.v"

module imuldiv_IntMulDivIterative
(
  input         clk,
  input         reset,

  input   [2:0] muldivreq_msg_fn,
  input  [31:0] muldivreq_msg_a,
  input  [31:0] muldivreq_msg_b,
  input         muldivreq_val,
  output        muldivreq_rdy,

  output [63:0] muldivresp_msg_result,
  output        muldivresp_val,
  input         muldivresp_rdy
);

  //----------------------------------------------------------------------
  // Input Select
  //----------------------------------------------------------------------

  wire mulreq_val    = (( muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MUL ) ||
                       ( muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MULH ) ||
                       ( muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MULHU ) ||
                       ( muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_MULHSU ))
                     &&  muldivreq_val && divreq_rdy;

  wire divreq_val    = ((muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_DIV)  ||
                        (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_DIVU) ||
                        (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_REM)  ||
                        (muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_REMU)
                        ) && muldivreq_val && mulreq_rdy;

  wire divreq_msg_fn = ( muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_DIV
                     ||  muldivreq_msg_fn == `IMULDIV_MULDIVREQ_MSG_FUNC_REM );

  //----------------------------------------------------------------------
  // Output Select
  //----------------------------------------------------------------------

  wire        mulreq_rdy;
  wire        divreq_rdy;
  wire        mulresp_val;
  wire        divresp_val;
  wire [63:0] mulresp_msg_result;
  wire [63:0] divresp_msg_result;

  assign muldivreq_rdy          = mulreq_rdy && divreq_rdy;

  assign muldivresp_val         = mulresp_val || divresp_val;

  reg [63:0] result_mux_out;

  always @(*) begin
    case (muldivreq_msg_fn)
      // --------------------------
      // Low part (original MUL)
      // --------------------------
      `IMULDIV_MULDIVREQ_MSG_FUNC_MUL:
        result_mux_out = {32'b0, mulresp_msg_result[31:0]};

      // --------------------------
      // High 32-bit products
      // --------------------------
      `IMULDIV_MULDIVREQ_MSG_FUNC_MULH:   // signed × signed
        result_mux_out = {32'b0, mulresp_msg_result[63:32]};

      `IMULDIV_MULDIVREQ_MSG_FUNC_MULHU:  // unsigned × unsigned
        result_mux_out = {32'b0, mulresp_msg_result[63:32]};

      `IMULDIV_MULDIVREQ_MSG_FUNC_MULHSU: // signed × unsigned
        result_mux_out = {32'b0, mulresp_msg_result[63:32]};

      // --------------------------
      // Division and Remainder
      // --------------------------
      `IMULDIV_MULDIVREQ_MSG_FUNC_DIV,
      `IMULDIV_MULDIVREQ_MSG_FUNC_DIVU,
      `IMULDIV_MULDIVREQ_MSG_FUNC_REM,
      `IMULDIV_MULDIVREQ_MSG_FUNC_REMU:
        result_mux_out = divresp_msg_result;

      // Default fallback
      default:
        result_mux_out = 64'bx;
    endcase
  end

  assign muldivresp_msg_result = result_mux_out;

  //----------------------------------------------------------------------
  // Mul/Div Modules
  //----------------------------------------------------------------------

  imuldiv_IntMulIterative imul
  (
    .clk                (clk),
    .reset              (reset),
    .mulreq_msg_a       (muldivreq_msg_a),
    .mulreq_msg_b       (muldivreq_msg_b),
    .mulreq_msg_fn      (muldivreq_msg_fn),
    .mulreq_val         (mulreq_val),
    .mulreq_rdy         (mulreq_rdy),
    .mulresp_msg_result (mulresp_msg_result),
    .mulresp_val        (mulresp_val),
    .mulresp_rdy        (muldivresp_rdy)
  );

  imuldiv_IntDivIterative idiv
  (
    .clk                (clk),
    .reset              (reset),
    .divreq_msg_fn      (divreq_msg_fn),
    .divreq_msg_a       (muldivreq_msg_a),
    .divreq_msg_b       (muldivreq_msg_b),
    .divreq_val         (divreq_val),
    .divreq_rdy         (divreq_rdy),
    .divresp_msg_result (divresp_msg_result),
    .divresp_val        (divresp_val),
    .divresp_rdy        (muldivresp_rdy)
  );

endmodule

`endif
