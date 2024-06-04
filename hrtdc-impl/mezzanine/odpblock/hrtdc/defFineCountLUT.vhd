library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library mylib;
use mylib.defHrTimingUnit.all;

package defFineCountLUT is
  -- LUT --
  constant kNumLut            : positive:= 2;

  constant kWidthLutIn        : positive:= 21;
  constant kWidthLutAddr      : positive:= 8;
  constant kMaxPtr            : std_logic_vector(kWidthLutAddr-1 downto 0):= (others => '1');
  -- LutAddr: Bin number of reduced-tap --

  constant kLengthDiscard     : positive:= 8;
  constant kWidthLutOut       : positive:= kWidthLutIn - kLengthDiscard;

  type WriteProcessType is (
    Init,
    InitReset, SetAddrReset, WriteReset, FinalizeReset,
    SetAddr0, Read0, Record0, Sum0, Write0, Finalize0,
    InitInteg,
    SetAddr1, Read1, Record1, Sum1, Write1, Write2, Finalize1,
    DoSwitch,
    Done
    );

end package defFineCountLUT;

