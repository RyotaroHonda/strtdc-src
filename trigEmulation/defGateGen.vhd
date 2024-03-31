library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package defGateGen is

  constant kWidthTrgDelay : integer:= 8;
  constant kWidthTrgWidth : integer:= 16;

  -- Emulation mode --
  -- 01: Trigger mode (Open gate by the trigger signal)
  -- 10: Veto mode (Close gate by the veto signal)
  constant kTriggerMode   : std_logic_vector(1 downto 0):= "01";
  constant kVetoMode      : std_logic_vector(1 downto 0):= "10";


end package;