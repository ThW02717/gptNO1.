#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        li x2, 5
        li x3, 7
        mul x4, x2, x3
        mul x5, x2, x3
        mul x6, x2, x4

        TEST_CHECK_EQ(x4, 35)
        TEST_CHECK_EQ(x5, 35)
        TEST_CHECK_EQ(x6, 175)

        li x2, 10
        li x3, 5
        li x4, 7
        li x5, 2
        mul x6, x2, x3
        div x7, x6, x4

        la x21, tdata_0
        sw x7, 0(x21)

        lw x8, 0(x21)
        mul x9, x8, x5
        div x10, x9, x3
        sw x10, 4(x21)

        lw x11, 0(x21)
        lw x12, 4(x21)
        mul x13, x11, x12
        div x14, x13, x2

        TEST_CHECK_EQ(x6, 50)
        TEST_CHECK_EQ(x7, 7)
        TEST_CHECK_EQ(x9, 14)
        TEST_CHECK_EQ(x10, 2)
        TEST_CHECK_EQ(x13, 14)
        TEST_CHECK_EQ(x14, 1)

        div x15, x2, x5
        mul x16, x15, x4
        TEST_CHECK_EQ(x16, 35)

        sw x4, 8(x21)
        lw x17, 8(x21)
        mul x18, x17, x3
        TEST_CHECK_EQ(x18, 35)

        TEST_RISCV_END

        .data
        .align 4
tdata_0:
        .word 0x00000000
