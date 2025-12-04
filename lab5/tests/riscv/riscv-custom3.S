#include "riscv-macros.h"

TEST_RISCV_BEGIN
  li x1, 0x12345678
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
  TEST_CHECK_EQ( x1, 0x12345678 )
  
TEST_RISCV_END

  //------------------------------------------------------------------
  // Data section
  //------------------------------------------------------------------
  .section .data
  .align 6                 # 64B 對齊，offset bits [5:0] = 0
conf_base:
  .space 8192              # 8KB buffer，給 A/B/C + 80 個 blocks 用
