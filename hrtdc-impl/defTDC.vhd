library ieee;
use ieee.std_logic_1164.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defDelimiter.all;

package defTDC is

  -- TDC data structure --
  constant kPosChannel  : std_logic_vector(kPosHbdDataType'low-1 downto kPosHbdDataType'low -7)  :=(others => '0');
  constant kPosTot      : std_logic_vector(kPosChannel'low-1     downto kPosChannel'low     -22) := (others => '0');
  constant kPosTiming   : std_logic_vector(kPosTot'low-1         downto kPosTot'low         -29) := (others => '0');

  -- kWidthFine + kWidthSemiFine --
  constant kWidthFineCount  : integer := 13;

  -- TdcUnit ---------------------------------------------------------------------------
  constant kWidthTiming     : positive  := kPosTiming'length;

  -- LT paring -----------------------------------------------------------------------
  constant kLengthParing    : positive  := 30;

  constant kMaxToT          : integer   := 4000; -- Unit ns
  constant kMaxPairingCount : integer   := kMaxToT/8;
  constant kWidthTOT        : positive  := kPosTot'length; -- ToT value

end package defTDC;
