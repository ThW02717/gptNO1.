#include "riscv-macros.h"

TEST_RISCV_BEGIN


  li   x1, 0x12345678


  la   x8,  cache_base      # x8  = current address
  li   x9,  64              # x9  = block size (64B)
  li   x10, 64              # x10 = block count (64 blocks)

  li   x13, 0x10000000     

  # -------------------------------
  # Loop 1: store to all 64 blocks
  # -------------------------------
store_loop:
  sw   x13, 0(x8)           # store pattern to cache_base + i*64

  add  x8,  x8,  x9         # addr += 64
  addi x10, x10, -1         # count--
  bnez x10, store_loop

  # -------------------------------
  # Loop 2: load and verify all 64 blocks
  # -------------------------------

  la   x8,  cache_base      # reset address to base
  li   x9,  64              # block size
  li   x10, 64              # block count

load_loop:
  lw   x14, 0(x8)         
  TEST_CHECK_EQ( x14, 0x10000000 ) 

  add  x8,  x8,  x9         # addr += 64
  addi x10, x10, -1         # count--
  bnez x10, load_loop


  TEST_CHECK_EQ( x1, 0x12345678 )

TEST_RISCV_END

  # ------------------------------------------------------------
  # Data section
  # ------------------------------------------------------------
  .section .data
  .align 6                 
cache_base:
  .space 4096               
