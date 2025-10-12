//========================================================================
// riscv-mulhsu.S
//========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        # TODO
        TEST_RR_OP( mulh, 0x00000000, 0x00000000, 0x00000000 )  # 0 * 0 = 0
        TEST_RR_OP( mulh, 0x00000001, 0x00000001, 0x00000000 )  # 1 * 1 = 1 -> ans =0
        TEST_RR_OP( mulh, 0x00000002, 0x00000003, 0x00000000 )  # 2 * 3 = 6 -> ans =0
        TEST_RR_OP( mulh, 0x7FFFFFFF, 0x7FFFFFFF, 0x3FFFFFFF )  # large positive * positive
        TEST_RR_OP( mulh, 0x80000000, 0x00000002, 0xFFFFFFFF )  # (-2^31)*2 = -4294967296 -> ans =0xFFFFFFFF
        TEST_RR_OP( mulh, 0xFFFFFFFF, 0x00000002, 0xFFFFFFFF )  # (-1)*2 = -2 -> hi=0xFFFFFFFF
        TEST_RR_OP( mulh, 0x80000000, 0x80000000, 0x40000000 )  # (-2^31)*(-2^31)=2^62 -> ans=0x40000000

        //--------------------------------------------------------------------
        // Source/Destination hazard tests
        //--------------------------------------------------------------------

        TEST_RR_SRC0_EQ_DEST( mulh, 13, 11, 0 )
        TEST_RR_SRC1_EQ_DEST( mulh, 14, 11, 0 )
        TEST_RR_SRC0_EQ_SRC1( mulh, 15, 0 )
        TEST_RR_SRCS_EQ_DEST( mulh, 16, 0 )

        TEST_RISCV_END