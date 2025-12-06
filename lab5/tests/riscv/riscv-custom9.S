#include "riscv-macros.h"

TEST_RISCV_BEGIN

  li   x1, 0x12345678

  la   x8, simple_base
  li   x9, 4
  li   x10, 16
  li   x11, 0

init_loop:
  sw   x11, 0(x8)
  add  x8,  x8,  x9
  addi x11, x11, 1
  addi x10, x10, -1
  bnez x10, init_loop

  la   x8, simple_base
  li   x10, 16
  li   x5, 0

forward_sum_loop:
  lw   x12, 0(x8)
  add  x5,  x5,  x12
  add  x8,  x8,  x9
  addi x10, x10, -1
  bnez x10, forward_sum_loop

  TEST_CHECK_EQ( x5, 120 )

  la   x8, simple_base
  li   x10, 16
  addi x10, x10, -1
  slli x11, x10, 2
  add  x8,  x8,  x11
  li   x6, 0
  li   x13, 16

backward_sum_loop:
  lw   x12, 0(x8)
  add  x6,  x6,  x12
  addi x13, x13, -1
  addi x8,  x8,  -4
  bnez x13, backward_sum_loop

  TEST_CHECK_EQ( x6, 120 )

  la   x8, simple_base
  li   x10, 16

update_loop:
  lw   x12, 0(x8)
  addi x12, x12, 1
  sw   x12, 0(x8)
  add  x8,  x8,  x9
  addi x10, x10, -1
  bnez x10, update_loop

  la   x8, simple_base
  li   x10, 16
  li   x7, 0

sum2_loop:
  lw   x12, 0(x8)
  add  x7,  x7,  x12
  add  x8,  x8,  x9
  addi x10, x10, -1
  bnez x10, sum2_loop

  TEST_CHECK_EQ( x7, 136 )
  TEST_CHECK_EQ( x1, 0x12345678 )

TEST_RISCV_END

.section .data
.align 6
simple_base:
  .space 64
