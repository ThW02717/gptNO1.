// /lab4/tests/riscv/riscv-test1.S
#include "riscv-macros.h"

TEST_RISCV_BEGIN

  li   x4, 40
  li   x2, 20
  li   x3, 30

  // 老：慢（4-cycle）
  mul  x7, x2, x3      // x7 = 600

  // 少：快（1-cycle）— 用 addi
  addi x7, x4, 0       // x7 = 40（會先完成）

  // 拉開時間，確保 mul 晚點回來
  TEST_INSERT_NOPS( 8 )

  // 最終應該是 40；I2O2 會被 mul 晚到蓋回 600 而失敗；I2OI 會通過
  TEST_CHECK_EQ( x7, 40 )

TEST_RISCV_END

