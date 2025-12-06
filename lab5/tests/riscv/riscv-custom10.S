#include "riscv-macros.h"

TEST_RISCV_BEGIN

  li   x1, 0x12345678



  la   x8, rand_base      # base
  li   x9, 32             # N = 32
  li   x10, 0             # i = 0
  li   x11, 0x1000        # pattern base

store_loop:
  li   x12, 13
  mul  x13, x10, x12      # x13 = i * 13
  andi x13, x13, 31       # idx = (i*13) & 31
  slli x14, x13, 2        # offset = idx * 4
  add  x15, x8,  x14      # addr = base + offset

  add  x16, x11, x10      # data = 0x1000 + i
  sw   x16, 0(x15)

  addi x10, x10, 1
  blt  x10, x9, store_loop


  la   x8, rand_base
  li   x9, 32
  li   x10, 0
  li   x5, 0

sum1_loop:
  lw   x12, 0(x8)
  add  x5,  x5,  x12
  addi x8,  x8,  4
  addi x10, x10, 1
  blt  x10, x9, sum1_loop

  TEST_CHECK_EQ( x5, 0x201f0 )    # 32*(0x1000) + sum(0..31)



  la   x8, rand_base
  li   x9, 32
  li   x10, 0

update_loop:
  li   x12, 7
  mul  x13, x10, x12      # i * 7
  addi x13, x13, 5        # i * 7 + 5
  andi x13, x13, 31       # idx = (7*i+5) & 31
  slli x14, x13, 2        # offset = idx * 4
  la   x15, rand_base
  add  x15, x15, x14

  lw   x16, 0(x15)
  addi x16, x16, 1
  sw   x16, 0(x15)

  addi x10, x10, 1
  blt  x10, x9, update_loop


  la   x8, rand_base
  li   x9, 32
  li   x10, 0
  li   x6, 0

sum2_loop:
  lw   x12, 0(x8)
  add  x6,  x6,  x12
  addi x8,  x8,  4
  addi x10, x10, 1
  blt  x10, x9, sum2_loop

  TEST_CHECK_EQ( x6, 0x20210 )    # 0x201f0 + 32 * 1

  TEST_CHECK_EQ( x1, 0x12345678 )

TEST_RISCV_END

.section .data
.align 6
rand_base:
  .space 128              # 32 words
