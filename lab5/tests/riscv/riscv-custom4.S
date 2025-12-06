#include "riscv-macros.h"

TEST_RISCV_BEGIN



  la   x1, set_base        # x1 = base (A)

  li   x2, 2048            # 2^11
  add  x9, x1, x2          # x9 = B = base + 2048

  li   x3, 4096            # 2^12
  add  x10, x1, x3         # x10 = C = base + 4096

 
  li   x11, 0xAAA11111
  sw   x11, 0(x1)          # mem[A] = 0xAAA11111

  li   x12, 0xBBB22222
  sw   x12, 0(x9)          # mem[B] = 0xBBB22222

  li   x13, 0xCCC33333
  sw   x13, 0(x10)         # mem[C] = 0xCCC33333


  

  lw   x4, 0(x1)           # load A
  lw   x5, 0(x9)           # load B

 
  lw   x4, 0(x1)          

  

  li   x6, 0xAAA99999
  sw   x6, 0(x1)          

  lw   x7, 0(x10)         



  lw   x4, 0(x1)           # A
  lw   x5, 0(x9)           # B
  lw   x7, 0(x10)          # C
  lw   x4, 0(x1)           # A 再 hit 一次


  lw   x14, 0(x1)
  TEST_CHECK_EQ( x14, 0xAAA99999 )

  lw   x15, 0(x9)
  TEST_CHECK_EQ( x15, 0xBBB22222 )

  lw   x16, 0(x10)
  TEST_CHECK_EQ( x16, 0xCCC33333 )

TEST_RISCV_END

  .section .data
  .align 6
set_base:
  .space 8192              