#include "riscv-macros.h"

TEST_RISCV_BEGIN

  li   x1, 0x12345678

  la   x8, lru_base
  li   x9, 2048
  add  x9, x8, x9
  li   x10, 4096
  add  x10, x8, x10
  li   x5, 6144
  add  x11, x8, x5

  li   x12, 0xAAA00001
  sw   x12, 0(x8)

  li   x13, 0xBBB00002
  sw   x13, 0(x9)

  li   x14, 0xCCC00003
  sw   x14, 0(x10)

  li   x15, 0xDDD00004
  sw   x15, 0(x11)

  li   x20, 8

lru_loop:
  lw   x2, 0(x8)
  lw   x3, 0(x10)
  lw   x4, 0(x9)
  lw   x5, 0(x11)
  lw   x2, 0(x9)
  lw   x3, 0(x8)
  lw   x4, 0(x11)
  lw   x5, 0(x10)
  addi x20, x20, -1
  bnez x20, lru_loop

  lw   x6, 0(x8)
  TEST_CHECK_EQ( x6, 0xAAA00001 )

  lw   x7, 0(x9)
  TEST_CHECK_EQ( x7, 0xBBB00002 )

  lw   x18, 0(x10)
  TEST_CHECK_EQ( x18, 0xCCC00003 )

  lw   x19, 0(x11)
  TEST_CHECK_EQ( x19, 0xDDD00004 )

  TEST_CHECK_EQ( x1, 0x12345678 )

TEST_RISCV_END

.section .data
.align 6
lru_base:
  .space 8192
