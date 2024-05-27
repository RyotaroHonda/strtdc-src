library ieee;
use ieee.std_logic_1164.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defDelimiter.all;

package defTDC is

  -- TDC data structure --
  constant kPosChannel  : std_logic_vector(kPosHbdDataType'low-1 downto kPosHbdDataType'low -8)  := (others => '0');
  constant kPosTot      : std_logic_vector(kPosChannel'low-1     downto kPosChannel'low     -16) := (others => '0');
  constant kPosTiming   : std_logic_vector(kPosTot'low-1         downto kPosTot'low         -19) := (others => '0');

  -- FirstFDCEs parameters -------------------------------------------------------------
  constant kNumTdcClock     : integer  := 4;

  -- FineCounterDecoder parameters -----------------------------------------------------
  constant kWidthFineCount  : integer  := 3;

  -- Channel ---------------------------------------------------------------------------
  constant kWidthChannel    : integer  := kPosChannel'length;

  -- TdcUnit ---------------------------------------------------------------------------
  constant kWidthTiming     : integer  := kPosTiming'length;

  -- LT paring -----------------------------------------------------------------------
  constant kLengthParing    : integer  := 32;

  constant kMaxToT          : integer  := 4000; -- Unit ns
  constant kMaxPairingCount : integer  := kMaxToT/8;
  constant kWidthTOT        : integer  := kPosTot'length; -- ToT value

end package defTDC;
