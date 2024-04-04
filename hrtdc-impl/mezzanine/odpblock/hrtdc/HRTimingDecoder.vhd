library ieee, mylib;
use ieee.std_logic_1164.all;
use mylib.defHrTimingUnit.all;

entity HRTimingDecoder is
  port (
    tdcRst      : in std_logic;

    tdcClk      : in std_logic;
    sysClk      : in std_logic;

    -- input --
    TapIn       : in std_logic_vector(kNumRTaps downto 0);

    -- output --
    hdOut       : out std_logic;
    dOut        : out std_logic_vector(kWidthFine+kWidthSemi-1 downto 0)

    );
end HRTimingDecoder;

architecture RTL of HRTimingDecoder is
  -- signal decralation ----------------------------------------------------

  -- Lead finder --
  signal lead_position_out    : std_logic_vector(kNumRTaps-1 downto 0);

  -- Binary encoder --
  signal hit_detect_fast  : std_logic;
  signal fine_count_fast  : std_logic_vector(kWidthFine-1 downto 0);

  constant kOrder   : string:= "Decrement";

begin
  -- ============================ body ====================================

  -- Lead finder --
  u_LF_Inst : entity mylib.LeadFinder
    port map(
      CLK       => tdcClk,
      TapIn     => TapIn,
      LeadOut   => lead_position_out
      );

  -- Binary encoder --
  u_bEncoder_Inst : entity mylib.BinaryEncoder
    port map(
      RST         => tdcRst,
      CLK         => tdcClk,
      LeadIn      => lead_position_out,
      hitDetect   => hit_detect_fast,
      dataOut     => fine_count_fast
      );

  -- CDC --
  u_cdc : entity mylib.tdcClockDomainCrossing_v5
  generic map(
    SemiCountOrder => kOrder
  )
  port map(
    -- fast clock --
    tdcClk      => tdcClk,
    hdIn        => hit_detect_fast,
    dIn         => fine_count_fast,

    -- slow clock --
    sysClk      => sysClk,
    hdOut       => hdOut,
    dOut        => dOut
    );




end RTL;
