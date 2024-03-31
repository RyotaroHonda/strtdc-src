--------------------------------------------------------------------------------
--! @file   FineCounter.vhd
--! @brief  Fine counter for MHTDC
--! @author Takehiro Shiozaki
--! @date   2014-06-06

--! Update information
--! @author Ryotaro Honda
--! @date   2018-08-20
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library mylib;
use mylib.defTDC.all;

entity FineCounter is
  port
    (
      clk  : in std_logic_vector(kNumTdcClock-1 downto 0);
      dIn  : in std_logic_vector(kNumTdcClock-1 downto 0);
      dOut : out std_logic_vector(kNumTdcClock-1 downto 0)
    );
end FineCounter;

architecture RTL of FineCounter is
  -- signal decralation -----------------------------------------
  signal Stage0         : std_logic_vector(3 downto 0);
  signal Stage1         : std_logic_vector(3 downto 0);
  signal DelayedStage1  : std_logic_vector(2 downto 0);
begin
  -- ========================= body =============================
  process(clk(0))
  begin
    if(clk(0)'event and clk(0) = '1') then
      Stage0(0) <= dIn(0);
    end if;
  end process;

  process(clk(1))
  begin
    if(clk(1)'event and clk(1) = '1') then
      Stage0(1) <= dIn(1);
    end if;
  end process;

  process(clk(2))
  begin
    if(clk(2)'event and clk(2) = '1') then
      Stage0(2) <= dIn(2);
    end if;
  end process;

  process(clk(3))
  begin
    if(clk(3)'event and clk(3) = '1') then
      Stage0(3) <= dIn(3);
    end if;
  end process;

  process(clk(0))
  begin
    if(clk(0)'event and clk(0) ='1') then
      Stage1 <= Stage0;
    end if;
  end process;

  process(clk(0))
  begin
    if(clk(0)'event and clk(0) = '1') then
      DelayedStage1 <= Stage1(2 downto 0);
    end if;
  end process;

  dOut <= Stage1(3) & DelayedStage1;
end RTL;
