library ieee;
use ieee.std_logic_1164.all;

library mylib;
use mylib.defTDC.all;

package defTDCDelayBuffer is

  -- Data Unit --
  -- Valid + isLeading + isConfilicted + FineCount
  constant kWidthDataUnit     : integer  := 2+ kWidthFineCount + kWidthFineCount;

  -- BRAM information
  constant kDepthBuffer       : integer  := 256;
  constant kWidthAddrBuffer   : integer  := 8;   -- log2(kDepthBuffer)


  -- setting delay clock
  constant kDelayClock        : integer  := 257; -- 3~kDepthBuffer+1
  constant kOffsetRAddr       : integer  := kDepthBuffer-kDelayClock+3;

end package defTDCDelayBuffer;
