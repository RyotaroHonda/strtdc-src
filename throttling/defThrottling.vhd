library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package defThrottling is

  constant kNumHbfMode    : integer:= 4;
  -- 0001: HBF is active 1 in 2
  -- 0010: HBF is active 1 in 4
  -- 0100: HBF is active 1 in 8
  -- 1000: HBF is active 1 in 16

end package;