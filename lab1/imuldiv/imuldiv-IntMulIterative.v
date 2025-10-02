//========================================================================
// Lab 1 - Iterative Mul Unit
//========================================================================

`ifndef RISCV_INT_MUL_ITERATIVE_V
`define RISCV_INT_MUL_ITERATIVE_V

module imuldiv_IntMulIterative
(
  input                clk,
  input                reset,

  input  [31:0] mulreq_msg_a,
  input  [31:0] mulreq_msg_b,
  input         mulreq_val,
  input         mulresp_rdy,
  output [63:0] mulresp_msg_result,
  output        mulresp_val,
  output        mulreq_rdy
);
  // Control Signal
  wire a_mux_sel;
  wire b_mux_sel;
  wire result_mux_sel;
  wire add_mux_sel;
  wire result_en;
  wire cntr_mux_sel;
  wire sign_en;
  wire sign_mux_sel;
  wire b0;
  wire count;
  // Datapth module
  imuldiv_IntMulIterativeDpath dpath
  (
    .clk                (clk),
    .reset              (reset),
    .mulreq_msg_a       (mulreq_msg_a),
    .mulreq_msg_b       (mulreq_msg_b),

    .a_mux_sel(a_mux_sel),
    .b_mux_sel(b_mux_sel),
    .result_mux_sel(result_mux_sel),
    .result_en(result_en),
    .add_mux_sel(add_mux_sel),
    .cntr_mux_sel(cntr_mux_sel),
    .sign_en(sign_en),
    .sign_mux_sel(sign_mux_sel),

    .b0(b0),
    .count(count),
    .mulresp_msg_result(mulresp_msg_result)
  );

  imuldiv_IntMulIterativeCtrl ctrl
  (
    .clk(clk), 
    .reset(reset),

    .mulreq_val(mulreq_val),
    .mulreq_rdy(mulreq_rdy),
    .mulresp_val(mulresp_val),
    .mulresp_rdy(mulresp_rdy),

    .b0(b0), 
    .count(count),

    .a_mux_sel(a_mux_sel),
    .b_mux_sel(b_mux_sel),
    .result_mux_sel(result_mux_sel),
    .add_mux_sel(add_mux_sel),
    .result_en(result_en),
    .cntr_mux_sel(cntr_mux_sel),
    .sign_en(sign_en),
    .sign_mux_sel(sign_mux_sel)
  );

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module imuldiv_IntMulIterativeDpath
(
  input clk,
  input reset,

  // input for A & B
  input  [31:0] mulreq_msg_a,       // Operand A
  input  [31:0] mulreq_msg_b,       // Operand B

  // Control signals
  input a_mux_sel,
  input b_mux_sel,
  input result_mux_sel,
  input result_en,
  input add_mux_sel,
  
  input cntr_mux_sel,
  input sign_en,
  input sign_mux_sel,


  
  // Add or not Signal
  output b0,
  // shut down signal to control logic
  output count, 
  // 64bit result
  output [63:0] mulresp_msg_result // Result of operation
  
);
  
  // Register
  reg  [63:0] a_reg;       // Register for storing operand A
  reg  [31:0] b_reg;       // Register for storing operand B
  reg  [63:0] result_reg;   
  reg  [4:0] counter_reg;      
  reg  sign_reg; 
  // Loop Signal & shutdown signal
  assign b0 = b_reg[0];
  assign count = (counter_reg == 5'd0);
  // Sign data path & unsigned A value and B value
  wire a_sign = mulreq_msg_a[31];
  wire b_sign = mulreq_msg_b[31];
  wire sign = a_sign ^ b_sign;
  

  //------------------------------------------------------------------------
  // Path
  //-----------------------------------------------------------------------
  // A value in path
  wire [31:0] a_value = a_sign ? (~mulreq_msg_a + 32'b1) : mulreq_msg_a;
  // B value in path              ab
  wire [31:0] b_value = b_sign ? (~mulreq_msg_b + 32'b1) : mulreq_msg_b;
  // A Path
  wire [63:0] a_shift = a_reg << 1;
  wire [63:0] a_next_state  = a_mux_sel ? a_shift : {32'b0, a_value};
  // B Path
  wire [31:0] b_shift = b_reg >> 1;
  wire [31:0] b_next_state  = b_mux_sel ? b_shift : {32'b0, b_value};
  // Result Path
  wire [63:0] adder     = result_reg + a_reg;
  wire [63:0] add_mux_out = add_mux_sel ? adder : result_reg;
  wire [63:0] result_next = result_mux_sel ? add_mux_out : 64'b0;
  // Counter Path
  wire [4:0] counter_decrease = counter_reg - 5'd1;
  wire [4:0] counter_next = cntr_mux_sel ? counter_decrease : 5'd31;
  // Sign datapath
  // wire [63:0] unsigned_result = result_reg;
  // wire [63:0] signed_result   = ~unsigned_result + 64'd1;
  // wire [63:0] sign_mux_out    = sign_mux_sel ? signed_result : unsigned_result;
  //----------------------------------------------------------------------
  // Sequential Logic
  //----------------------------------------------------------------------
  always @(posedge clk) begin
    // Always zero for reset situation
    if (reset) begin
      a_reg <= 64'b0;
      b_reg <= 32'b0;
      result_reg <= 64'b0;
      counter_reg <= 5'b0;
      sign_reg <= 1'b0;
    end
    // Normal Situation
    else begin
      a_reg <= a_next_state;
      b_reg <= b_next_state;
      if (result_en) result_reg <= result_next;
      counter_reg <= counter_next;
      if (sign_en) sign_reg <= sign;
    end

  end

  //----------------------------------------------------------------------
  // Result
  //----------------------------------------------------------------------
  assign mulresp_msg_result = sign_reg ? (~result_reg + 64'd1) : result_reg;
  

endmodule

//------------------------------------------------------------------------
// Control Logic
//------------------------------------------------------------------------
// request is from outside to iterative mul perspective
module imuldiv_IntMulIterativeCtrl
(
  input clk,
  input reset,
  input mulreq_val,         // Request val Signal
  input mulresp_rdy,         // Response rdy Signal
  // From datapath
  input b0,
  input count,           // zero if not yet finish

  // output
  output mulreq_rdy,         // Request rdy Signal
  output mulresp_val,        // Response val Signal
  // Control signals
  output reg a_mux_sel,
  output reg b_mux_sel,
  output reg result_mux_sel,
  output reg result_en,
  output reg add_mux_sel,
  
  output reg cntr_mux_sel,
  output reg sign_en,
  output reg sign_mux_sel
);
  reg [1:0] state;
  reg[1:0] temp;
  reg [1:0] state_n;
  // State var
  localparam state_init = 2'd0;
  localparam state_compute = 2'd1;
  localparam state_finish = 2'd2;

  // Response and rquest check
  assign mulreq_rdy = (state == state_init); // Ready to recieve
  assign mulresp_val = (state == state_finish); // Reveive check
  // next state
  always @(*) begin
    case (state)
      state_init: temp = (mulreq_val & mulreq_rdy) ? state_compute : state_init;
      state_compute: temp = (count) ? state_finish : state_compute;
      state_finish: temp = (mulresp_rdy) ? state_init : state_finish;
      default: temp = state_init;
    endcase
  end
  // reset signal check
  always @(posedge clk) begin
    if (reset) state <= state_init;
    else       state <= temp;
  end
  // Control Signal
  always @(*) begin
    // Initial value
    a_mux_sel     = 1'b0;
    b_mux_sel     = 1'b0;
    result_mux_sel= 1'b0;
    add_mux_sel   = 1'b0;
    result_en     = 1'b0;
    cntr_mux_sel  = 1'b0;
    sign_en       = 1'b0;
    sign_mux_sel  = 1'b0;

    case (state)
      state_init: begin
        if (mulreq_val & mulreq_rdy) begin
          a_mux_sel      = 1'b0; // a b value
          b_mux_sel      = 1'b0; 
          result_mux_sel = 1'b0; 
          cntr_mux_sel   = 1'b0; // round count: 32
          sign_en        = 1'b1; 
          result_en      = 1'b1;
        end
      end

      state_compute: begin
        a_mux_sel     = 1'b1;   // shift a b
        b_mux_sel     = 1'b1;   
        cntr_mux_sel  = 1'b1;   // counter decrease
        add_mux_sel   = b0;     // b0 == 1 add A to product
        result_mux_sel= 1'b1;
        result_en     = 1'b1;
      end

      state_finish: begin

      end
    endcase
  end

endmodule

`endif
