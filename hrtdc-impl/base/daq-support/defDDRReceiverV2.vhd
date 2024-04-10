library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package defDDRReceiverV2 is
  constant kNumDDR    : positive:= 9;

  -- Internal signal definition --
  -- SerDes data --
  constant kWidthSys        : positive:= 1;
  constant kWidthDev        : positive:= 8;

  constant kRefBit              : std_logic_vector(7 downto 0) := "01010110";
  type SerDesDataType is array (kNumDDR-1 downto 0) of std_logic_vector(kRefBit'range);

  -- IDELAY
  constant kWidthTap        : integer:= 5;
  constant kNumTaps         : positive:= 32;
  constant kMaxIdelayCheck  : positive:= 256;
  constant kSuccThreshold   : positive:= 230;
  constant kWidthCheckCount : positive:= 8;

  function GetTapDelay(freq_idelayctrl_ref : real) return real;
  function GetPlateauLength(tap_delay       : real;
                             freq_fast_clock : real) return integer;

  type IdelayControlProcessType is (
    Init,
    WaitStart,
    Check,
    NumTrialCheck,
    Increment,
    Decrement,
    IdelayAdjusted,
    IdelayFailure
    );

   -- BITSLIP
  constant kMaxPattCheck    : positive:= 32;
  constant kPattOkThreshold : positive:= 10;

  type BitslipControlProcessType is (
    Init,
    WaitStart,
    CheckIdlePatt,
    NumTrialCheck,
    BitSlip,
    BitslipFinished,
    BitslipFailure
    );

  -- Pattern match --
  constant kNumPattMatchCycle : integer:= 16;

  -- IDELAY adjust sequence --

  -- Bit slip sequence --


  -- DDR data     ------------------------------------------------------
  constant kWidthDdrData  : integer:= 64;

  type dataDdr2Tdc is record
    dout        : std_logic_vector(kWidthDdrData-1 downto 0);
    rv          : std_logic;
  end record;

  type dataTdc2Ddr is record
    re          : std_logic;
  end record;

  -- DDR control registers --
  type InvMaskDdr is array(kNumDDR-1 downto 0) of boolean;

  type RegDct2RcvType is record
    testModeDDR : std_logic;
    initDDR     : std_logic;
  end record;

  type RegRcv2DctType is record
    bitAligned  : std_logic;
    bitError    : std_logic;
  end record;

end package defDDRReceiverV2;
-- ----------------------------------------------------------------------------------
-- Package body
-- ----------------------------------------------------------------------------------
package body defDDRReceiverV2 is

  -- GetTapDelay --------------------------------------------------------------
  function GetTapDelay(freq_idelayctrl_ref : real) return real is
    -- Argument : Frequency of refclk for IDELAYCTRL (MHz). Integer number.
    -- Return   : Delay per tap in IDELAY (ps). Real number.
    variable result : real;
  begin
    if (190.0 < freq_idelayctrl_ref and freq_idelayctrl_ref < 210.0) then
      result  := 78.0;
    elsif(290.0 < freq_idelayctrl_ref and freq_idelayctrl_ref < 310.0) then
      result  := 52.0;
    elsif(390.0 < freq_idelayctrl_ref and freq_idelayctrl_ref < 410.0) then
      result  := 39.0;
    else
      result  := 0.0;
    end if;

    return result;

  end GetTapDelay;

  -- GetPlateauLength ---------------------------------------------------------
  function GetPlateauLength(tap_delay       : real;
                            freq_fast_clock : real) return integer is
                            -- tap_delay : IDELAY tap delay (ps).
                            -- freq_fast_clock : Frequency of SERDES fast clock (MHz)
    constant kStableRange          : real:= 0.8;
    constant kExpectedStableLength : real:= 1.0/(2.0*freq_fast_clock)*1000.0*1000.0*kStableRange; -- [ps]
    --constant kMaxLength            : integer:= 12;
    constant kMaxLength            : integer:= 7;
    variable result                : integer:= integer(0.5*kExpectedStableLength/tap_delay);
  begin
    if(result > kMaxLength) then
      result  := kMaxLength;
    end if;
    return result;
  end GetPlateauLength;

end package body defDDRReceiverV2;

