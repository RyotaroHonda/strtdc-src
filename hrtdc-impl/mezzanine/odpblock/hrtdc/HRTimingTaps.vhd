library ieee, mylib;
use ieee.std_logic_1164.all;
use mylib.defHrTimingUnit.all;

entity HRTimingTaps is
  generic(
    SliceOrigin    : string
    );
  port (
    RST     : in std_logic;
    tdcClk  : in std_logic;

    -- input --
    sigIn   : in std_logic;

    -- output
    TapOut  : out std_logic_vector(kNumTaps-1 downto 0)

    );
end HRTimingTaps;

architecture RTL of HRTimingTaps is
  -- signal decralation ----------------------------------------------------

  -- tapped delay line --
  signal raw_tap_out      : std_logic_vector(kNumTaps-1 downto 0);

  -- Remapping --
  --signal remapped_tap_out : std_logic_vector(kNumRTaps downto 0);

begin
  -- ============================ body ====================================

  --TapOut  <= remapped_tap_out;

  -- Tapped Delay line --
  u_TDL_Inst : entity mylib.TappedDelayLineV2
    generic map(
      SliceOrigin  => SliceOrigin
      )
    port map(
      RST          => RST,
      CLK          => tdcClk,
      CIN          => sigIn,
      Q            => TapOut
      );

--  -- Remapping --
--  u_Remap_Inast : entity mylib.RemappingTapsV3
--    port map(
--      RST     => RST,
--      CLK     => tdcClk,
--      TapIn   => raw_tap_out,
--      TapOut  => remapped_tap_out
--      );


end RTL;
