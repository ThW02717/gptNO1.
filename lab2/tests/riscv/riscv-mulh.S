//========================================================================
// riscv-mulh.S
//========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        # TODO
        TEST_RR_OP( mulh,  0,  0, 0 )
        TEST_RR_OP( mulh,  1,  1, 0 )           # 1*1=1 -> 0x0000000000000001，ans = 00000000
        TEST_RR_OP( mulh, -1,  1, 0xffffffff )  # (-1)*1=-1 -> 0xffffffffffffffff，ans = ffffffff
        TEST_RR_OP( mulh, -1, -1, 0x00000000 )  # (-1)*(-1)=1 00000000
        //--------------------------------------------------------------------
        // Source/Destination tests
        //--------------------------------------------------------------------

        TEST_RR_SRC0_EQ_DEST( mulh, 13, 11, 0 )   # 13*11=143 -> 00000000
        TEST_RR_SRC1_EQ_DEST( mulh, 14, 11, 0 )
        TEST_RR_SRC0_EQ_SRC1( mulh, 15, 0 )
        TEST_RR_SRCS_EQ_DEST( mulh, 16, 0 )
        TEST_RISCV_END

