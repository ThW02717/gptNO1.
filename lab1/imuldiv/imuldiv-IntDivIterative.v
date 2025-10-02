//========================================================================
// Lab 1 - Iterative Div Unit
//========================================================================

`ifndef RISCV_INT_DIV_ITERATIVE_V
`define RISCV_INT_DIV_ITERATIVE_V

`include "imuldiv-DivReqMsg.v"

module imuldiv_IntDivIterative
(

  input         clk,
  input         reset,

  input divreq_msg_fn,
  input  [31:0] divreq_msg_a,
  input  [31:0] divreq_msg_b,
  input         divreq_val,
  input         divresp_rdy,

  output        divreq_rdy,
  output [63:0] divresp_msg_result,
  output        divresp_val
  
);
  // Control wires
  wire a_mux_sel;
  wire sub_mux_sel;
  wire a_en;
  wire b_en;
  wire cntr_mux_sel;
  wire sign_en;
  wire reg_sign_mux_sel;
  wire div_sign_mux_sel;
  wire count;

  imuldiv_IntDivIterativeDpath dpath
  (
    .clk                (clk),
    .reset              (reset),

    .divreq_msg_fn      (divreq_msg_fn),
    .divreq_msg_a       (divreq_msg_a),
    .divreq_msg_b       (divreq_msg_b),

    .a_mux_sel     (a_mux_sel),
    .sub_mux_sel   (sub_mux_sel),
    .a_en          (a_en),
    .b_en          (b_en),
    .cntr_mux_sel  (cntr_mux_sel),
    .sign_en       (sign_en),
    .reg_sign_mux_sel (reg_sign_mux_sel),
    .div_sign_mux_sel (div_sign_mux_sel),

    .count(count),
    .divresp_msg_result(divresp_msg_result)
  );

  imuldiv_IntDivIterativeCtrl ctrl
  (
    .clk   (clk),
    .reset (reset),

    .divreq_msg_fn(divreq_msg_fn),
    .divreq_val   (divreq_val),
    .divresp_rdy  (divresp_rdy),
    .count        (count),

    .divreq_rdy   (divreq_rdy),
    .divresp_val  (divresp_val),

    .a_mux_sel    (a_mux_sel),
    .sub_mux_sel  (sub_mux_sel),
    .a_en         (a_en),
    .b_en         (b_en),
    .cntr_mux_sel (cntr_mux_sel),
    .sign_en      (sign_en),
    .reg_sign_mux_sel (reg_sign_mux_sel),
    .div_sign_mux_sel (div_sign_mux_sel)
  );

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module imuldiv_IntDivIterativeDpath
(
  input clk,
  input reset,

  input divreq_msg_fn,  
  // Input A B
  input  [31:0] divreq_msg_a,       // Operand A
  input  [31:0] divreq_msg_b,       // Operand B
  // control signal
  input a_mux_sel,
  input sub_mux_sel,
  input a_en,
  input b_en,
  input cntr_mux_sel,
  input sign_en,
  input reg_sign_mux_sel,
  input div_sign_mux_sel,

  // Shutdown signal
  output count,
  //////////////////////////
  output [63:0] divresp_msg_result // Result of operation 
);
  
  // registers
  reg [64:0] a_reg;
  reg [64:0] b_reg;
  reg [4:0] counter_reg;
  reg div_sign_reg;
  reg rem_sign_reg;
  // shutdown signal
  assign count = (counter_reg == 5'd0);
  // Sign data path & unsigned A value and B value

  wire is_signed = divreq_msg_fn; // Signed operation?
  wire a_sign = is_signed && divreq_msg_a[31];
  wire b_sign = is_signed && divreq_msg_b[31];

  // unsigned A, B
  wire [31:0] a_unsigned = a_sign ? (~divreq_msg_a + 32'b1) : divreq_msg_a;
  wire [31:0] b_unsigned = b_sign ? (~divreq_msg_b + 32'b1) : divreq_msg_b;
  // Sign operation or not, if unsigned at first use the original
  wire [31:0] a_init = is_signed ? a_unsigned : divreq_msg_a;
  wire [31:0] b_init = is_signed ? b_unsigned : divreq_msg_b;
  //------------------------------------------------------------------------
  // Path
  //-----------------------------------------------------------------------
  // A value in path
  wire [64:0] a_value = {33'b0, a_init};
  // B value in path
  wire [64:0] b_value = {1'b0, b_init, 32'b0}; 
  wire [64:0] a_shift_out = a_reg << 1;
  wire [65:0] sub_out = {1'b0, a_shift_out} - {1'b0, b_reg};
  // negative: return and shift positive get sub result
  wire [64:0] sub_mux_out = {sub_out[64:1], 1'b1};
  wire [64:0] a_res = sub_out[65] ? a_shift_out : sub_mux_out;
  wire [64:0] a_next = a_mux_sel ? (sub_mux_sel ? a_res : a_shift_out) : a_value;
  
  //----------------------------------------------------------------------
  // Sequential Logic
  //----------------------------------------------------------------------

   always @(posedge clk) begin
    if (reset) begin
      a_reg        <= 65'b0;
      b_reg        <= 65'b0;
      counter_reg  <= 5'b0;
      div_sign_reg <= 1'b0;
      rem_sign_reg <= 1'b0;
    end
    else begin
      if (a_en) a_reg <= a_next;
      if (b_en) b_reg <= b_value;
      counter_reg <= cntr_mux_sel ? (counter_reg - 5'd1) : 5'd31;

      if (sign_en) begin
        div_sign_reg <= a_sign ^ b_sign; 
        rem_sign_reg <= a_sign;           
      end 
    end
  end

  // remainder and quatinent unsign
  wire [31:0] quotinent_unsigned = a_reg[31:0];
  wire [31:0] remainder_unsigned = a_reg[63:32];
  // complement
  wire [31:0] quotinent_com = ~quotinent_unsigned + 32'd1;
  wire [31:0] remainder_com = ~remainder_unsigned + 32'd1;
  // Mux
  wire [31:0] quotinent_result =
    (is_signed && div_sign_reg) ? quotinent_com : quotinent_unsigned;

  wire [31:0] remainder_result =
    (rem_sign_reg) ? remainder_com : remainder_unsigned;
  // Result
  assign divresp_msg_result = {remainder_result, quotinent_result};

endmodule

//------------------------------------------------------------------------
// Control Logic
//------------------------------------------------------------------------

module imuldiv_IntDivIterativeCtrl
(
  input clk,
  input reset,
  
  input divreq_msg_fn,
  input divreq_val,         // Request val Signal
  input divresp_rdy,         // Response rdy Signal
  input count,

  // output
  output divreq_rdy,         // Request rdy Signal
  output divresp_val,        // Response val Signal
  // control signal
  output reg a_mux_sel,
  output reg sub_mux_sel,
  output reg a_en,
  output reg b_en,
  output reg cntr_mux_sel,
  output reg sign_en,
  output reg reg_sign_mux_sel,
  output reg div_sign_mux_sel
);

  wire is_signed = divreq_msg_fn;
  // // State var
  localparam state_init    = 2'd0;
  localparam state_compute = 2'd1;
  localparam state_finish  = 2'd2;
  reg [1:0] state;
  reg[1:0] temp;
  // Response and rquest check
  assign divreq_rdy  = (state == state_init);
  assign divresp_val = (state == state_finish);
  // next state 
  always @(*) begin
    case (state)
      state_init:    temp = (divreq_val & divreq_rdy) ? state_compute : state_init;
      state_compute: temp = (count) ? state_finish : state_compute;
      state_finish:  temp = (divresp_rdy) ? state_init : state_finish;
      default:       temp = state_init;
    endcase
  end
  // reset signal
  always @(posedge clk) begin
    if (reset) state <= state_init;
    else       state <= temp;
  end
  // control signals
  always @(*) begin
    // default
    a_mux_sel        = 1'b0;
    sub_mux_sel      = 1'b0;
    a_en             = 1'b0;
    b_en             = 1'b0;
    cntr_mux_sel     = 1'b0;
    sign_en          = 1'b0;
    div_sign_mux_sel = 1'b0;
    reg_sign_mux_sel = 1'b0;

    case (state)
      state_init: begin
        if (divreq_val & divreq_rdy) begin
          a_mux_sel    = 1'b0; 
          a_en         = 1'b1;
          b_en         = 1'b1;
          cntr_mux_sel = 1'b0; 
          sign_en      = 1'b1; 
        end
      end

      state_compute: begin
        a_mux_sel    = 1'b1; 
        sub_mux_sel  = 1'b1; 
        a_en         = 1'b1;
        cntr_mux_sel = 1'b1; // counter--
      end

      state_finish: begin
        if (is_signed) begin
          div_sign_mux_sel = 1'b1;
          reg_sign_mux_sel = 1'b1;
        end else begin
          div_sign_mux_sel = 1'b0;
          reg_sign_mux_sel = 1'b0;
        end
      end
    endcase
  end
endmodule

`endif
