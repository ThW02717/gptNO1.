#=========================================================================
# riscv-cache-miss-refill.S
# Read & write misses with refills (with & without eviction)
#=========================================================================

#include "riscv-macros.h"

TEST_RISCV_BEGIN

# ----------------------------------------------------------------------
# Part 1: Misses without eviction
#  - Case 1A: Read miss + refill (cold load)
#  - Case 1B: Write miss + refill (cold store-then-load)
# ----------------------------------------------------------------------

  # ---- Case 1A: Read miss, no eviction ----
  # memory: miss_rd_base = 0x11112222

  la    x10, miss_rd_base       # x10 = &miss_rd_base
  lw    x11, 0(x10)             # first access, must be a miss+refill
  TEST_CHECK_EQ( x11, 0x11112222 )

  # ---- Case 1B: Write miss, no eviction ----
  # 初值是 0，第一次就是 write miss + refill (write-allocate)

  la    x12, miss_wr_base       # x12 = &miss_wr_base
  li    x13, 0x33334444
  sw    x13, 0(x12)             # cold store, write miss + refill
  lw    x14, 0(x12)             # should read back what we just stored
  TEST_CHECK_EQ( x14, 0x33334444 )

# ----------------------------------------------------------------------
# Part 2: Misses WITH eviction (same set, 2-way, 64B block)
#
#  - 三個 block：setA0, setA1, setA2
#  - 透過 .align 11 + .space 2048-4 讓：
#      addr(setA1) = addr(setA0) + 2048
#      addr(setA2) = addr(setA1) + 2048
#    → index bits [10:6] 相同，tag 不同 → 同一個 set
#
#  流程：
#   1. 讀 setA0  → read miss + refill (no eviction，因為 cache 空的)
#   2. 讀 setA1  → read miss + refill (另一個 way，仍然無 eviction)
#   3. 對 setA0 寫入 → write hit，讓這條 line 變 dirty
#   4. 對 setA2 做「第一次存取」：
#        - 這時同一個 set 已經塞滿兩條 (setA0,setA1)
#        - setA2 的第一次存取會是 miss+refill+eviction
#          （victim 可能是 setA0 或 setA1，實作看 LRU）
#   5. 之後再去讀 setA0 / setA1，資料都要正確
#      → 如果 victim 是 dirty 的 setA0，必須有正確 write-back
# ----------------------------------------------------------------------

  # ---- Step 1: read miss on setA0 (no eviction yet) ----
  la    x20, setA0
  lw    x21, 0(x20)             # miss + refill into some way
  TEST_CHECK_EQ( x21, 0xA0A0A0A0 )

  # ---- Step 2: read miss on setA1 (still no eviction,第二個 way) ----
  la    x22, setA1
  lw    x23, 0(x22)
  TEST_CHECK_EQ( x23, 0xB1B1B1B1 )

  # ---- Step 3: make setA0 dirty (write hit on cached line) ----
  li    x24, 0xDEADBEAF
  sw    x24, 0(x20)             # write hit on setA0 → dirty line

  # 再讀一次，確保 dirty data 正確存在 cache 裡
  lw    x25, 0(x20)
  TEST_CHECK_EQ( x25, 0xDEADBEAF )

  # ---- Step 4: access setA2 to force eviction within the same set ----
  # 現在同一個 set 已經有 setA0、setA1 兩條 line
  # 第一次碰 setA2，會是 miss+refill，一定會 evict 其中一條
  # （victim clean 或 dirty 視 LRU 與實作）

  la    x26, setA2

  # 這裡直接做「write miss」：第一次就是 store
  li    x27, 0xC2C2C2C2
  sw    x27, 0(x26)             # write miss + refill + eviction

  # 讀回來確認 write miss 成功
  lw    x28, 0(x26)
  TEST_CHECK_EQ( x28, 0xC2C2C2C2 )

  # ---- Step 5: 再讀回 setA0 / setA1，確認資料完全正確 ----
  #
  # 不管 LRU 把誰踢出去：
  #   - setA0 原本被我們改成 0xDEADBEAF
  #   - setA1 一直是 0xB1B1B1B1（乾淨）
  #
  # 如果 victim 是 dirty 的 setA0：
  #   → 必須 write-back 到 memory
  #   → 這裡再 lw setA0，一樣要看到 0xDEADBEAF
  #
  # 如果 victim 是 setA1：
  #   → setA1 會從 memory 或 victim-cache 撈回來
  #   → 這裡再 lw setA1，要看到 0xB1B1B1B1
  #
  # 我們兩個都檢查，確保「有 eviction 的 miss 路徑」沒有壞掉資料。

  lw    x5,  0(x20)             # reload setA0
  TEST_CHECK_EQ( x5, 0xDEADBEAF )

  lw    x6,  0(x22)             # reload setA1
  TEST_CHECK_EQ( x6, 0xB1B1B1B1 )

TEST_RISCV_END

# ----------------------------------------------------------------------
# Data section
# ----------------------------------------------------------------------

  .section .data
  .align 4

# ---- Part 1 data: misses without eviction ----

miss_rd_base:
  .word 0x11112222            # 用來測 read miss + refill
  .space 60                   # 填滿一個 64B block，其實沒一定要，但順手

miss_wr_base:
  .word 0x00000000            # 初值不重要，我們會用 write miss 蓋掉

# ---- Part 2 data: 三個 block 在同一個 set ----
# 利用 .align 11 (2KB 對齊) + 每個 label 間隔 2048 bytes
# → index bits [10:6] 相同、offset 相同、tag 不同

  .align 11                   # 對齊到 2048 bytes 邊界
setA0:
  .word 0xA0A0A0A0
  .space 2048-4               # 下一個 label 距離 2048 bytes

setA1:
  .word 0xB1B1B1B1
  .space 2048-4

setA2:
  .word 0xC2C2C2C2
  # 後面不用特別填，這裡只用到第一個 word
