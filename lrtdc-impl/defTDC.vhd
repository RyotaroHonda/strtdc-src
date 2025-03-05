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

  -- Internal ata structure ------------------------------------------------------------
  constant kWidthIntData    : integer:= 46; -- width of internal data

  -- Definition of internal HBD data position --
  -- 1st delimiter --
  constant kPosIHbdDataType : std_logic_vector(kWidthIntData-1        downto kWidthIntData        -kWidthDataType)      := (others => '0');
  constant kPosIHbdFlag     : std_logic_vector(kPosIHbdDataType'low-1 downto kPosIHbdDataType'low -kWidthDelimiterFlag) := (others => '0');
  constant kPosIHbdHBFrame  : std_logic_vector(kPosIHbdFlag'low-1     downto kPosIHbdFlag'low     -kWidthStrHbf)        := (others => '0');

  -- 2nd delimiter --
  constant kPosIHbdGenSize  : std_logic_vector(kPosHbdGenSize'length-4 downto 0):= (others => '0'); -- Num of  word (-3 comes from word to byte)

  -- Definition of internal TDC data position --
  constant kPosITot     : std_logic_vector(kPosIHbdDataType'low-1 downto kPosIHbdDataType'low -16) := (others => '0');
  constant kPosITiming  : std_logic_vector(kPosITot'low-1         downto kPosITot'low         -19) := (others => '0');

end package defTDC;
