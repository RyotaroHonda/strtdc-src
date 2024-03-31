library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defTDC.all;

-------------------------------------------------------------------------------
-- LTMerger is the data path merger. It receive the leading and the trailing data in parallel
-- and arrange them into the single data path in the order in which it was received.
-- If the leading and the trailing data come at the same time, the trailing data is ignored.
-- In this case, the isConfilicted signal goes high.
-------------------------------------------------------------------------------

entity LTMerger is
  port(
    clk     : in std_logic;   -- base clock

    -- Leading in --
    validLeading  : in std_logic;
    dInLeading    : in std_logic_vector(kWidthFineCount-1 downto 0);

    -- Trailing in --
    validTrailing : in std_logic;
    dInTrailing   : in std_logic_vector(kWidthFineCount-1 downto 0);

    -- Data out --
    validOut      : out std_logic; -- Indicates data valid for dOutTiming
    isLeading     : out std_logic; -- If high, output is leading data. Valid only when validOut is high.
    isConflicted  : out std_logic; -- If high, the trailing data, which arrives at the same time, is discarded. Valid only when validOut is high.
    dOutTOT       : out std_logic_vector(kWidthFineCount-1 downto 0); -- Data output TOT
    dOutTiming    : out std_logic_vector(kWidthFineCount-1 downto 0)  -- Data output
  );
end LTMerger;

architecture RTL of LTMerger is

-- Signal decralation ---------------------------------------------
  signal valid_in       : std_logic_vector(1 downto 0);
  signal valid_out      : std_logic;
  signal merged_data    : std_logic_vector(dInLeading'range);
  signal merged_tot     : std_logic_vector(dInLeading'range);
  signal is_leading     : std_logic;
  signal is_confilicted : std_logic;

  signal reg_valid_out  : std_logic;
  signal reg_merged_data  : std_logic_vector(dInLeading'range);
  signal reg_merged_tot : std_logic_vector(dInLeading'range);
  signal reg_is_leading : std_logic;
  signal reg_is_confilicted : std_logic;

begin
  -- =========================== body ===============================

  -- Index: 0=leading, 1=trailing --
  valid_in  <= validTrailing & validLeading;

  valid_out <= validTrailing or validLeading;

  merged_data <=
    dInLeading when(valid_in = "01") else
    dInTrailing when(valid_in = "10") else
    dInLeading when(valid_in = "11") else (others => '0');

  merged_tot <=
    std_logic_vector( to_unsigned(0, dInLeading'length)) when(valid_in = "01") else
    std_logic_vector( to_unsigned(0, dInLeading'length)) when(valid_in = "10") else
    std_logic_vector( unsigned(dInTrailing) - unsigned(dInLeading) )  when(valid_in = "11") else (others => '0');

  is_leading    <= '1' when(valid_in = "01") else
                   '0' when(valid_in = "10") else
                   '1' when(valid_in = "11") else '0';

  is_confilicted  <= '1' when(valid_in = "11") else '0';

  -- Output register --
  u_buffer : process(clk)
  begin
    if(clk'event and clk = '1') then
      reg_valid_out       <= valid_out;
      reg_merged_data     <= merged_data;
      reg_merged_tot      <= merged_tot;
      reg_is_leading      <= is_leading;
      reg_is_confilicted  <= is_confilicted;
    end if;
  end process;

  validOut      <= reg_valid_out;
  isLeading     <= reg_is_leading;
  isConflicted  <= reg_is_confilicted;
  dOutTOT       <= reg_merged_tot;
  dOutTiming    <= reg_merged_data;

end RTL;
