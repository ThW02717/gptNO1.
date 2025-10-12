//========================================================================
// riscv-mulhu.S
//========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //--------------------------------------------------------------------
        // Basic arithmetic tests
        //--------------------------------------------------------------------

        TEST_RR_OP( mulhu, 0x00000000, 0x00000000, 0x00000000 )  # 0 * 0 → 0
        TEST_RR_OP( mulhu, 0x00000001, 0x00000001, 0x00000000 )  # 0
        TEST_RR_OP( mulhu, 0x00000002, 0x00000003, 0x00000000 )  # 0
        TEST_RR_OP( mulhu, 0xFFFFFFFF, 0x00000002, 0x00000001 )  # ans =1
        TEST_RR_OP( mulhu, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFE )  # ans =0xFFFFFFFE
        TEST_RR_OP( mulhu, 0x80000000, 0x80000000, 0x40000000 )  # ans =0x40000000
        TEST_RR_OP( mulhu, 0xFFFFFFFF, 0x7FFFFFFF, 0x7FFFFFFE )  # 

        //--------------------------------------------------------------------
        // Source/Destination hazard tests
        //--------------------------------------------------------------------

        TEST_RR_SRC0_EQ_DEST( mulhu, 13, 11, 0 )
        TEST_RR_SRC1_EQ_DEST( mulhu, 14, 11, 0 )
        TEST_RR_SRC0_EQ_SRC1( mulhu, 15, 0 )
        TEST_RR_SRCS_EQ_DEST( mulhu, 16, 0 )

        TEST_RISCV_END