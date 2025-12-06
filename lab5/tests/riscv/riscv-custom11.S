#include "riscv-macros.h"

TEST_RISCV_BEGIN

  li   x1, 0x12345678

  la   x8, stride_base
  li   x9, 4
  li   x10, 32
  li   x11, 0

init_loop:
  sw   x11, 0(x8)
  add  x8,  x8,  x9
  addi x11, x11, 1
  addi x10, x10, -1
  bnez x10, init_loop

  la   x8, stride_base
  li   x9, 4
  li   x10, 32
  li   x5, 0

sum1_loop:
  lw   x12, 0(x8)
  add  x5,  x5,  x12
  add  x8,  x8,  x9
  addi x10, x10, -1
  bnez x10, sum1_loop

  TEST_CHECK_EQ( x5, 0x1F0 )

  la   x8, stride_base
  li   x9, 8
  li   x10, 16
  li   x6, 0

sum2_loop:
  lw   x12, 0(x8)
  add  x6,  x6,  x12
  add  x8,  x8,  x9
  addi x10, x10, -1
  bnez x10, sum2_loop

  TEST_CHECK_EQ( x6, 0xF0 )

  la   x8, stride_base
  addi x8, x8, 4
  li   x9, 32
  li   x10, 4
  li   x7, 0

sum3_loop:
  lw   x12, 0(x8)
  add  x7,  x7,  x12
  add  x8,  x8,  x9
  addi x10, x10, -1
  bnez x10, sum3_loop

  TEST_CHECK_EQ( x7, 0x34 )

  la   x8, stride_base
  la   x13, stride_base
  li   x9, 4
  li   x10, 32
  li   x18, 0

mix_loop:
  lw   x12, 0(x8)
  add  x18, x18, x12
  lw   x12, 4(x8)
  add  x18, x18, x12
  lw   x12, 8(x8)
  add  x18, x18, x12
  lw   x12, 12(x8)
  add  x18, x18, x12

  lw   x12, 0(x13)
  add  x18, x18, x12
  add  x13, x13, x9

  addi x10, x10, -1
  bnez x10, mix_loop

  TEST_CHECK_EQ( x18, 0x2B0 )
  TEST_CHECK_EQ( x1, 0x12345678 )

TEST_RISCV_END

.section .data
.align 6
stride_base:
  .space 128
