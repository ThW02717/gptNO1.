//=========================================================================
// Victim Cache (2-Entry Fully Associative, LRU) with Eviction Buffer
// Key = addr[31:6] (26 bits)
// Adds: victim_block_addr output for correct tag reconstruction in L1
//=========================================================================

`ifndef RISCV_VICTIM_CACHE_V
`define RISCV_VICTIM_CACHE_V

`include "riscvbc-CacheMsg.v"
`include "vc-RAMs.v"

module riscv_VictimCache
(
    input  clk,
    input  reset,

    // ---------------- From D-Cache ----------------
    input         dcache_evict_val,       // dcache send to vc cache
    input  [31:0] dcache_evict_addr,     // block-base address
    input  [511:0] dcache_evict_data,    // block data


    // Miss probe from D-cache
    input         dcache_refill_val, // dcache ask: do you have this block?
    input  [31:0] dcache_refill_addr, // victim use this to check block

    // ---------------- To D-Cache ----------------
    output reg         victim_hit, // yeah find what you want
    output reg [511:0] victim_read_data, // this is what you looking for
    output reg [25:0]  victim_block_addr,  // and this is where it is

    // ---------------- To Main Memory ----------------
    output wire        mem_evict_val, // gonna write back to mem
    input              mem_evict_rdy, // dram: i m ready
    output wire [31:0] mem_evict_addr, // who's gonna wb to dram
    output wire [511:0] mem_evict_data // what's inside
);

  //----------------------------------------------------------------------
  // RAM entries
  //----------------------------------------------------------------------

  wire [26:0] tag0_rdata, tag1_rdata;
  reg  [26:0] tag0_wdata, tag1_wdata;

  wire [511:0] data0_rdata, data1_rdata;
  reg  [511:0] data0_wdata, data1_wdata;

  reg tag0_wen, tag1_wen;
  reg data0_wen, data1_wen;

  // Entry0
  vc_RAM_rst_1w1r_pf #(.DATA_SZ(27), .ENTRIES(1), .ADDR_SZ(1), .RESET_VALUE(0))
    vc_tag0 ( .clk(clk), .reset_p(reset),
              .raddr(1'b0), .rdata(tag0_rdata),
              .wen_p(tag0_wen), .waddr_p(1'b0), .wdata_p(tag0_wdata) );

  vc_RAM_rst_1w1r_pf #(.DATA_SZ(512), .ENTRIES(1), .ADDR_SZ(1), .RESET_VALUE(0))
    vc_data0 ( .clk(clk), .reset_p(reset),
               .raddr(1'b0), .rdata(data0_rdata),
               .wen_p(data0_wen), .waddr_p(1'b0), .wdata_p(data0_wdata) );

  // Entry1
  vc_RAM_rst_1w1r_pf #(.DATA_SZ(27), .ENTRIES(1), .ADDR_SZ(1), .RESET_VALUE(0))
    vc_tag1 ( .clk(clk), .reset_p(reset),
              .raddr(1'b0), .rdata(tag1_rdata),
              .wen_p(tag1_wen), .waddr_p(1'b0), .wdata_p(tag1_wdata) );

  vc_RAM_rst_1w1r_pf #(.DATA_SZ(512), .ENTRIES(1), .ADDR_SZ(1), .RESET_VALUE(0))
    vc_data1 ( .clk(clk), .reset_p(reset),
               .raddr(1'b0), .rdata(data1_rdata),
               .wen_p(data1_wen), .waddr_p(1'b0), .wdata_p(data1_wdata) );

  //----------------------------------------------------------------------
  // Tag decode
  //----------------------------------------------------------------------
  // get{valid, block addr}
  wire        valid0 = tag0_rdata[26];
  wire [25:0] addr0  = tag0_rdata[25:0];

  wire        valid1 = tag1_rdata[26];
  wire [25:0] addr1  = tag1_rdata[25:0];

  wire [25:0] search_tag = dcache_refill_addr[31:6];

  wire hit0 = valid0 && (addr0 == search_tag);
  wire hit1 = valid1 && (addr1 == search_tag);

  //----------------------------------------------------------------------
  // LRU bit: 0=entry0, 1=entry1
  //----------------------------------------------------------------------

  reg lru;// entry0 or entry1 to evict
  reg lru_next;// 怪怪的

  //----------------------------------------------------------------------
  // Eviction buffer to memory
  //----------------------------------------------------------------------
  // Squeeze to LRU to MEM
  reg        evict_buf_val;
  reg [31:0] evict_buf_addr;
  reg [511:0] evict_buf_data;

  assign mem_evict_val  = evict_buf_val;
  assign mem_evict_addr = evict_buf_addr;
  assign mem_evict_data = evict_buf_data;

  //----------------------------------------------------------------------
  // Combinational logic
  //----------------------------------------------------------------------

  always @(*) begin
    // defaults
    victim_hit        = 1'b0;
    victim_read_data  = 512'b0;
    victim_block_addr = 26'b0;

    tag0_wen   = 1'b0; data0_wen = 1'b0;
    tag1_wen   = 1'b0; data1_wen = 1'b0;

    tag0_wdata = tag0_rdata;
    tag1_wdata = tag1_rdata;
    data0_wdata = data0_rdata;
    data1_wdata = data1_rdata;

    lru_next = lru;

    // -------------------------------------------------------
    // VC lookup for swap
    // -------------------------------------------------------
    // The hit block will be invalidate and it will be the block
    // to be refill next time
    if (dcache_refill_val) begin
      if (hit0 || hit1) begin
        victim_hit       = 1'b1;
        victim_read_data = hit0 ? data0_rdata : data1_rdata;
        victim_block_addr = hit0 ? addr0 : addr1;

        // invalidate the hit entry
        if (hit0) begin
          tag0_wen   = 1'b1;
          tag0_wdata = {1'b0, addr0};
          lru_next   = 1'b0;
        end else begin
          tag1_wen   = 1'b1;
          tag1_wdata = {1'b0, addr1};
          lru_next   = 1'b1;
        end
      end
    end

    // -------------------------------------------------------
    // Incoming eviction from L1
    // -------------------------------------------------------
    if (dcache_evict_val) begin

      if (lru == 1'b0) begin
        // evict entry0 if needed
        // actual buffer latch in sequential block

        tag0_wen   = 1'b1;
        data0_wen  = 1'b1;

        tag0_wdata  = {1'b1, dcache_evict_addr[31:6]};
        data0_wdata = dcache_evict_data;

        lru_next = 1'b1;
      end else begin
        tag1_wen   = 1'b1;
        data1_wen  = 1'b1;

        tag1_wdata  = {1'b1, dcache_evict_addr[31:6]};
        data1_wdata = dcache_evict_data;

        lru_next = 1'b0;
      end
    end
  end

  //----------------------------------------------------------------------
  // Sequential logic (LRU & eviction buffer)
  //----------------------------------------------------------------------

  always @(posedge clk) begin
    if (reset) begin
      lru <= 1'b0;

      evict_buf_val  <= 1'b0;
      evict_buf_addr <= 32'b0;
      evict_buf_data <= 512'b0;
    end
    else begin
      lru <= lru_next;

      // Handle eviction buffer
      // buffer is empty, and cache wants to write into vc cache
      if (!evict_buf_val && dcache_evict_val) begin
        if (lru == 1'b0 && valid0) begin
          evict_buf_val  <= 1'b1;
          evict_buf_addr <= {addr0, 6'b0};
          evict_buf_data <= data0_rdata;
        end
        else if (lru == 1'b1 && valid1) begin
          evict_buf_val  <= 1'b1;
          evict_buf_addr <= {addr1, 6'b0};
          evict_buf_data <= data1_rdata;
        end
      end
      else if (evict_buf_val && mem_evict_rdy) begin
        evict_buf_val <= 1'b0;
      end
    end
  end
  // --------------------------------------------------------------------
  // Victim Cache Debug Prints (用 +vcdebug 控制)
  // --------------------------------------------------------------------
  always @(posedge clk) begin
    if (!reset && $test$plusargs("vcdebug")) begin

      // 1) L1 -> VC eviction
      if (dcache_evict_val) begin
        $display("[VC %0t] EVICT L1->VC : dcache_evict_addr=%h data[31:0]=%h | lru=%0d valid0=%0d addr0=%h valid1=%0d addr1=%h",
                 $time,
                 dcache_evict_addr,
                 dcache_evict_data[31:0],
                 lru,
                 valid0, addr0,
                 valid1, addr1 );
      end

      // 2) D-Cache miss 來 probe Victim
      if (dcache_refill_val) begin
        $display("[VC %0t] REFILL probe : refill_addr=%h search_tag=%h | v0=%0d a0=%h v1=%0d a1=%h | hit0=%0d hit1=%0d victim_hit=%0d victim_data[31:0]=%h",
                 $time,
                 dcache_refill_addr,
                 search_tag,
                 valid0, addr0,
                 valid1, addr1,
                 hit0, hit1,
                 victim_hit,
                 victim_read_data[31:0] );
      end

      // 3) VC -> MEM writeback
      if (evict_buf_val && mem_evict_rdy) begin
        $display("[VC %0t] WRITEBACK VC->MEM : evict_buf_addr=%h data[31:0]=%h",
                 $time,
                 evict_buf_addr,
                 evict_buf_data[31:0] );
      end
    end
  end

  

endmodule

`endif
