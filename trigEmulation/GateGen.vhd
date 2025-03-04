library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use ieee.numeric_std.all;

library mylib;
use mylib.defGateGen.all;

entity GateGen is
  port(
    clk             : in STD_LOGIC;

    emuModeOn       : in std_logic_vector(1 downto 0);
    delayReg        : in std_logic_vector(kWidthTrgDelay-1 downto 0);
    widthReg        : in std_logic_vector(kWidthTrgWidth-1 downto 0);

    triggerIn       : in std_logic;
    gateOut         : out std_logic

  );
end GateGen;

architecture Behavioral of GateGen is

  -- System --
  signal one_shot_trig    : std_logic;
  --signal mode_on_edge     : std_logic;
  signal gate_out         : std_logic;

  constant kMaxAddr       : unsigned(kWidthTrgDelay-1 downto 0):= (others => '1');
  signal write_addr, read_addr  : std_logic_vector(kWidthTrgDelay-1 downto 0):= (others => '0');
  signal delay_trig       : std_logic;
  signal delay_reg_prev   : std_logic_vector(delayReg'range);

  signal gate_count       : std_logic_vector(kWidthTrgWidth-1 downto 0):= (others => '0');

begin
  -- =======================================================================
  --                              Body
  -- =======================================================================

  gateOut <= not gate_out when(emuModeOn = kVetoMode) else gate_out;

  u_edge_trig   : entity mylib.EdgeDetector port map(clk, triggerIn, one_shot_trig);
  --u_edge_modeon : entity mylib.EdgeDetector port map(clk, or_reduce(emuModeOn), mode_on_edge);

  u_addr : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(delay_reg_prev /= delayReg) then
        write_addr  <= std_logic_vector(kMaxAddr);
        read_addr   <= std_logic_vector(kMaxAddr-1-unsigned(delayReg));
        delay_reg_prev  <= delayReg;
      else
        write_addr  <= std_logic_vector(unsigned(write_addr) +1);
        read_addr   <= std_logic_vector(unsigned(read_addr) +1);
      end if;
    end if;
  end process;

  u_delay : entity mylib.MyDPRamSE
    generic map(
      kWidthAddr  => kWidthTrgDelay,
      kWidthData  => 1
      )
    port map(
      clk     => clk,
      we      => '1',
      en      => '1',
      addra   => write_addr,
      addrb   => read_addr,
      di(0)   => one_shot_trig,
      doa     => open,
      dob(0)  => delay_trig
      );

  u_gate : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(delay_trig = '1') then
        gate_count  <= widthReg;
      else
        if(unsigned(gate_count) /= 0) then
          gate_count  <= std_logic_vector(unsigned(gate_count) -1);
        end if;
      end if;

      if(emuModeOn = "00") then
        gate_out <= '1';
      elsif(or_reduce(emuModeOn) = '1' and unsigned(gate_count) /= 0) then
        gate_out <= '1';
      else
        gate_out <= '0';
      end if;
    end if;
  end process;


end Behavioral;
