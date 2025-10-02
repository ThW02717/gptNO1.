//========================================================================
// Lab 1 - Three Input Iterative Mul Unit (using two Booth multipliers)
//========================================================================

`ifndef RISCV_INT_MULDIV_THREEINPUT_V
`define RISCV_INT_MULDIV_THREEINPUT_V

`include "imuldiv-ThreeMulReqMsg.v"
`include "imuldiv-IntMulBooth.v"

module imuldiv_IntMulThreeInput
(
  input         clk,
  input         reset,

  input   [2:0] muldivreq_msg_fn,   // only need mul
  input  [31:0] muldivreq_msg_a,
  input  [31:0] muldivreq_msg_b,
  input  [31:0] muldivreq_msg_c,
  input         muldivreq_val,
  output        muldivreq_rdy,

  output [95:0] muldivresp_msg_result,
  output        muldivresp_val,
  input         muldivresp_rdy
);

  //----------------------------------------------------------------------
  // Busy lock: prevent next C value loaded too early(Protect C reg)
  //----------------------------------------------------------------------
  reg busy;
  // send_result: we finish computation and Send the final result output
  // this means the next data can come in, unlock signal
  wire send_result = muldivresp_val & muldivresp_rdy;
  // muldivreq_rdy lock by busy: if busy the process doesn't finish
  assign muldivreq_rdy = ~busy & ab_rdy;
  always @(posedge clk) begin
    if (reset)
      busy <= 1'b0;
    else begin
      if (muldivreq_val && muldivreq_rdy)
        busy <= 1'b1;          // calculate → busy
      else if (send_result)
        busy <= 1'b0;          // Computation Finish → busy no lock
    end
  end

  //----------------------------------------------------------------------
  // save c in a register when request ok, because we gonna use c value in hi lo
  //----------------------------------------------------------------------
  reg [31:0] c_reg;
  always @(posedge clk) begin
    if (reset)
      c_reg <= 32'b0;
    else if (muldivreq_val && muldivreq_rdy)
      c_reg <= muldivreq_msg_c;
  end

  //----------------------------------------------------------------------
  // State 1: A * B using 32bits booth multiplier
  //----------------------------------------------------------------------
  wire [63:0] ab_result;
  wire        ab_val;
  wire        ab_rdy;

  reg  [63:0] ab_reg;
  reg         ab_reg_val;

  
  wire booth_req_val = muldivreq_val & ~busy;
  

  imuldiv_IntMulBooth mul_ab (
    .clk               (clk),
    .reset             (reset),
    .mulreq_msg_a      (muldivreq_msg_a),
    .mulreq_msg_b      (muldivreq_msg_b),
    .mulreq_val        (booth_req_val), //input
    .mulresp_rdy       (1'b1),    // input
    .mulresp_msg_result(ab_result), 
    .mulresp_val       (ab_val),  // output
    .mulreq_rdy        (ab_rdy) //output
    
  );
  // Save A*B result for later use
  always @(posedge clk) begin
    if (reset) begin
      ab_reg     <= 64'b0;
      ab_reg_val <= 1'b0;
    end else if (ab_val) begin
      ab_reg     <= ab_result;
      ab_reg_val <= 1'b1;
    end else if (lo_val && hi_val) begin
      ab_reg_val <= 1'b0;
    end
  end

  
  // Move the c value from c_reg to creg_2
  // When we get the ab_result we need a register to save the c value
  // This c value loaded with A and B. just like the pipeline, pass down
  // the value in each differen state
  reg [31:0] c_reg2;
  always @(posedge clk) begin
    if (reset)
      c_reg2 <= 32'b0;
    else if (ab_val) 
      c_reg2 <= c_reg;
  end
  //----------------------------------------------------------------------
  // State 2: divide 64bit ab result into 2 32bit hi/lo
  // Multiplying hi and lo to c respectively
  //----------------------------------------------------------------------
  wire [63:0] lo_result;
  wire [63:0] hi_result;
  wire        lo_val, hi_val;
  // This is the bit for value handling for lo register
  wire lo_sign = ab_reg[31];  // sign bit of low 32-bit part

  imuldiv_IntMulBooth mul_lo (
    .clk               (clk),
    .reset             (reset),
    .mulreq_msg_a      (ab_reg[31:0]),
    .mulreq_msg_b      (c_reg2),
    .mulreq_val        (ab_reg_val),
    .mulreq_rdy        (),
    .mulresp_msg_result(lo_result),
    .mulresp_val       (lo_val),
    .mulresp_rdy       (1'b1)
  );

  imuldiv_IntMulBooth mul_hi (
    .clk               (clk),
    .reset             (reset),
    .mulreq_msg_a      (ab_reg[63:32]),
    .mulreq_msg_b      (c_reg2),
    .mulreq_val        (ab_reg_val),
    .mulreq_rdy        (),
    .mulresp_msg_result(hi_result),
    .mulresp_val       (hi_val),
    .mulresp_rdy       (1'b1)
  );

  //----------------------------------------------------------------------
  // State 3: Merge the two result into final result
  //----------------------------------------------------------------------
  reg  [95:0] final_result;
  reg         final_val;

  assign muldivresp_msg_result = final_result;
  assign muldivresp_val        = final_val;

  wire [95:0] lo_extend  = {{32{lo_result[63]}}, lo_result};
  wire [95:0] hi_extend  = {hi_result, 32'b0};
  // This is because our booth multiplier is a signed operation
  // but we sholud lo*c should be an unsigned operation 
  // In some cases if we treat lo register a signed value 
  // There will be a big problem, so we need to deal with it
  // Plus the signed bit(1*2^32) if we got a 1 in MSB
  wire [95:0] lo_com    = lo_sign ? ({{64{c_reg2[31]}}, c_reg2} << 32) : 96'b0;
  // Final result
  always @(posedge clk) begin
    if (reset) begin
      final_result <= 96'b0;
      final_val    <= 1'b0;
    end else if (lo_val && hi_val) begin
      final_result <= lo_extend + hi_extend + lo_com;
      final_val    <= 1'b1;
    end else if (send_result) begin
      final_val    <= 1'b0;
    end
  end

endmodule

`endif
