#include "riscv-macros.h"

TEST_RISCV_BEGIN

  # x10 當 base pointer，不碰 x1
  la   x10, data_base

  # Step 1: 第一次 load，應該 miss + refill，但這裡不管 cache 細節
  lw   x2, 0(x10)              # x2 = 0x11223344

  # Step 2: 第二次 load 同一個位址 → hit
  lw   x3, 0(x10)
  TEST_CHECK_EQ( x3, 0x11223344 )

  # Step 3: 在同一個 block 內做 store hit（乾淨行 → 變 dirty）
  li   x4, 0x55667788
  sw   x4, 4(x10)

  # Step 4: 再 load 回來 → write hit 生效
  lw   x5, 4(x10)
  TEST_CHECK_EQ( x5, 0x55667788 )

TEST_RISCV_END

  .section .data
  .align 4

data_base:
  .word 0x11223344      # 0(x10)
  .word 0x00000000      # 4(x10) 會被改成 0x55667788
