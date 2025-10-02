//========================================================================
// Simulator for Three-Input Iterative Multiplier
//========================================================================

`include "imuldiv-ThreeMulReqMsg.v"
`include "imuldiv-IntMulThreeInput.v"

//------------------------------------------------------------------------
// Simulator
//------------------------------------------------------------------------

module sim;

  // VCD Dump
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end

  // Generate Clock
  reg clk = 1'b0;
  always #5 clk = ~clk;

  // Three-Input Mult Unit
  reg   [2:0] src_msg_fn;
  reg  [31:0] src_msg_a;
  reg  [31:0] src_msg_b;
  reg  [31:0] src_msg_c;
  reg         src_val = 1'b0;
  wire        src_rdy;

  wire [95:0] sink_msg;
  wire        sink_val;
  wire        sink_rdy = 1'b1; // Always ready

  wire        mulreq_go  = src_val && src_rdy;
  wire        mulresp_go = sink_val && sink_rdy;

  reg reset = 1'b1;

  imuldiv_IntMulThreeInput imul3
  (
    .clk                    (clk),
    .reset                  (reset),
    .muldivreq_msg_fn       (src_msg_fn),
    .muldivreq_msg_a        (src_msg_a),
    .muldivreq_msg_b        (src_msg_b),
    .muldivreq_msg_c        (src_msg_c),
    .muldivreq_val          (src_val),
    .muldivreq_rdy          (src_rdy),
    .muldivresp_msg_result  (sink_msg),
    .muldivresp_val         (sink_val),
    .muldivresp_rdy         (sink_rdy)
  );

  // Initial Block
  reg [1023:0] op_type;

  initial begin
    // Reset signal
    #10 reset = 1'b0;

    // Parse Arguments
    if ( !$value$plusargs( "op=%s", op_type ) ) begin
      $display( "No operation specified! Only {mul} supported" ); $finish;
    end

    if ( op_type != "mul" ) begin
      $display( "Illegal operation! Only {mul} supported" );
      $finish;
    end

    src_msg_fn = `IMULDIV_THREE_MULDIVREQ_MSG_FUNC_MUL;

    if ( !$value$plusargs( "a=%h", src_msg_a ) ) begin
      $display( "No operand A specified!" ); $finish;
    end
    if ( !$value$plusargs( "b=%h", src_msg_b ) ) begin
      $display( "No operand B specified!" ); $finish;
    end
    if ( !$value$plusargs( "c=%h", src_msg_c ) ) begin
      $display( "No operand C specified!" ); $finish;
    end

    // Set request valid high
    src_val = 1'b1;
  end

  // Count Clock Cycles
  reg        busy = 1'b0;
  reg [31:0] cycle_count = 32'b0;

  always @ (posedge clk) begin
    if ( mulreq_go ) busy <= 1'b1;

    // Result ready
    else if ( mulresp_go ) begin
      $display( "0x%h * 0x%h * 0x%h = 0x%h", src_msg_a, src_msg_b, src_msg_c, sink_msg );
      $display( "Cycle Count = %d", cycle_count );
      $finish;
    end

    // Reset val after accepted
    if ( mulreq_go ) src_val <= 1'b0;

    if ( mulreq_go || busy )
      cycle_count <= cycle_count + 1;
  end

endmodule
