library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use ieee.numeric_std.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defDelimiter.all;
use mylib.defThrottling.all;

entity hbfThrottling is
  port(
    clk                 : in STD_LOGIC;

    -- Control registers --
    throttlingRatio     : in std_logic_vector(kNumHbfMode-1 downto 0);
    hbfNum              : in std_logic_vector(kWidthStrHbf-1 downto 0);

    -- Status output --
    isWorking           : out std_logic -- The signal indicating that throttling is on

  );
end hbfThrottling;

architecture Behavioral of hbfThrottling is

  signal throttling_on  : std_logic_vector(throttlingRatio'range);

begin
  -- =======================================================================
  --                              Body
  -- =======================================================================

  throttling_on(0)  <= '0' when(hbfNum(0 downto 0) = "0") else '1';
  throttling_on(1)  <= '0' when(hbfNum(1 downto 0) = "00") else '1';
  throttling_on(2)  <= '0' when(hbfNum(2 downto 0) = "000") else '1';
  throttling_on(3)  <= '0' when(hbfNum(3 downto 0) = "0000") else '1';

  isWorking <= or_reduce(throttlingRatio and throttling_on);

end Behavioral;
