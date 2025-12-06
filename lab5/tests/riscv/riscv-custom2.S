
#include "riscv-macros.h"

TEST_RISCV_BEGIN

  la    x10, miss_rd_base       # x10 = &miss_rd_base
  lw    x11, 0(x10)             # first access, must be a miss+refill
  TEST_CHECK_EQ( x11, 0x11112222 )



  la    x12, miss_wr_base       # x12 = &miss_wr_base
  li    x13, 0x33334444
  sw    x13, 0(x12)             # cold store, write miss + refill
  lw    x14, 0(x12)             # should read back what we just stored
  TEST_CHECK_EQ( x14, 0x33334444 )



  la    x20, setA0
  lw    x21, 0(x20)             # miss + refill into some way
  TEST_CHECK_EQ( x21, 0xA0A0A0A0 )


  la    x22, setA1
  lw    x23, 0(x22)
  TEST_CHECK_EQ( x23, 0xB1B1B1B1 )


  li    x24, 0xDEADBEAF
  sw    x24, 0(x20)             # write hit on setA0 → dirty line

  lw    x25, 0(x20)
  TEST_CHECK_EQ( x25, 0xDEADBEAF )



  la    x26, setA2


  li    x27, 0xC2C2C2C2
  sw    x27, 0(x26)             # write miss + refill + eviction


  lw    x28, 0(x26)
  TEST_CHECK_EQ( x28, 0xC2C2C2C2 )


  lw    x5,  0(x20)             # reload setA0
  TEST_CHECK_EQ( x5, 0xDEADBEAF )

  lw    x6,  0(x22)             # reload setA1
  TEST_CHECK_EQ( x6, 0xB1B1B1B1 )

TEST_RISCV_END



  .section .data
  .align 4



miss_rd_base:
  .word 0x11112222            
  .space 60                 

miss_wr_base:
  .word 0x00000000            


  .align 11                  
setA0:
  .word 0xA0A0A0A0
  .space 2048-4           

setA1:
  .word 0xB1B1B1B1
  .space 2048-4

setA2:
  .word 0xC2C2C2C2

