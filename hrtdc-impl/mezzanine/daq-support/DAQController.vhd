library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use mylib.defBCT.all;
use mylib.defDAQController.all;

entity DAQController is
  port(
    RST 		: in std_logic;
    CLK 		: in std_logic;

    -- Module Output --
    regTestMode         : out std_logic;
    regExtraPath        : out std_logic;

    -- Local bus --
    addrLocalBus        : in LocalAddressType;
    dataLocalBusIn      : in LocalBusInType;
    dataLocalBusOut     : out LocalBusOutType;
    reLocalBus          : in std_logic;
    weLocalBus          : in std_logic;
    readyLocalBus	      : out std_logic
    );
end DAQController;

architecture RTL of DAQController is
  attribute keep  : string;

  -- System --
  signal sync_reset       : std_logic;

  -- signal declaration ------------------------------------------------------
  signal reg_test_mode      : std_logic;
  signal reg_extra_path     : std_logic;
  signal state_lbus     : BusProcessType;

  attribute keep of reg_extra_path  : signal is "true";

-- ================================= body ==================================
begin
  regTestMode   <= reg_test_mode;
  regExtraPath  <= reg_extra_path;

  -- Bus process -------------------------------------------------------------
  u_BusProcess : process ( CLK )
  begin
    if( CLK'event and CLK='1' ) then
      if( sync_reset = '1' ) then
        dataLocalBusOut   <= x"00";
        readyLocalBus     <= '0';
        reg_test_mode     <= '0';
        reg_extra_path    <= '0';
        state_lbus        <= Init;
      else
        case state_lbus is
          when Init =>
            state_lbus 		   <= Idle;

          when Idle =>
            readyLocalBus <= '0';
            if ( weLocalBus = '1' ) then
              state_lbus <= Write;
            elsif ( reLocalBus = '1' ) then
              state_lbus <= Read;
            end if;

          when Write =>
            if(addrLocalBus(kNonMultiByte'range) = kTestMode(kNonMultiByte'range)) then
              reg_test_mode       <= dataLocalBusIn(0);
            elsif(addrLocalBus(kNonMultiByte'range) = kExtraPath(kNonMultiByte'range)) then
              reg_extra_path      <= dataLocalBusIn(0);
            end if;
            state_lbus <= Done;

          when Read =>
            if(addrLocalBus(kNonMultiByte'range) = kTestMode(kNonMultiByte'range)) then
              dataLocalBusOut     <= "0000000" & reg_test_mode;
            elsif(addrLocalBus(kNonMultiByte'range) = kExtraPath(kNonMultiByte'range)) then
              dataLocalBusOut     <= "0000000" & reg_extra_path;
            else
              dataLocalBusOut	<= X"ff";
            end if;
            state_lbus <= Done;

          when Done =>
            readyLocalBus <= '1';
            if ( weLocalBus = '0' and reLocalBus = '0' ) then
              state_lbus <= Idle;
            end if;

          when others =>
            state_lbus	<= Init;
        end case;
      end if;
    end if;
  end process u_BusProcess;

  -- Reset sequence --
  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rst, clk, sync_reset);

end RTL;
