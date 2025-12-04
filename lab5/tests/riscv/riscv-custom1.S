#include "riscv-macros.h"

TEST_RISCV_BEGIN

    # 用 x10 當 base pointer，完全不要用 x1，避免跟 TEST_CHECK_EQ 打架
    la    x10, data_base

    # ------------------------------------------------------
    # Part A: 先把 cache line 拉進來（clean）
    # ------------------------------------------------------
    # 第一次 load：miss + refill，line = valid=1, dirty=0
    lw    x11, 0(x10)

    # ------------------------------------------------------
    # Part B: 對同一個 word 做 write hit，變 dirty line
    # ------------------------------------------------------
    li    x12, 0x11112222
    sw    x12, 0(x10)         # write hit on clean line → line 變 dirty

    # read hit on dirty line
    lw    x13, 0(x10)
    TEST_CHECK_EQ( x13, 0x11112222 )

    # ------------------------------------------------------
    # Part C: 同一個 block 內另一個 word 的 read/write hit（dirty 狀態下）
    # ------------------------------------------------------
    li    x14, 0x33334444
    sw    x14, 4(x10)         # 同一個 64B block，write hit（line 已經 dirty）

    lw    x15, 0(x10)         # 再讀回第一個 word，檢查沒被莫名改掉
    TEST_CHECK_EQ( x15, 0x11112222 )

    lw    x16, 4(x10)         # 讀回第二個 word
    TEST_CHECK_EQ( x16, 0x33334444 )

    # ------------------------------------------------------
    # Part D: dirty line 上測 sb/sh 的 write hit + read hit
    # ------------------------------------------------------
    # offset 8 對應的整個 word 初始是 0
    li    x17, 0x000000AA
    sb    x17, 8(x10)         # 只寫最低一個 byte

    lw    x18, 8(x10)         # 用 lw 看整個 word pattern
    TEST_CHECK_EQ( x18, 0x000000AA )

    # offset 12 對應的整個 word 初始也是 0
    li    x19, 0x00005566
    sh    x19, 12(x10)        # 寫入 16 bits halfword（假設對齊）

    lw    x20, 12(x10)
    TEST_CHECK_EQ( x20, 0x00005566 )

TEST_RISCV_END

    .data
    .align 6              # 64B 對齊，確保 data_base 是一個 block 的開頭
data_base:
    .word 0xDEADBEEF      # offset 0  (之後被 sw 成 0x11112222)
    .word 0x12345678      # offset 4  (之後被 sw 成 0x33334444)
    .word 0x00000000      # offset 8  (之後被 sb 改成 0x000000AA)
    .word 0x00000000      # offset 12 (之後被 sh 改成 0x00005566)
    .space 48             # 把整個 64B block 補滿（4*4=16 + 48 = 64 bytes）
