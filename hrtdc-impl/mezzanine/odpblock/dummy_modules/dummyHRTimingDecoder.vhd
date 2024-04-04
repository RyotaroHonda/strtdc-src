library ieee, mylib;
use ieee.std_logic_1164.all;
use mylib.defHrTimingUnit.all;

entity dummyHRTimingDecoder is
  port (
    tdcClk      : in std_logic;
    sysClk      : in std_logic;

    -- input --
    sigIn       : in std_logic;

    -- output --
    hdOut       : out std_logic;
    dOut        : out std_logic_vector(kWidthFine+kWidthSemi-1 downto 0)

    );
end dummyHRTimingDecoder;

architecture RTL of dummyHRTimingDecoder is
  -- signal decralation ----------------------------------------------------
  signal hd_fast    : std_logic;
  signal fine_count : std_logic_vector(kWidthFine-1 downto 0);

  constant kOrder   : string:= "Decrement";

begin
  -- ============================ body ====================================
  -- signal connection --
  u_FineCount : entity mylib.dummyFineCount
    port map(
      tdcClk      => tdcClk,

      sigIn       => sigIn,
      hdOut       => hd_fast,
      dOut        => fine_count
      );

  u_cdc : entity mylib.tdcClockDomainCrossing_v5
    generic map(
      SemiCountOrder => kOrder
    )
    port map(
      -- fast clock --
      tdcClk      => tdcClk,
      hdIn        => hd_fast,
      dIn         => fine_count,

      -- slow clock --
      sysClk      => sysClk,
      hdOut       => hdOut,
      dOut        => dOut
      );

end RTL;
