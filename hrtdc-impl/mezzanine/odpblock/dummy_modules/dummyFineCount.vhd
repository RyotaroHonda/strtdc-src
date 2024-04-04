library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
--use ieee.numeric_std.all;
use mylib.defHrTimingUnit.all;


entity dummyFineCount is
  port (
    --tdcRst      : in std_logic;
    tdcClk      : in std_logic;

    sigIn       : in std_logic;
    hdOut       : out std_logic;
    dOut        : out std_logic_vector(kWidthFine-1 downto 0)
    );
end dummyFineCount;

architecture RTL of dummyFineCount is
  attribute   mark_debug  : string;
  -- signal decralation ----------------------------------------------------
  signal sync_out, one_shot_out   : std_logic;

begin
  -- =============================== body ==================================

  hdOut <= one_shot_out;
  dOut  <= (others => '0');

  u_sync : entity mylib.synchronizer
    port map(tdcClk, sigIn, sync_out);

  u_edge : entity mylib.EdgeDetector
    port map('0', tdcClk, sync_out, one_shot_out);

end RTL;
