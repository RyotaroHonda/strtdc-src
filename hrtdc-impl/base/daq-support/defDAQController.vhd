library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use mylib.defBCT.all;
use mylib.defDDRReceiverV2.all;

package defDCT is
  constant kNumDaqBlock : integer:= 2;

  -- Entity port ----------------------------------------------------------
  type RegDct2RcvArray is array(kNumDaqBlock-1 downto 0) of RegDct2RcvType;
  type RegRcv2DctArray is array(kNumDaqBlock-1 downto 0) of RegRcv2DctType;

  -- Internal registers ---------------------------------------------------
  subtype CtrlID is integer range -1 to 5;
  type regLeaf is record
    Index : CtrlID;
  end record;
  constant kTestModeU : regLeaf := (Index => 0);
  constant kTestModeD : regLeaf := (Index => 1);
  constant kEnU       : regLeaf := (Index => 2);
  constant kEnD       : regLeaf := (Index => 3);
  constant kFRstU     : regLeaf := (Index => 4);
  constant kFRstD     : regLeaf := (Index => 5);
  constant kDummy     : regLeaf := (Index => -1);

  type DCTProcessType is (
    Init, Idle, Connect,
    Write, Read,
    ExecuteInitDDR,
    Finalize,
    Done
    );

  -- Local Address --------------------------------------------------------
  constant kInitDdr       : LocalAddressType := x"020"; -- W,         Assert DDR receiver initialize
  constant kCtrlReg       : LocalAddressType := x"030"; -- W,R  [0:0] DDR control register
  constant kRcvStatus     : LocalAddressType := x"040"; -- R,   [1:0] DDR reciever status

end package defDCT;
