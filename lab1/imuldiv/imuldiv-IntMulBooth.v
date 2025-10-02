//========================================================================
// Lab 1 - Booth Iterative Mul Unit
//========================================================================

`ifndef RISCV_INT_MUL_BOOTH_V
`define RISCV_INT_MUL_BOOTH_V

module imuldiv_IntMulBooth
(
  input         clk,
  input         reset,

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

  wire result_en;
  wire cntr_mux_sel;
  wire sign_en;
  wire sign_mux_sel;

  wire count;
  imuldiv_IntMulBoothDpath dpath
  (
    .clk(clk),
    .reset(reset),
    .mulreq_msg_a(mulreq_msg_a),
    .mulreq_msg_b(mulreq_msg_b),

    .a_mux_sel(a_mux_sel),
    .b_mux_sel(b_mux_sel),
    .result_mux_sel(result_mux_sel),
    .result_en(result_en),
    .cntr_mux_sel(cntr_mux_sel),
    .sign_en(sign_en),
    .sign_mux_sel(sign_mux_sel),

    .count(count),
    .mulresp_msg_result(mulresp_msg_result)
  );

  imuldiv_IntMulBoothCtrl ctrl
  (
    .clk(clk),
    .reset(reset),
    .mulreq_val(mulreq_val),
    .mulreq_rdy(mulreq_rdy),
    .mulresp_val(mulresp_val),
    .mulresp_rdy(mulresp_rdy),
    .count(count),
    .a_mux_sel(a_mux_sel),
    .b_mux_sel(b_mux_sel),
    .result_mux_sel(result_mux_sel),
    .result_en(result_en),
    .cntr_mux_sel(cntr_mux_sel),
    .sign_en(sign_en),
    .sign_mux_sel(sign_mux_sel)
  );

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module imuldiv_IntMulBoothDpath
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
  // no need? input add_mux_sel,
  
  input cntr_mux_sel,
  input sign_en,
  input sign_mux_sel,


  
  // Add or not Signal
  // no need? output b0,
  // shut down signal to control logic
  output count, 
  // 64bit result
  output [63:0] mulresp_msg_result // Result of operation
);
  // Register
  reg  [63:0] a_reg;       // Register for storing operand A
  reg  [32:0] b_reg;       // Register for storing operand B
  reg  [63:0] result_reg;   
  reg  [3:0] counter_reg;      
  reg  sign_reg; 
  // Loop Signal & shutdown signal
  assign count = (counter_reg == 4'd0);

  // Sign data path & unsigned A value and B value
  wire a_sign = mulreq_msg_a[31];
  wire b_sign = mulreq_msg_b[31];
  wire sign = a_sign ^ b_sign;
  //------------------------------------------------------------------------
  // Path Value
  //-----------------------------------------------------------------------
  // A value
  wire [63:0] a_value = {{32{mulreq_msg_a[31]}}, mulreq_msg_a};
  // B value
  wire [32:0] b_value = {mulreq_msg_b, 1'b0};


  wire [63:0] a_shift      = a_reg << 2;
  wire [63:0] a_next_state = a_mux_sel ? a_shift : a_value;
  wire [32:0] b_shift      = b_reg >> 2;
  wire [32:0] b_next_state = b_mux_sel ? b_shift : b_value;
  // Booth path
  wire [2:0] booth_bits = b_reg[2:0];
  reg  [63:0] booth;

  always @(*) begin
    case (booth_bits)
      3'b000, 3'b111: booth = 64'd0; // just shift
      3'b001, 3'b010: booth = a_reg; // +A
      3'b011:         booth = a_reg << 1; // +2A
      3'b100:         booth = - (a_reg << 1); // -2A
      3'b101, 3'b110: booth = - a_reg; // -A
      default:        booth = 64'd0;
    endcase
  end
  // Result & count
  wire [63:0] adder       = result_reg + booth;
  wire [63:0] result_next = result_mux_sel ? adder : 64'd0;

  // Counter path
  wire [3:0] counter_decrease = counter_reg - 4'd1;
  wire [3:0] counter_next     = cntr_mux_sel ? counter_decrease : 4'd15;

  //----------------------------------------------------------------------
  // Sequential Logic
  //----------------------------------------------------------------------


  always @(posedge clk) begin
    if (reset) begin
      a_reg       <= 64'b0;
      b_reg       <= 33'b0;
      result_reg  <= 64'b0;
      counter_reg <= 4'b0;
      sign_reg    <= 1'b0;
    end else begin
      a_reg       <= a_next_state;
      b_reg       <= b_next_state;
      if (result_en) result_reg <= result_next;
      counter_reg <= counter_next;
      if (sign_en) 
        sign_reg <= mulreq_msg_a[31] ^ mulreq_msg_b[31];
    end
  end

  //----------------------------------------------------------------------
  // Result
  //----------------------------------------------------------------------
  assign mulresp_msg_result = result_reg;
endmodule

//------------------------------------------------------------------------
// Control Logic
//------------------------------------------------------------------------
// request is from outside to iterative mul perspective
module imuldiv_IntMulBoothCtrl
(
  input clk,
  input reset,
  input mulreq_val,         // Request val Signal
  input mulresp_rdy,         // Response rdy Signal
  // From datapath

  input count,           // zero if not yet finish

  // output
  output mulreq_rdy,         // Request rdy Signal
  output mulresp_val,        // Response val Signal
  // Control signals
  output reg a_mux_sel,
  output reg b_mux_sel,
  output reg result_mux_sel,
  output reg result_en,

  
  output reg cntr_mux_sel,
  output reg sign_en,
  output reg sign_mux_sel
);
  reg [1:0] state;
  reg[1:0] temp;

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
        result_mux_sel= 1'b1;
        result_en     = 1'b1;
      end

      state_finish: begin

      end
    endcase
  end

endmodule

`endif
