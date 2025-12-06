#include "riscv-macros.h"

TEST_RISCV_BEGIN

  li   x1, 0x12345678

  # Part A: conflict misses

  la   x8, conf_base
  li   x9, 2048
  add  x9, x8, x9
  li   x10, 4096
  add  x10, x8, x10

  li   x11, 0xA1A1A1A1
  sw   x11, 0(x8)
  li   x12, 0xB2B2B2B2
  sw   x12, 0(x9)
  li   x13, 0xC3C3C3C3
  sw   x13, 0(x10)

  li   x20, 4

conflict_loop:
  lw   x14, 0(x8)
  TEST_CHECK_EQ( x14, 0xA1A1A1A1 )

  lw   x15, 0(x9)
  TEST_CHECK_EQ( x15, 0xB2B2B2B2 )

  lw   x16, 0(x10)
  TEST_CHECK_EQ( x16, 0xC3C3C3C3 )

  addi x20, x20, -1
  bnez x20, conflict_loop

  # Part B: capacity misses (96 blocks, all same pattern)

  la   x21, conf_base
  li   x22, 64
  li   x23, 96
  li   x25, 0x20000000

capacity_store_loop:
  sw   x25, 0(x21)
  add  x21, x21, x22
  addi x23, x23, -1
  bnez x23, capacity_store_loop

  la   x21, conf_base
  li   x22, 64
  li   x23, 96

capacity_load1_loop:
  lw   x27, 0(x21)
  TEST_CHECK_EQ( x27, 0x20000000 )
  add  x21, x21, x22
  addi x23, x23, -1
  bnez x23, capacity_load1_loop

  la   x21, conf_base
  li   x22, 64
  li   x23, 96

capacity_load2_loop:
  lw   x27, 0(x21)
  TEST_CHECK_EQ( x27, 0x20000000 )
  add  x21, x21, x22
  addi x23, x23, -1
  bnez x23, capacity_load2_loop

  TEST_CHECK_EQ( x1, 0x12345678 )

TEST_RISCV_END

  .section .data
  .align 6
conf_base:
  .space 8192
