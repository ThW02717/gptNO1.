//=========================================================================
// Cache Base Design (2KB, Direct-Mapped, 64B Block, Write-Allocate)
//=========================================================================

`ifndef RISCV_CACHE_BASE_V
`define RISCV_CACHE_BASE_V

`include "riscvbc-CacheMsg.v"
`include "vc-RAMs.v"

//-------------------------------------------------------------------------
// Cache Parameters
//-------------------------------------------------------------------------
`define CL_IDX_BITS  5    
`define CL_OFF_BITS  6    
`define CL_TAG_BITS  21   
`define CL_BLK_SIZE  512 

module riscv_CacheBase (
    input  clk,
    input  reset,

    // Processor to Cache Request
    input                       memreq_val,
    output                      memreq_rdy,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,

    // Cache to Processor Response
    output                      memresp_val,
    input                       memresp_rdy,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,

    // Cache to Memory Request
    output                      cachereq_val,
    input                       cachereq_rdy,
    output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg,

    // Memory to Cache Response
    input                       cacheresp_val,
    output                      cacheresp_rdy,
    input  [`VC_MEM_RESP_MSG_SZ(32)-1:0]   cacheresp_msg
);

  //----------------------------------------------------------------------
  // Wires
  //----------------------------------------------------------------------

  wire        memreq_en;
  wire        tag_wen;
  wire        data_wen;
  wire        write_data_mux_sel;
  wire        miss;
  wire        refill_cnt_en;
  wire        refill_cnt_clr;
  
  wire        cachereq_type; 
  wire        evict_sel;     

  wire [2:0]  state;
  wire        type;
  wire        tag_match;
  wire        valid_bit;
  wire        dirty_bit;
  
  wire [4:0]  refill_counter;

  // RAM Interface Wires
  wire [`CL_IDX_BITS-1:0]   tag_addr;
  wire [22:0]               tag_wdata;
  wire [22:0]               tag_rdata;
  
  wire [`CL_IDX_BITS-1:0]   data_addr;
  wire [`CL_BLK_SIZE-1:0]   data_wdata;
  wire [`CL_BLK_SIZE-1:0]   data_rdata;

  //----------------------------------------------------------------------
  // Datapath Instance
  //----------------------------------------------------------------------

  riscv_CacheBaseDpath dpath
  (
    .clk                (clk),
    .reset              (reset),

    .memreq_val         (memreq_val),
    .memreq_msg         (memreq_msg),
    .cacheresp_msg      (cacheresp_msg),
    .memresp_msg        (memresp_msg),
    .cachereq_msg       (cachereq_msg),

    .state              (state),
    .memreq_en          (memreq_en),
    .tag_wen            (tag_wen),
    .data_wen           (data_wen),
    .write_data_mux_sel (write_data_mux_sel),
    .miss               (miss),
    .refill_cnt_en      (refill_cnt_en),
    .refill_cnt_clr     (refill_cnt_clr),
    
    .cachereq_type      (cachereq_type),
    .evict_sel          (evict_sel),

    .type               (type),
    .tag_match          (tag_match),
    .valid_bit          (valid_bit),
    .dirty_bit          (dirty_bit),
    .refill_counter     (refill_counter),

    .tag_addr           (tag_addr),
    .tag_wdata          (tag_wdata),
    .tag_rdata          (tag_rdata),
    .data_addr          (data_addr),
    .data_wdata         (data_wdata),
    .data_rdata         (data_rdata)
  );

  //----------------------------------------------------------------------
  // Control Logic Instance
  //----------------------------------------------------------------------

  riscv_CacheBaseCtrl ctrl
  (
    .clk                (clk),
    .reset              (reset),

    .memreq_val         (memreq_val),
    .memreq_rdy         (memreq_rdy),
    .memresp_val        (memresp_val),
    .memresp_rdy        (memresp_rdy),
    .cachereq_val       (cachereq_val),
    .cachereq_rdy       (cachereq_rdy),
    .cacheresp_val      (cacheresp_val),
    .cacheresp_rdy      (cacheresp_rdy),

    .type               (type),
    .tag_match          (tag_match),
    .valid_bit          (valid_bit),
    .dirty_bit          (dirty_bit),
    .refill_counter     (refill_counter),

    .state              (state),
    .memreq_en          (memreq_en),
    .tag_wen            (tag_wen),
    .data_wen           (data_wen),
    .write_data_mux_sel (write_data_mux_sel),
    .miss               (miss),
    .refill_cnt_en      (refill_cnt_en),
    .refill_cnt_clr     (refill_cnt_clr),
    
    .cachereq_type      (cachereq_type),
    .evict_sel          (evict_sel)
  );

  //----------------------------------------------------------------------
  // RAM Modules
  //----------------------------------------------------------------------

  vc_RAM_rst_1w1r_pf #(
    .DATA_SZ     (`CL_BLK_SIZE),
    .ENTRIES     (32),
    .ADDR_SZ     (`CL_IDX_BITS),
    .RESET_VALUE (0)
  ) _data_ram (
    .clk       (clk),
    .reset_p   (reset),
    .raddr     (tag_addr),
    .rdata     (data_rdata),
    .wen_p     (data_wen),
    .waddr_p   (data_addr),
    .wdata_p   (data_wdata)
  ); 

  vc_RAM_rst_1w1r_pf #(
    .DATA_SZ     (23),
    .ENTRIES     (32),
    .ADDR_SZ     (`CL_IDX_BITS),
    .RESET_VALUE (0)
  ) _tag_ram (
    .clk       (clk),
    .reset_p   (reset),
    .raddr     (tag_addr),
    .rdata     (tag_rdata),
    .wen_p     (tag_wen),
    .waddr_p   (tag_addr),
    .wdata_p   (tag_wdata)
  );

endmodule

//------------------------------------------------------------------------
// Datapath Module
//------------------------------------------------------------------------

module riscv_CacheBaseDpath (
    input           clk,
    input           reset,

    input              memreq_val, 
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,
    input  [`VC_MEM_RESP_MSG_SZ(32)-1:0]   cacheresp_msg,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,
    output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg,

    input       [2:0]  state,
    input              memreq_en,
    input              tag_wen,
    input              data_wen,
    input              write_data_mux_sel,
    input              miss,
    input              refill_cnt_en,
    input              refill_cnt_clr,
    
    input              cachereq_type,
    input              evict_sel,

    output             type,
    output             tag_match,
    output             valid_bit,
    output             dirty_bit,
    output reg  [4:0]  refill_counter,

    output [`CL_IDX_BITS-1:0] tag_addr,
    output [22:0]             tag_wdata,
    input  [22:0]             tag_rdata,
    output [`CL_IDX_BITS-1:0] data_addr,
    output [`CL_BLK_SIZE-1:0] data_wdata,
    input  [`CL_BLK_SIZE-1:0] data_rdata
);

    // 1. Input Unpacking
    wire        memreq_type; 
    wire [31:0] memreq_addr_comb; 
    wire [1:0]  memreq_len;
    wire [31:0] memreq_data;

    vc_MemReqMsgFromBits#(32,32) memreq_unpack (
        .bits (memreq_msg),
        .type (memreq_type),
        .addr (memreq_addr_comb),
        .len  (memreq_len),
        .data (memreq_data)
    );

    wire [31:0] cacheresp_data = cacheresp_msg[31:0]; 

    // 2. Request Registers
    reg         memreq_type_reg;
    reg [31:0]  memreq_addr_reg;
    reg [1:0]   memreq_len_reg; 
    reg [31:0]  memreq_data_reg;

    always @(posedge clk) begin
        if (reset) begin
             memreq_type_reg <= 0;
             memreq_addr_reg <= 0;
             memreq_len_reg  <= 0;
             memreq_data_reg <= 0;
        end else if (memreq_en) begin
             memreq_type_reg <= memreq_type;
             memreq_addr_reg <= memreq_addr_comb;
             memreq_len_reg  <= memreq_len;
             memreq_data_reg <= memreq_data;
        end
    end

    wire [`CL_OFF_BITS-1:0] offset = memreq_addr_reg[5:0];
    wire [`CL_IDX_BITS-1:0] index  = memreq_addr_reg[10:6];
    wire [`CL_TAG_BITS-1:0] tag    = memreq_addr_reg[31:11];

    // 3. Address Mux
    wire [`CL_IDX_BITS-1:0] index_comb = memreq_addr_comb[10:6];
    
    // Only read from index_comb if state is IDLE AND request is valid
    wire use_comb = (state == 3'd0) && memreq_val;
    assign tag_addr  = (use_comb) ? index_comb : index;
    assign data_addr = (use_comb) ? index_comb : index;

    // 4. Tag Check & Dirty Logic
    wire [`CL_TAG_BITS-1:0] read_tag;
    assign valid_bit = tag_rdata[22];
    assign dirty_bit = tag_rdata[21];
    assign read_tag  = tag_rdata[20:0];

    assign tag_match = (tag == read_tag) && valid_bit;
    assign type      = (memreq_type_reg == 1'b1); 

    // 5. Data Read Mux
    reg [31:0] read_data_hit;
    wire [3:0] word_select = offset[5:2]; 
    
    always @(*) begin
        read_data_hit = data_rdata[word_select * 32 +: 32];
    end

    // 6. Refill Shifter
    reg [`CL_BLK_SIZE-1:0] refill_data;
    always @(posedge clk) begin
        if (reset) begin
            refill_counter <= 5'd0;
            refill_data    <= 0;
        end else begin
            if (refill_cnt_clr) begin
                refill_counter <= 5'd0;
            end else if (refill_cnt_en) begin
                refill_data[refill_counter * 32 +: 32] <= cacheresp_data;
                refill_counter <= refill_counter + 1;
            end
        end
    end

    // 7. Eviction Data Slice
    reg [31:0] evict_data_slice;
    always @(*) begin
        evict_data_slice = data_rdata[refill_counter[3:0] * 32 +: 32];
    end

    // Read Data Mux (Miss)
    reg [31:0] read_data_miss;
    always @(*) begin
        read_data_miss = refill_data[word_select * 32 +: 32];
    end

    wire [31:0] final_read_data = (miss) ? read_data_miss : read_data_hit;
    
    vc_MemRespMsgToBits#(32) memresp_pack (
        .type (memreq_type_reg), 
        .len  (memreq_len_reg),
        .data (final_read_data),
        .bits (memresp_msg)
    );

    // 8. Write Logic
    wire [`CL_BLK_SIZE-1:0] base_write_data = (write_data_mux_sel) ? refill_data : data_rdata;
    reg  [`CL_BLK_SIZE-1:0] modified_write_data;
    
    always @(*) begin
        modified_write_data = base_write_data;
        if (type) begin
             // Handle Byte/Half/Word writes
             if (memreq_len_reg == 2'b00) // Word
                 modified_write_data[word_select*32 +: 32] = memreq_data_reg;
             else if (memreq_len_reg == 2'b01) // Byte
                 modified_write_data[word_select*32 +: 8] = memreq_data_reg[7:0];
             else if (memreq_len_reg == 2'b10) // Half
                 modified_write_data[word_select*32 +: 16] = memreq_data_reg[15:0];
        end
    end

    assign data_wdata = modified_write_data;
    wire new_dirty = (type); 
    assign tag_wdata = {1'b1, new_dirty, tag};

    // 9. Memory Request Generation
    wire [31:0] refill_req_addr = {tag, index, refill_counter[3:0], 2'b00};
    wire [31:0] evict_req_addr  = {read_tag, index, refill_counter[3:0], 2'b00};
    
    wire [31:0] final_req_addr = (evict_sel) ? evict_req_addr   : refill_req_addr;
    wire [31:0] final_req_data = (evict_sel) ? evict_data_slice : 32'b0;

    vc_MemReqMsgToBits#(32,32) cachereq_pack (
        .type (cachereq_type),
        .addr (final_req_addr),
        .len  (2'b00),
        .data (final_req_data),
        .bits (cachereq_msg)
    );

endmodule

//------------------------------------------------------------------------
// Control Logic
//------------------------------------------------------------------------

module riscv_CacheBaseCtrl (
    input           clk,
    input           reset,

    input           memreq_val,
    output          memreq_rdy,
    output          memresp_val,
    input           memresp_rdy,
    output          cachereq_val,
    input           cachereq_rdy,
    input           cacheresp_val,
    output          cacheresp_rdy,
    
    input           type,           
    input           tag_match,
    input           valid_bit,
    input           dirty_bit,
    input   [4:0]   refill_counter, 

    output  [2:0]   state,
    output reg      memreq_en,
    output reg      tag_wen,
    output reg      data_wen,
    output reg      write_data_mux_sel, 
    output reg      miss,
    output reg      refill_cnt_en,
    output reg      refill_cnt_clr,
    
    output reg      cachereq_type,
    output reg      evict_sel
);

    // FSM States
    localparam IDLE           = 3'b000;
    localparam READ_CACHE     = 3'b001;
    localparam UPDATE_CACHE   = 3'b010;
    localparam READ_MEM_REQ   = 3'b011;
    localparam READ_MEM_RESP  = 3'b100;
    localparam DONE           = 3'b101;
    localparam EVICT_REQ      = 3'b110; 
    localparam EVICT_RESP     = 3'b111;

    reg [2:0] curr_state, next_state;

    assign state = curr_state;

    always @(posedge clk) begin
        if (reset) curr_state <= IDLE;
        else       curr_state <= next_state;
    end

    // State Transitions
    always @(*) begin
        next_state = curr_state;
        
        case (curr_state)
            IDLE: begin
            
                if (memreq_val) next_state = READ_CACHE;
            end

            READ_CACHE: begin
                if (tag_match && valid_bit) begin
                    // Hit
                    if (type) begin
                        next_state = UPDATE_CACHE; 
                    end else begin
                        // Read Hit
                        // Handshaking: If data accepted (rdy), check for new req (val)
                        if (memresp_rdy) begin
                            if (memreq_val) next_state = READ_CACHE;
                            else            next_state = IDLE;
                        end else begin
                            next_state = READ_CACHE; // Stall until data taken
                        end
                    end
                end else begin
                    // Miss
                    if (valid_bit && dirty_bit) 
                        next_state = EVICT_REQ;
                    else
                        next_state = READ_MEM_REQ;
                end
            end

            EVICT_REQ: begin
                if (cachereq_rdy) next_state = EVICT_RESP;
            end
            
            EVICT_RESP: begin
                if (cacheresp_val) begin 
                    if (refill_counter < 15) next_state = EVICT_REQ;
                    else                     next_state = READ_MEM_REQ;
                end
            end

            READ_MEM_REQ: begin
            // 真的送出去一筆 request 才算完成
                if (cachereq_val && cachereq_rdy)
                    next_state = READ_MEM_RESP;
            end

            READ_MEM_RESP: begin
            // 真的接到一筆 response 才動 counter / 決定要不要繼續
                if (cacheresp_val && cacheresp_rdy) begin
                    if (refill_counter < 15)
                    next_state = READ_MEM_REQ;
                    else
                    next_state = UPDATE_CACHE;
                end
            end

            UPDATE_CACHE: begin
                next_state = DONE;
            end
            
            DONE: begin
                if (memresp_rdy) next_state = IDLE;
            end
        endcase
    end
    
    // Output Logic
    reg memreq_rdy_reg;
    reg memresp_val_reg;
    reg cachereq_val_reg;
    reg cacheresp_rdy_reg;

    always @(*) begin
        memreq_rdy_reg     = 0;
        memresp_val_reg    = 0;
        cachereq_val_reg   = 0;
        cacheresp_rdy_reg  = 0;
        memreq_en          = 0;
        tag_wen            = 0;
        data_wen           = 0;
        write_data_mux_sel = 0;
        miss               = 0;
        refill_cnt_en      = 0;
        refill_cnt_clr     = 0;
        
        cachereq_type      = 0; 
        evict_sel          = 0; 

        case (curr_state)
            IDLE: begin
                memreq_rdy_reg = 1; 
                memreq_en      = memreq_val; // Only enable if val is high
                refill_cnt_clr = 1; 
            end

            READ_CACHE: begin
                if (tag_match && valid_bit) begin
                    // Hit
                    if (!type) begin 
                        memresp_val_reg = 1; 
                        // Read Hit Pipelining
                        memreq_rdy_reg  = memresp_rdy; 
                        // Only latch next if current output is accepted AND next input valid
                        memreq_en       = memresp_rdy && memreq_val; 
                    end
                end else begin
                     miss = 1; 
                     refill_cnt_clr = 1;
                end
            end

            EVICT_REQ: begin
                cachereq_val_reg = 1;
                cachereq_type    = 1; 
                evict_sel        = 1; 
                miss             = 1;
            end

            EVICT_RESP: begin
                cacheresp_rdy_reg = 1;
                miss = 1;
                if (cacheresp_val) begin
                    refill_cnt_en = 1;
                end
                if (cacheresp_val && refill_counter == 15) begin
                    refill_cnt_clr = 1; // Clear for next stage (Refill)
                end
            end

            READ_MEM_REQ: begin
                cachereq_val_reg  = 1;
                cacheresp_rdy_reg = 1; // 讓底下 memory 任何舊 response 可以被清掉
                miss = 1;
            end

            READ_MEM_RESP: begin
                cacheresp_rdy_reg = 1; 
                miss = 1;
                if (cacheresp_val) begin
                    refill_cnt_en = 1; 
                end
            end

            UPDATE_CACHE: begin
                tag_wen  = 1;
                data_wen = 1;
                if (refill_counter != 0) begin
                    write_data_mux_sel = 1; 
                    miss = 1;
                end else begin
                    write_data_mux_sel = 0; 
                    miss = 0;
                end
            end

            DONE: begin
                memresp_val_reg = 1; 
                miss = 1; 
                refill_cnt_clr = 1;
            end
        endcase
    end

    assign memreq_rdy    = memreq_rdy_reg;
    assign memresp_val   = memresp_val_reg;
    assign cachereq_val  = cachereq_val_reg;
    assign cacheresp_rdy = cacheresp_rdy_reg;

endmodule

`endif /* RISCV_CACHE_BASE_V */