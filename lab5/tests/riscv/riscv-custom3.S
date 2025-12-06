#include "riscv-macros.h"

TEST_RISCV_BEGIN
  li x1, 0x12345678

  # A, B, C 
  la   x8, conf_base      # x8 = A

  li   x9, 2048           # 2^11
  add  x9, x8, x9         # x9 = B = A + 2048

  li   x10, 4096          # 2^12
  add  x10, x8, x10       # x10 = C = A + 4096

  # 寫入三個不同 pattern
  li   x11, 0xA1A1A1A1
  sw   x11, 0(x8)         # A

  li   x12, 0xB2B2B2B2
  sw   x12, 0(x9)         # B

  li   x13, 0xC3C3C3C3
  sw   x13, 0(x10)        # C


  lw   x14, 0(x8)
  TEST_CHECK_EQ( x14, 0xA1A1A1A1 )

  lw   x15, 0(x9)
  TEST_CHECK_EQ( x15, 0xB2B2B2B2 )

  lw   x16, 0(x10)
  TEST_CHECK_EQ( x16, 0xC3C3C3C3 )
  TEST_CHECK_EQ( x1, 0x12345678 )
  
TEST_RISCV_END

  //------------------------------------------------------------------
  // Data section
  //------------------------------------------------------------------
  .section .data
  .align 6                
conf_base:
  .space 8192             
