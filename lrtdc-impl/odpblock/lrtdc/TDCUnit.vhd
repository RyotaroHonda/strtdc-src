library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

Library xpm;
use xpm.vcomponents.all;

library mylib;
use mylib.defTDC.all;

entity TDCUnit is
  generic (
    -- DEBUG --
    enDEBUG           : boolean:= false
  );
  port (
    -- system --
    rst               : in std_logic;
    tdcClk            : in std_logic_vector(kNumTdcClock-1 downto 0);
    bClk              : in std_logic;

    -- Data In --
    sigIn             : in std_logic;

    -- Data Out --
    validOut          : out std_logic;
    dOut              : out std_logic_vector(kWidthFineCount-1 downto 0)
  );
end TDCUnit;

architecture RTL of TDCUnit is

  -- signal decralation ----------------------------------------------
  -- tdc clock domain --
  signal dout_first_fdc         : std_logic_vector(kNumTdcClock-1 downto 0);
  signal dout_fcount            : std_logic_vector(kNumTdcClock-1 downto 0);

  -- clock domain crossing --
  signal dout_decoded_fcount    : std_logic_vector(kWidthFineCount-1 downto 0);
  signal valid_decoder          : std_logic;

  -- system clock domain --
  signal reg_valid              : std_logic;
  signal reg_data               : std_logic_vector(kWidthFineCount-1 downto 0);

--  attribute mark_debug : boolean;
--  attribute mark_debug of reg_valid     : signal is enDEBUG;
--  attribute mark_debug of reg_data      : signal is enDEBUG;

begin
  -- ============================= body ==============================

  -- fine count TDC --------------------------------------------------
  u_FirstFDC : entity mylib.FirstFDCEs
  port map
  (
    rst       => '0',
    clk       => tdcClk,
    dIn       => sigIn,
    dOut      => dout_first_fdc
  );

  u_FCounter : entity mylib.FineCounter
  port map
  (
    clk       => tdcClk,
    dIn       => dout_first_fdc,
    dOut      => dout_fcount
  );

  u_FCDecoder : entity mylib.FineCounterDecoder
  port map
  (
    tdcClk    => tdcClk(0),
    sysClk    => bClk,
    dIn       => dout_fcount,
    dOut      => dout_decoded_fcount,
    valid     => valid_decoder
  );

-- system clock time stamp -----------------------------------------
  u_stamp_time : process(bClk)
  begin
    if(bClk'event and bClk = '1') then
      if(RST = '1') then
        reg_valid <= '0';
      else
        if(valid_decoder = '1') then
          reg_valid <= '1';
          reg_data  <= dout_decoded_fcount;
        else
          reg_valid <= '0';
        end if;
      end if;
    end if;
  end process;

  validOut  <= reg_valid;
  dOut      <= reg_data;

end RTL;
