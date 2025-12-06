//=========================================================================
// Cache Alternative Design 
//=========================================================================

`ifndef RISCV_CACHE_ALT_V
`define RISCV_CACHE_ALT_V

`include "riscvbc-CacheMsg.v"
`include "vc-RAMs.v"
`include "riscvbc-VictimCache.v"

//-------------------------------------------------------------------------
// Top Module
//-------------------------------------------------------------------------

module riscv_CacheAlt (
    input  clk,
    input  reset,

    // Processor Interface
    input                       memreq_val,
    output                      memreq_rdy,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,

    output                      memresp_val,
    input                       memresp_rdy,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,

    // Memory Interface
    output                      cachereq_val,
    input                       cachereq_rdy,
    output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg,

    input                       cacheresp_val,
    output                      cacheresp_rdy,
    input  [`VC_MEM_RESP_MSG_SZ(32)-1:0]   cacheresp_msg
);
  wire [31:0] vc_refill_addr;
  
  //----------------------------------------------------------------------  
  // Wires
  //----------------------------------------------------------------------  

  // Control Signals
  wire        memreq_en;
  wire        tag_wen;
  wire        data_wen;
  wire [1:0]  write_data_mux_sel;
  wire        miss;
  wire        refill_cnt_en;
  wire        refill_cnt_clr;
  wire        cachereq_type;
  wire        evict_sel;

  wire        way_sel;
  wire        lru_update;

  // Status Signals
  wire [3:0]  state;
  wire        type;
  wire        hit;
  wire        hit0;
  wire        hit1;
  wire        victim_dirty;
  wire        lru_victim;

  wire [4:0]  refill_counter;

  // Victim Cache Interface Wires
  wire        vc_evict_val;
  wire        vc_refill_val;
  wire        vc_hit;
  wire [511:0] vc_read_data;
  wire [31:0]  d_evict_addr;
  wire [511:0] d_evict_data;

  // VC to Memory Wires
  wire        vc_mem_req_val;
  wire [31:0] vc_mem_req_addr;
  wire [511:0] vc_mem_req_data;

  // RAM Interface Wires
  wire [`IDX_BITS-1:0]   tag_addr;
  wire [`IDX_BITS-1:0]   data_addr;

  // Way 0
  wire [22:0]            tag0_wdata;
  wire [22:0]            tag0_rdata;
  wire [`BLK_SIZE-1:0]   data0_wdata;
  wire [`BLK_SIZE-1:0]   data0_rdata;
  wire                   tag0_wen;
  wire                   data0_wen;

  // Way 1
  wire [22:0]            tag1_wdata;
  wire [22:0]            tag1_rdata;
  wire [`BLK_SIZE-1:0]   data1_wdata;
  wire [`BLK_SIZE-1:0]   data1_rdata;
  wire                   tag1_wen;
  wire                   data1_wen;

  //----------------------------------------------------------------------  
  // Victim Cache Instance
  //----------------------------------------------------------------------  

  riscv_VictimCache victim_cache (
      .clk                (clk),
      .reset              (reset),

      // D-cache -> Victim Cache (Evict)
      .dcache_evict_val   (vc_evict_val),
      .dcache_evict_addr  (d_evict_addr),
      .dcache_evict_data  (d_evict_data),

      // D-cache -> Victim Cache (Refill Probe)
      .dcache_refill_val  (vc_refill_val),
      .dcache_refill_addr (vc_refill_addr),

      .victim_hit         (vc_hit),
      .victim_read_data   (vc_read_data),

      // Victim Cache -> Memory (Evict to DRAM)
      .mem_evict_val      (vc_mem_req_val),
      .mem_evict_rdy      (cachereq_rdy),
      .mem_evict_addr     (vc_mem_req_addr),
      .mem_evict_data     (vc_mem_req_data)
  );

  //----------------------------------------------------------------------  
  // Datapath Instance
  //----------------------------------------------------------------------  

  riscv_CacheAltDpath dpath
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
    .write_data_mux_sel (write_data_mux_sel),
    .miss               (miss),
    .refill_cnt_en      (refill_cnt_en),
    .refill_cnt_clr     (refill_cnt_clr),
    .cachereq_type      (cachereq_type),
    .evict_sel          (evict_sel),

    // Alt Ports
    .way_sel            (way_sel),
    .lru_update         (lru_update),
    .hit                (hit),
    .hit0               (hit0),
    .hit1               (hit1),
    .victim_dirty       (victim_dirty),
    .lru_victim         (lru_victim),

    .type               (type),
    .refill_counter     (refill_counter),

    // Victim Cache Interactions
    .vc_hit             (vc_hit),
    .vc_read_data       (vc_read_data),
    .d_evict_addr       (d_evict_addr),
    .d_evict_data       (d_evict_data),

    // VC Memory Passthrough
    .vc_mem_req_val     (vc_mem_req_val),
    .vc_mem_req_addr    (vc_mem_req_addr),
    .vc_mem_req_data    (vc_mem_req_data),
    .vc_refill_addr     (vc_refill_addr),
    
    // RAM Connections
    .tag_addr           (tag_addr),
    .data_addr          (data_addr),

    .tag0_wdata         (tag0_wdata),
    .tag0_rdata         (tag0_rdata),
    .data0_wdata        (data0_wdata),
    .data0_rdata        (data0_rdata),

    .tag1_wdata         (tag1_wdata),
    .tag1_rdata         (tag1_rdata),
    .data1_wdata        (data1_wdata),
    .data1_rdata        (data1_rdata)
  );

  //----------------------------------------------------------------------  
  // Control
  //----------------------------------------------------------------------  

  riscv_CacheAltCtrl ctrl
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
    .hit                (hit),
    .hit0               (hit0),
    .hit1               (hit1),
    .victim_dirty       (victim_dirty),
    .lru_victim         (lru_victim),
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
    .evict_sel          (evict_sel),
    .way_sel            (way_sel),
    .lru_update         (lru_update),

    // VC Controls
    .vc_hit             (vc_hit),
    .vc_mem_req_val     (vc_mem_req_val),
    .vc_evict_val       (vc_evict_val),
    .vc_refill_val      (vc_refill_val)
  );

  //----------------------------------------------------------------------  
  // RAM Modules
  //----------------------------------------------------------------------  

  assign tag0_wen  = tag_wen  && (way_sel == 1'b0);
  assign data0_wen = data_wen && (way_sel == 1'b0);

  assign tag1_wen  = tag_wen  && (way_sel == 1'b1);
  assign data1_wen = data_wen && (way_sel == 1'b1);

  vc_RAM_rst_1w1r_pf #(
    .DATA_SZ(`BLK_SIZE), .ENTRIES(32), .ADDR_SZ(`IDX_BITS), .RESET_VALUE(0)
  ) _data_ram0 (
    .clk    (clk),
    .reset_p(reset),
    .raddr  (data_addr),      
    .rdata  (data0_rdata),
    .wen_p  (data0_wen),
    .waddr_p(data_addr),
    .wdata_p(data0_wdata)
  );

  vc_RAM_rst_1w1r_pf #(
    .DATA_SZ(23), .ENTRIES(32), .ADDR_SZ(`IDX_BITS), .RESET_VALUE(0)
  ) _tag_ram0 (
    .clk    (clk),
    .reset_p(reset),
    .raddr  (tag_addr),
    .rdata  (tag0_rdata),
    .wen_p  (tag0_wen),
    .waddr_p(tag_addr),
    .wdata_p(tag0_wdata)
  );

  vc_RAM_rst_1w1r_pf #(
    .DATA_SZ(`BLK_SIZE), .ENTRIES(32), .ADDR_SZ(`IDX_BITS), .RESET_VALUE(0)
  ) _data_ram1 (
    .clk    (clk),
    .reset_p(reset),
    .raddr  (data_addr),      
    .rdata  (data1_rdata),
    .wen_p  (data1_wen),
    .waddr_p(data_addr),
    .wdata_p(data1_wdata)
  );

  vc_RAM_rst_1w1r_pf #(
    .DATA_SZ(23), .ENTRIES(32), .ADDR_SZ(`IDX_BITS), .RESET_VALUE(0)
  ) _tag_ram1 (
    .clk    (clk),
    .reset_p(reset),
    .raddr  (tag_addr),
    .rdata  (tag1_rdata),
    .wen_p  (tag1_wen),
    .waddr_p(tag_addr),
    .wdata_p(tag1_wdata)
  );


    
endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module riscv_CacheAltDpath (
    input           clk,
    input           reset,
    input           memreq_val,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,
    input  [`VC_MEM_RESP_MSG_SZ(32)-1:0]   cacheresp_msg,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,
    output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] cachereq_msg,

    input       [3:0]  state,
    input              memreq_en,
    input       [1:0]  write_data_mux_sel,
    input              miss,
    input              refill_cnt_en,
    input              refill_cnt_clr,
    input              cachereq_type,
    input              evict_sel,

    input              way_sel,
    input              lru_update,

    output             type,
    output             hit,
    output             hit0,
    output             hit1,
    output             victim_dirty,
    output             lru_victim,
    output reg  [4:0]  refill_counter,

    input              vc_hit,
    input [511:0]      vc_read_data,
    output [31:0]      d_evict_addr,
    output [511:0]     d_evict_data,

    input              vc_mem_req_val,
    input [31:0]       vc_mem_req_addr,
    input [511:0]      vc_mem_req_data,

    output [`IDX_BITS-1:0] tag_addr,
    output [`IDX_BITS-1:0] data_addr,
    output [22:0]          tag0_wdata,
    input  [22:0]          tag0_rdata,
    output [`BLK_SIZE-1:0] data0_wdata,
    input  [`BLK_SIZE-1:0] data0_rdata,
    output [22:0]          tag1_wdata,
    input  [22:0]          tag1_rdata,
    output [`BLK_SIZE-1:0] data1_wdata,
    input  [`BLK_SIZE-1:0] data1_rdata,
    output [31:0]          vc_refill_addr
);

 
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


    reg         memreq_type_reg;
    reg [31:0]  memreq_addr_reg;
    reg [1:0]   memreq_len_reg;
    reg [31:0]  memreq_data_reg;

    always @(posedge clk) begin
        if (reset) begin
             memreq_type_reg <= 1'b0;
             memreq_addr_reg <= 32'b0;
             memreq_len_reg  <= 2'b0;
             memreq_data_reg <= 32'b0;
        end else if (memreq_en) begin
             memreq_type_reg <= memreq_type;
             memreq_addr_reg <= memreq_addr_comb;
             memreq_len_reg  <= memreq_len;
             memreq_data_reg <= memreq_data;
        end
    end
    

    wire [`OFF_BITS-1:0] offset = memreq_addr_reg[5:0];
    wire [`IDX_BITS-1:0] index  = memreq_addr_reg[10:6];
    wire [`TAG_BITS-1:0] tag    = memreq_addr_reg[31:11];
    
    assign vc_refill_addr = memreq_addr_reg;
    

    wire [`IDX_BITS-1:0] index_comb = memreq_addr_comb[10:6];
    wire use_comb = (state == 4'd0) && memreq_val;
    assign tag_addr  = (use_comb) ? index_comb : index;
    assign data_addr = (use_comb) ? index_comb : index;

    // ---------------- LRU Logic ----------------
    reg [31:0] lru_bits;

    always @(posedge clk) begin
        if (reset)
            lru_bits <= 32'b0;
        else if (lru_update) begin
            lru_bits[index] <= (way_sel == 1'b0) ? 1'b1 : 1'b0;
        end
    end

    assign lru_victim = lru_bits[index];

    // ---------------- Hit / Miss Logic ----------------
    wire [`TAG_BITS-1:0] read_tag0 = tag0_rdata[20:0];
    wire valid0 = tag0_rdata[22];
    wire dirty0 = tag0_rdata[21];
    assign hit0 = (tag == read_tag0) && valid0;

    wire [`TAG_BITS-1:0] read_tag1 = tag1_rdata[20:0];
    wire valid1 = tag1_rdata[22];
    wire dirty1 = tag1_rdata[21];
    assign hit1 = (tag == read_tag1) && valid1;

    assign hit  = hit0 || hit1;
    assign type = (memreq_type_reg == `WRITE);

    // victim_dirty
    assign victim_dirty = (lru_victim == 1'b0)
                          ? (valid0 & dirty0)
                          : (valid1 & dirty1);

    // ---------------- EVICTION DATA PRE ----------------
    wire [`BLK_SIZE-1:0] victim_data = (lru_victim == 1'b0) ? data0_rdata
                                                            : data1_rdata;
    wire [`TAG_BITS-1:0] victim_tag  = (lru_victim == 1'b0) ? read_tag0
                                                            : read_tag1;

    assign d_evict_data = victim_data;
    assign d_evict_addr = {victim_tag, index, 6'b0};

    // ---------------- Data Read -------------
    wire [`BLK_SIZE-1:0] data_block_hit = (hit0) ? data0_rdata : data1_rdata;
    wire [3:0] word_select = offset[5:2];
    wire [1:0] byte_offset = offset[1:0];

    reg [31:0] read_data_hit;
    reg [31:0] read_data_miss;
    reg [31:0] read_data_vc;
    reg [31:0] raw_word;
    reg [31:0] final_read_data;
    reg [7:0]  load_byte;
    reg [15:0] load_half;

    always @(*) begin
        read_data_hit = data_block_hit[word_select * 32 +: 32];
        read_data_vc  = vc_read_data[word_select * 32 +: 32];
    end

    reg [`BLK_SIZE-1:0] refill_data;
    wire [31:0] cacheresp_data = cacheresp_msg[31:0];

    always @(posedge clk) begin
        if (reset) begin
            refill_counter <= 5'd0;
            refill_data    <= {`BLK_SIZE{1'b0}};
        end else begin
            if (refill_cnt_clr)
                refill_counter <= 5'd0;
            else if (refill_cnt_en) begin
                refill_data[refill_counter * 32 +: 32] <= cacheresp_data;
                refill_counter <= refill_counter + 1'b1;
            end
        end
    end

    always @(*) begin
        read_data_miss = refill_data[word_select * 32 +: 32];
    end

    always @(*) begin
        raw_word = read_data_hit;
    end

    // ---------------- Load Data SB  LB..... ----------------
    always @(*) begin
        final_read_data = raw_word;
        load_byte       = 8'b0;
        load_half       = 16'b0;

        case (memreq_len_reg)
            2'b00: final_read_data = raw_word;
            2'b01: begin
                case (byte_offset)
                    2'b00: load_byte = raw_word[7:0];
                    2'b01: load_byte = raw_word[15:8];
                    2'b10: load_byte = raw_word[23:16];
                    2'b11: load_byte = raw_word[31:24];
                endcase
                final_read_data = {24'b0, load_byte};
            end
            2'b10: begin
                case (byte_offset[1])
                    1'b0: load_half = raw_word[15:0];
                    1'b1: load_half = raw_word[31:16];
                endcase
                final_read_data = {16'b0, load_half};
            end
            default: final_read_data = raw_word;
        endcase
    end

    vc_MemRespMsgToBits#(32) memresp_pack (
        .type (memreq_type_reg),
        .len  (memreq_len_reg),
        .data (final_read_data),
        .bits (memresp_msg)
    );

    // ---------------- Write Data  ----------------
    wire [`BLK_SIZE-1:0] victim_data_read = (way_sel == 1'b0) ? data0_rdata : data1_rdata;
    reg [`BLK_SIZE-1:0] base_write_data;
    
    reg [511:0] vc_read_data_reg;

    always @(posedge clk) begin
        if (state == 4'd2) begin 
            vc_read_data_reg <= vc_read_data;
        end
    end

    always @(*) begin
        case (write_data_mux_sel)
            2'd0: base_write_data = victim_data_read; 
            2'd1: base_write_data = refill_data;      
            2'd2: base_write_data = vc_read_data_reg;
            default: base_write_data = {`BLK_SIZE{1'b0}};
        endcase
    end

    reg  [`BLK_SIZE-1:0] modified_write_data;

    always @(*) begin
        modified_write_data = base_write_data;
        if (type) begin
            case (memreq_len_reg)
                2'b00: modified_write_data[word_select*32 +: 32] = memreq_data_reg;
                2'b01: begin
                    case (byte_offset)
                        2'b00: modified_write_data[word_select*32        +: 8] = memreq_data_reg[7:0];
                        2'b01: modified_write_data[word_select*32 +  8 +: 8] = memreq_data_reg[7:0];
                        2'b10: modified_write_data[word_select*32 + 16 +: 8] = memreq_data_reg[7:0];
                        2'b11: modified_write_data[word_select*32 + 24 +: 8] = memreq_data_reg[7:0];
                    endcase
                end
                2'b10: begin
                    case (byte_offset[1])
                        1'b0: modified_write_data[word_select*32        +: 16] = memreq_data_reg[15:0];
                        1'b1: modified_write_data[word_select*32 + 16 +: 16] = memreq_data_reg[15:0];
                    endcase
                end
            endcase
        end
    end

    assign data0_wdata = modified_write_data;
    assign data1_wdata = modified_write_data;

    wire new_dirty = (type) || (write_data_mux_sel == 2'd2);
    
    assign tag0_wdata = {1'b1, new_dirty, tag};
    assign tag1_wdata = {1'b1, new_dirty, tag};

    // ---------------- Memory Request MUX -------
    wire [31:0] refill_req_addr = {tag, index, refill_counter[3:0], 2'b00};
    wire [31:0] vc_block_base   = vc_mem_req_addr; 
    wire [31:0] vc_word_addr    = { vc_block_base[31:2] + refill_counter[3:0],
                                    2'b00 };
    wire [31:0] final_req_addr  = (evict_sel) ? vc_word_addr
                                              : refill_req_addr;

    wire [31:0] vc_sliced_data  = vc_mem_req_data[refill_counter[3:0]*32 +: 32];
    wire [31:0] final_req_data  = (evict_sel) ? vc_sliced_data
                                              : 32'b0;

    wire final_req_type = (evict_sel) ? `WRITE : `READ;

    vc_MemReqMsgToBits#(32,32) cachereq_pack (
        .type (final_req_type),
        .addr (final_req_addr),
        .len  (2'b00),
        .data (final_req_data),
        .bits (cachereq_msg)
    );

    
endmodule

//------------------------------------------------------------------------
// Control
//------------------------------------------------------------------------

module riscv_CacheAltCtrl (
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
    input           hit,
    input           hit0,
    input           hit1,
    input           victim_dirty,
    input           lru_victim,
    input   [4:0]   refill_counter,

    output  [3:0]   state,
    output reg      memreq_en,
    output reg      tag_wen,
    output reg      data_wen,
    output reg [1:0] write_data_mux_sel,
    output reg      miss,
    output reg      refill_cnt_en,
    output reg      refill_cnt_clr,
    output reg      cachereq_type,
    output reg      evict_sel,
    output reg      way_sel,
    output reg      lru_update,

    // VC Controls
    input           vc_hit,
    input           vc_mem_req_val,
    output reg      vc_evict_val,
    output reg      vc_refill_val
);

    localparam IDLE          = 4'd0;
    localparam READ_CACHE    = 4'd1;
    localparam VC_PROBE      = 4'd2; 
    localparam VC_RESP       = 4'd3; 
    localparam READ_MEM_REQ  = 4'd4;
    localparam READ_MEM_RESP = 4'd5;
    localparam VC_EVICT_REQ  = 4'd6;
    localparam VC_EVICT_RESP = 4'd7;
    localparam UPDATE_CACHE  = 4'd8;
    localparam DONE          = 4'd9;

    reg [3:0] curr_state, next_state;
    assign state = curr_state[3:0];

    always @(posedge clk) begin
        if (reset)
            curr_state <= IDLE;
        else
            curr_state <= next_state;
    end

    // State Transitions
    always @(*) begin
    next_state = curr_state;
    case (curr_state)
        IDLE: begin
        if (memreq_val)
            next_state = READ_CACHE;
        end

        READ_CACHE: begin
        if (hit) begin
            if (type) next_state = UPDATE_CACHE;   // write hit
            else begin
            if (memresp_rdy) next_state = (memreq_val ? READ_CACHE : IDLE);
            else             next_state = READ_CACHE;
            end
        end
        else begin
            next_state = VC_PROBE;
        end
        end

        VC_PROBE: begin
        next_state = VC_RESP;
        end

        VC_RESP: begin
        if (vc_hit_hold) next_state = UPDATE_CACHE;
        else             next_state = READ_MEM_REQ;
        end

        READ_MEM_REQ:  if (cachereq_rdy) next_state = READ_MEM_RESP;
        READ_MEM_RESP: if (cacheresp_val) begin
                         if (refill_counter < 5'd15) next_state = READ_MEM_REQ;
                         else                        next_state = UPDATE_CACHE;
                         end
        
        
        VC_EVICT_REQ:  if (cachereq_rdy) next_state = VC_EVICT_RESP;
        
        VC_EVICT_RESP: begin
                         if (refill_counter < 5'd15) next_state = VC_EVICT_REQ;
                         else                        next_state = DONE;
                       end

        UPDATE_CACHE:  next_state = DONE;

        DONE: begin
        if (vc_mem_req_val)      next_state = VC_EVICT_REQ;
        else if (memresp_rdy)    next_state = IDLE;
        end

        default: next_state = IDLE;
    endcase
    end

    // Output Logic
    reg memreq_rdy_reg;
    reg memresp_val_reg;
    reg cachereq_val_reg;
    reg cacheresp_rdy_reg;
    reg vc_hit_hold;

    always @(posedge clk) begin
    if (reset)
        vc_hit_hold <= 1'b0;
    else begin
        if (curr_state == VC_PROBE)
            vc_hit_hold <= vc_hit;
        else if (curr_state == DONE && memresp_rdy)
            vc_hit_hold <= 1'b0;
        else if (curr_state == IDLE && !memreq_val)
            vc_hit_hold <= 1'b0;
    end
    end

    always @(*) begin
        memreq_rdy_reg     = 1'b0;
        memresp_val_reg    = 1'b0;
        cachereq_val_reg   = 1'b0;
        cacheresp_rdy_reg  = 1'b0;

        memreq_en          = 1'b0;
        tag_wen            = 1'b0;
        data_wen           = 1'b0;
        write_data_mux_sel = 2'd0;
        miss               = 1'b0;
        refill_cnt_en      = 1'b0;
        refill_cnt_clr     = 1'b0;

        cachereq_type      = `READ;
        evict_sel          = 1'b0;
        lru_update         = 1'b0;
        vc_evict_val       = 1'b0;
        vc_refill_val      = 1'b0;

        if (hit) way_sel = (hit1 ? 1'b1 : 1'b0);
        else     way_sel = lru_victim;

        case (curr_state)
            IDLE: begin
            memreq_rdy_reg = 1'b1;
            memreq_en      = memreq_val;
            refill_cnt_clr = 1'b1;
            end

            READ_CACHE: begin
            if (hit) begin
                lru_update = 1'b1;
                if (!type) begin
                memresp_val_reg = 1'b1;
                memreq_rdy_reg  = memresp_rdy;
                memreq_en       = memresp_rdy && memreq_val;
                end
            end
            else begin
                miss           = 1'b1;
                refill_cnt_clr = 1'b1;
            end
            end

            VC_PROBE: begin
            miss          = 1'b1;
            vc_refill_val = 1'b1; 
            end

            VC_RESP: begin
            miss = 1'b1;
            end

            READ_MEM_REQ: begin
            cachereq_val_reg  = 1'b1;
            cacheresp_rdy_reg = 1'b1;
            miss              = 1'b1;
            end

            READ_MEM_RESP: begin
            cacheresp_rdy_reg = 1'b1;
            miss              = 1'b1;
            if (cacheresp_val) refill_cnt_en = 1'b1;
            end

            VC_EVICT_REQ: begin
            cachereq_val_reg = 1'b1;
            evict_sel        = 1'b1;
            miss             = 1'b1;
            cacheresp_rdy_reg = 1'b1;
            end

            VC_EVICT_RESP: begin
            miss      = 1'b1;
            evict_sel = 1'b1;
            refill_cnt_en     = 1'b1;
            cacheresp_rdy_reg = 1'b1;
            
            if (refill_counter == 5'd15) begin
                refill_cnt_clr = 1'b1;
            end
            end

            UPDATE_CACHE: begin
            tag_wen    = 1'b1;
            data_wen   = 1'b1;
            lru_update = 1'b1;

            if (refill_counter != 5'd0) begin
                // Case A: Refill from DRAM
                write_data_mux_sel = 2'd1;
                miss               = 1'b1;
                vc_evict_val       = victim_dirty;
            end
            else if (vc_hit_hold) begin
                // Case B: Swap from VC
                write_data_mux_sel = 2'd2;
                miss               = 1'b1;
                vc_evict_val       = victim_dirty;
            end
            else begin
                // Case C: Write Hit
                write_data_mux_sel = 2'd0;
                miss               = 1'b0;
            end
            end

            DONE: begin
            memresp_val_reg = 1'b1;
            miss            = 1'b0;
            refill_cnt_clr  = 1'b1;
            end
        endcase
    end
    
 
    assign memreq_rdy    = memreq_rdy_reg;
    assign memresp_val   = memresp_val_reg;
    assign cachereq_val  = cachereq_val_reg;
    assign cacheresp_rdy = cacheresp_rdy_reg;

   

endmodule

`endif // RISCV_CACHE_ALT_V