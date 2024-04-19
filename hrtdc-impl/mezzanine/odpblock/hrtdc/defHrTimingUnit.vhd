library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package defHrTimingUnit is
  -- Tapped delay line -----------------------------------------------------------------
  constant kNumOR             : integer:= 3;
  constant kNumTaps           : integer:= 192; -- 196
  constant kNumRTaps          : integer:= 192/kNumOR;

  constant kLeadingType       : integer:= 0;
  constant kTrailingType      : integer:= 1;

  -- Data Structure --------------------------------------------------------------------
  constant kNumClkDiv         : integer:= 4;

  constant kWidthFine         : integer:= 8;
  constant kWidthSemi         : integer:= integer(ceil(log2(real(kNumClkDiv))));

end package defHrTimingUnit;

