--------------------------------------------------------------------------------
--! @file   FineCounter.vhd
--! @brief  Decoder of fine counter for MHTDC
--! @author Takehiro Shiozaki
--! @date   2014-06-06

--! @modifier Ryotaro Honda
--! @date     2020-05-21
--------------------------------------------------------------------------------

library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use mylib.defTDC.all;

entity FineCounterDecoder is
  port (
    tdcClk  : in std_logic; -- 2*FreqSys
    sysClk  : in std_logic; -- FreqSys

    dIn     : in std_logic_vector(kNumTdcClock-1 downto 0);

    dOut    : out std_logic_vector(kWidthFineCount-1 downto 0);
    valid   : out std_logic
  );
end FineCounterDecoder;


architecture RTL of FineCounterDecoder is
  signal stage0 : std_logic_vector(kNumTdcClock-1 downto 0);
  signal stage1 : std_logic_vector(kNumTdcClock-1 downto 0);

  signal synch_stage0 : std_logic_vector(kNumTdcClock-1 downto 0);
  signal synch_stage1 : std_logic_vector(kNumTdcClock-1 downto 0);

  signal previous_synch_stage0 : std_logic_vector(kNumTdcClock-1 downto 0);
begin

  process(tdcClk)
  begin
    if(tdcClk'event and tdcClk = '1') then
      stage0 <= dIn;
      stage1 <= stage0;
    end if;
  end process;

  process(sysClk)
  begin
    if(sysClk'event and sysClk = '1') then
      synch_stage0 <= stage0;
      synch_stage1 <= stage1;
      previous_synch_stage0 <= synch_stage0;
    end if;
  end process;

  process(synch_stage0, synch_stage1, previous_synch_stage0)
  begin
    if(synch_stage1 = "1111") then
      case previous_synch_stage0 is
        when "0000" =>
          dOut(kWidthFineCount-2 downto 0) <= "11";
        when "1000" =>
          dOut(kWidthFineCount-2 downto 0) <= "10";
        when "1100" =>
          dOut(kWidthFineCount-2 downto 0) <= "01";
        when "1110" =>
          dOut(kWidthFineCount-2 downto 0) <= "00";
        when others =>
          dOut(kWidthFineCount-2 downto 0) <= (others => 'X');
      end case;
    else
      case synch_stage1 is
        when "0000" =>
          dOut(kWidthFineCount-2 downto 0) <= "11";
        when "1000" =>
          dOut(kWidthFineCount-2 downto 0) <= "10";
        when "1100" =>
          dOut(kWidthFineCount-2 downto 0) <= "01";
        when "1110" =>
          dOut(kWidthFineCount-2 downto 0) <= "00";
        when others =>
          dOut(kWidthFineCount-2 downto 0) <= (others => 'X');
      end case;
    end if;
  end process;

  process(synch_stage1)
  begin
    if(synch_stage1 = "1111") then
      dOut(kWidthFineCount-1) <= '0';
    else
      dOut(kWidthFineCount-1) <= '1';
    end if;
  end process;

  process(synch_stage0, synch_stage1, previous_synch_stage0)
  begin
    if(synch_stage0 = "1111" and synch_stage1 /= "1111") then
      valid <= '1';
    elsif(synch_stage1 = "1111" and previous_synch_stage0 /= "1111") then
      valid <= '1';
    else
      valid <= '0';
    end if;
  end process;
end RTL;
