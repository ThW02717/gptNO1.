#include "riscv-macros.h"

TEST_RISCV_BEGIN

  //--------------------------------------------------------------------
  // Part A: Conflict misses (同一個 set 不同 tag)
  //
  // conf_base = A
  // B = A + 2048  (加 2^11, index bits [10:6] 一樣, tag 不一樣)
  // C = A + 4096  (再多一個 tag)
  //
  // Dcache: 4KB, 2-way, 64B block, 32 sets
  // 同一個 set 最多 2 lines, A/B/C 三個輪流塞 → 一定有 conflict eviction
  //--------------------------------------------------------------------

  # A, B, C 三個地址
  la   x8, conf_base      # x8 = A

  li   x9, 2048           # 2^11
  add  x9, x8, x9         # x9 = B = A + 2048

  li   x10, 4096          # 2^12
  add  x10, x8, x10       # x10 = C = A + 4096

  # 寫入三個不同 pattern
  li   x11, 0xA1A1A1A1
  sw   x11, 0(x8)         # A

  li   x12, 0xB2B2B2B2
  sw   x12, 0(x9)         # B

  li   x13, 0xC3C3C3C3
  sw   x13, 0(x10)        # C

  # 現在同一個 set 至少被塞過三個 tag, 一定經歷 miss + eviction
  # 只要 cache + memory 路徑正確, 再 load 回來都必須是原本的值

  lw   x14, 0(x8)
  TEST_CHECK_EQ( x14, 0xA1A1A1A1 )

  lw   x15, 0(x9)
  TEST_CHECK_EQ( x15, 0xB2B2B2B2 )

  lw   x16, 0(x10)
  TEST_CHECK_EQ( x16, 0xC3C3C3C3 )

  //--------------------------------------------------------------------
  // Part B: Capacity misses (working set > cache size)
  //
  // Cache: 64 blocks, 每 block 64B
  // 用 stride = 64B, 從 conf_base 開始踩 80 個 blocks
  // → working set = 80 blocks > 64 blocks, 必然出現 capacity miss
  //--------------------------------------------------------------------

  la   x20, conf_base     # base 指到同一塊 data 區
  li   x21, 0             # i = 0

fill_loop:
  # data = 0x12340000 + i
  li   x22, 0x12340000
  add  x22, x22, x21
  sw   x22, 0(x20)

  addi x20, x20, 64       # 下一個 block (每次跳一個 cache line)
  addi x21, x21, 1        # i++

  li   x23, 80            # 總共寫 80 個 blocks
  blt  x21, x23, fill_loop

  # 回頭檢查前 10 個 blocks 的內容
  la   x20, conf_base
  li   x21, 0             # i = 0

check_loop:
  lw   x24, 0(x20)        # 讀回 block i 的內容

  li   x25, 0x12340000
  add  x25, x25, x21      # 期望值: 0x12340000 + i

  # 這裡不能用 TEST_CHECK_EQ(x24, x25)
  # 因為 value_ 必須是立即數, 只好手寫比較
  li   x29, __LINE__
  bne  x24, x25, _fail

  addi x20, x20, 64       # 下一個 block
  addi x21, x21, 1

  li   x23, 10            # 只檢查前 10 個
  blt  x21, x23, check_loop

TEST_RISCV_END

  //------------------------------------------------------------------
  // Data section
  //------------------------------------------------------------------
  .section .data
  .align 6                 # 64B 對齊，offset bits [5:0] = 0
conf_base:
  .space 8192              # 8KB buffer，給 A/B/C + 80 個 blocks 用
