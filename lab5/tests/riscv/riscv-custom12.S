#include "riscv-macros.h"

TEST_RISCV_BEGIN

  li   x1, 0x12345678

  la   x8, set_base
  li   x9, 2048
  add  x9, x8, x9
  li   x10, 4096
  add  x10, x8, x10
  li   x11, 6144
  add  x11, x8, x11

  li   x12, 0x11111111
  sw   x12, 0(x8)

  li   x13, 0x22222222
  sw   x13, 0(x9)

  li   x14, 0x33333333
  sw   x14, 0(x10)

  li   x15, 0x44444444
  sw   x15, 0(x11)

  li   x20, 64

conflict_stress_loop:
  lw   x2, 0(x8)
  lw   x3, 0(x9)
  lw   x4, 0(x10)
  lw   x5, 0(x11)
  lw   x2, 0(x9)
  lw   x3, 0(x11)
  lw   x4, 0(x8)
  lw   x5, 0(x10)
  addi x20, x20, -1
  bnez x20, conflict_stress_loop

  lw   x6, 0(x8)
  TEST_CHECK_EQ( x6, 0x11111111 )

  lw   x7, 0(x9)
  TEST_CHECK_EQ( x7, 0x22222222 )

  lw   x18, 0(x10)
  TEST_CHECK_EQ( x18, 0x33333333 )

  lw   x19, 0(x11)
  TEST_CHECK_EQ( x19, 0x44444444 )

  TEST_CHECK_EQ( x1, 0x12345678 )

TEST_RISCV_END

.section .data
.align 6
set_base:
  .space 8192
