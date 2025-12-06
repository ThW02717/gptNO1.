#include "riscv-macros.h"

TEST_RISCV_BEGIN

  li   x1, 0x12345678

  # init: arr[i] = i, i=0..127

  la   x8, rand_base
  li   x9, 4
  li   x10, 128
  li   x11, 0

init_loop:
  sw   x11, 0(x8)
  add  x8,  x8,  x9
  addi x11, x11, 1
  addi x10, x10, -1
  bnez x10, init_loop

  # sum1 = sum arr[i]

  la   x8, rand_base
  li   x10, 128
  li   x5, 0

sum1_loop:
  lw   x12, 0(x8)
  add  x5,  x5,  x12
  add  x8,  x8,  x9
  addi x10, x10, -1
  bnez x10, sum1_loop

  TEST_CHECK_EQ( x5, 8128 )      # 0+1+...+127 = 8128

  # scale: arr[i] = 2*arr[i]

  la   x8, rand_base
  li   x10, 128

scale_loop:
  lw   x12, 0(x8)
  add  x12, x12, x12
  sw   x12, 0(x8)
  add  x8,  x8,  x9
  addi x10, x10, -1
  bnez x10, scale_loop

  # sum2 = sum arr[i] = 2 * 8128 = 16256

  la   x8, rand_base
  li   x10, 128
  li   x6, 0

sum2_loop:
  lw   x12, 0(x8)
  add  x6,  x6,  x12
  add  x8,  x8,  x9
  addi x10, x10, -1
  bnez x10, sum2_loop

  TEST_CHECK_EQ( x6, 16256 )

  TEST_CHECK_EQ( x1, 0x12345678 )

TEST_RISCV_END

.section .data
.align 6
rand_base:
  .space 1024
