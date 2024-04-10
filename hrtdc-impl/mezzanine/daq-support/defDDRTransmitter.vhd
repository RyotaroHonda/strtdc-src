library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package defDDRTransmitter is
  constant kNumDDR    : positive:= 9;

  -- Internal signal definition --
  -- SerDes data --
  constant kRefBit              : std_logic_vector(7 downto 0) := "01010110";
  type DDRDataType    is array (kNumDDR-1 downto 0) of std_logic_vector(0 downto 0);
  type SerDesDataType is array (kNumDDR-1 downto 0) of std_logic_vector(7 downto 0);

  -- Reset --
  constant kNumResetDelay   : positive :=16;

end package defDDRTransmitter;
