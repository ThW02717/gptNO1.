#include "riscv-macros.h"

TEST_RISCV_BEGIN

  
    la    x10, data_base

    lw    x11, 0(x10)


    li    x12, 0x11112222
    sw    x12, 0(x10)       


    lw    x13, 0(x10)
    TEST_CHECK_EQ( x13, 0x11112222 )

  
    li    x14, 0x33334444
    sw    x14, 4(x10)        

    lw    x15, 0(x10)        
    TEST_CHECK_EQ( x15, 0x11112222 )

    lw    x16, 4(x10)    
    TEST_CHECK_EQ( x16, 0x33334444 )

  
    li    x17, 0x000000AA
    sb    x17, 8(x10)         

    lw    x18, 8(x10)         
    TEST_CHECK_EQ( x18, 0x000000AA )


    li    x19, 0x00005566
    sh    x19, 12(x10)       
    lw    x20, 12(x10)
    TEST_CHECK_EQ( x20, 0x00005566 )

TEST_RISCV_END

    .data
    .align 6              
data_base:
    .word 0xDEADBEEF      
    .word 0x12345678     
    .word 0x00000000     
    .word 0x00000000      
    .space 48            
