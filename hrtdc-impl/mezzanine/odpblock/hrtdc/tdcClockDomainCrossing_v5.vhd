library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.math_real.all;
use ieee.numeric_std.all;
use mylib.defHrTimingUnit.all;

Library xpm;
use xpm.vcomponents.all;

entity tdcClockDomainCrossing_v5 is
  generic(
    SemiCountOrder : string  -- Select Increment or Decrement
  );
  port (
    -- fast clock --
    tdcClk      : in std_logic;
    hdIn        : in std_logic;
    dIn         : in std_logic_vector(kWidthFine-1 downto 0);

    -- slow clock --
    sysClk      : in std_logic;
    hdOut       : out std_logic;
    dOut        : out std_logic_vector(kWidthFine+kWidthSemi-1 downto 0)
    );
end tdcClockDomainCrossing_v5;

architecture RTL of tdcClockDomainCrossing_v5 is
  attribute   mark_debug  : string;
  -- signal decralation ----------------------------------------------------
  -- fast clock
  signal   fast_stages                    : std_logic_vector(kNumClkDiv-1 downto 0);
  type FcBufType is array(integer range kNumClkDiv-1 downto 0) of std_logic_vector(kWidthFine-1 downto 0);
  signal   fc_fast_buf                    : FcBufType;

  -- CDC
  type CdcDataType is array(integer range kNumClkDiv-1 downto 0) of std_logic_vector(kWidthFine downto 0);
  signal cdc_in, cdc_out                  : CdcDataType;

  -- slow clock
  type SemiCountArray is array(integer range kNumClkDiv-1 downto 0) of std_logic_vector(kWidthSemi-1 downto 0);
  signal   preset_semi_count              : SemiCountArray;

  signal   slow_stages                    : std_logic_vector(kNumClkDiv-1 downto 0);
  signal   fc_slow_buf                    : FcBufType;

  signal   reg_fine_count                 : std_logic_vector(kWidthFine-1 downto 0);
  signal   semi_fine_count                : std_logic_vector(kWidthSemi-1 downto 0);
  signal   hd_out                         : std_logic;

  --attribute mark_debug of dout_fifo   : signal is "TRUE";
  --attribute mark_debug of rv_fifo     : signal is "TRUE";

begin
  -- =============================== body ==================================

  hdOut <= hd_out;
  dOut  <= semi_fine_count & reg_fine_count;

  --------------------------------------------------------------------------
  -- fast clock domain
  --------------------------------------------------------------------------
  u_sr_fast : process(tdcClk)
  begin
    if(tdcClk'event and tdcClk = '1') then
      fast_stages   <= fast_stages(kNumClkDiv-2 downto 0) & hdIn;
      fc_fast_buf   <= fc_fast_buf(kNumClkDiv-2 downto 0) & dIn;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- slow clock domain
  --------------------------------------------------------------------------
  gen_semi_increment : if SemiCountOrder = "Increment" generate
    preset_semi_count(0)              <= "11";
    preset_semi_count(kNumClkDiv-3)   <= "10";
    preset_semi_count(kNumClkDiv-2)   <= "01";
    preset_semi_count(kNumClkDiv-1)   <= "00";
  end generate;

  gen_semi_decrement : if SemiCountOrder = "Decrement" generate
    preset_semi_count(0)              <= "00";
    preset_semi_count(kNumClkDiv-3)   <= "01";
    preset_semi_count(kNumClkDiv-2)   <= "10";
    preset_semi_count(kNumClkDiv-1)   <= "11";
  end generate;

  gen_sync_stage : for i in 0 to kNumClkDiv-1 generate
    cdc_in(i)       <= fast_stages(i) & fc_fast_buf(i);
    slow_stages(i)  <= cdc_out(i)(kWidthFine);
    fc_slow_buf(i)  <= cdc_out(i)(kWidthFine-1 downto 0);

    u_xpm_cdc : xpm_cdc_array_single
      generic map (
        DEST_SYNC_FF   => 4,
        INIT_SYNC_FF   => 0,
        SIM_ASSERT_CHK => 0,
        SRC_INPUT_REG  => 1,
        WIDTH          => kWidthFine+1
      )
      port map (
        dest_out => cdc_out(i),
        dest_clk => sysClk,
        src_clk  => tdcClk,
        src_in   => cdc_in(i)
      );
  end generate;

--  u_sync_stage : process(sysClk)
--  begin
--    if(sysClk'event and sysClk = '1') then
--      for i in 0 to kNumClkDiv-1 loop
--        slow_stages(i)  <= fast_stages(i);
--        fc_slow_buf(i)  <= fc_fast_buf(i);
--      end loop;
--    end if;
--  end process;

  u_decode_semifine : process(sysClk)
  begin
    if(sysClk'event and sysClk = '1') then
      if(slow_stages(kNumClkDiv-1) = '1') then
        semi_fine_count <= preset_semi_count(kNumClkDiv-1);
        reg_fine_count  <= fc_slow_buf(kNumClkDiv-1);
        hd_out          <= '1';
      elsif(slow_stages(kNumClkDiv-1 downto kNumClkDiv-2) = "01") then
        semi_fine_count <= preset_semi_count(kNumClkDiv-2);
        reg_fine_count  <= fc_slow_buf(kNumClkDiv-2);
        hd_out          <= '1';
      elsif(slow_stages(kNumClkDiv-1 downto kNumClkDiv-3) = "001") then
        semi_fine_count <= preset_semi_count(kNumClkDiv-3);
        reg_fine_count  <= fc_slow_buf(kNumClkDiv-3);
        hd_out          <= '1';
      elsif(slow_stages(kNumClkDiv-1 downto 0) = "0001") then
        semi_fine_count <= preset_semi_count(0);
        reg_fine_count  <= fc_slow_buf(0);
        hd_out          <= '1';
      else
        semi_fine_count <= "00";
        reg_fine_count  <= (others => '0');
        hd_out          <= '0';
      end if;
    end if;
  end process;

end RTL;
