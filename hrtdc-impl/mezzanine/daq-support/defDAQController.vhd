library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use mylib.defBCT.all;

package defDAQController is
  -- Local Address --------------------------------------------------------
  constant kTestmode        : LocalAddressType := x"000"; -- W/R, [0:0] enable test mode
  constant kExtraPath       : LocalAddressType := x"010"; -- W/R, [0:0] calibration mode

  -- Register index --
  constant kLeading   : integer:= 0;
  constant kTrailing  : integer:= 1;

end package defDAQController;

