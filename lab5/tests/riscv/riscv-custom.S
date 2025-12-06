#include "riscv-macros.h"

TEST_RISCV_BEGIN


  la   x10, data_base


  lw   x2, 0(x10)              


  lw   x3, 0(x10)
  TEST_CHECK_EQ( x3, 0x11223344 )


  li   x4, 0x55667788
  sw   x4, 4(x10)

  lw   x5, 4(x10)
  TEST_CHECK_EQ( x5, 0x55667788 )

TEST_RISCV_END

  .section .data
  .align 4

data_base:
  .word 0x11223344     
  .word 0x00000000    
