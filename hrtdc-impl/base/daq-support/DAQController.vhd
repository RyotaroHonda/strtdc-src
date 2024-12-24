library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

use mylib.defDDRReceiverV2.all;
use mylib.defBCT.all;
use mylib.defDCT.all;

entity DAQController is
  generic(
    kWidthUserReg       : integer:= 16
  );
  port(
    rst                 : in std_logic;
    clk                 : in std_logic;

    -- Module input --
    regRcvIn            : in RegRcv2DctArray;

    -- Module output --
    regRcvOut           : out RegDct2RcvArray;
    forceReset          : out std_logic_vector(kNumDaqBlock-1 downto 0);
    userReg             : out std_logic_vector(kWidthUserReg-1 downto 0);

    -- Local bus --
    addrLocalBus	      : in  LocalAddressType;
    dataLocalBusIn	    : in  LocalBusInType;
    dataLocalBusOut	    : out LocalBusOutType;
    reLocalBus		      : in  std_logic;
    weLocalBus		      : in  std_logic;
    readyLocalBus	      : out std_logic
    );
end DAQController;

architecture RTL of DAQController is
  attribute keep  : string;

  -- System --
  signal sync_reset       : std_logic;

  -- internal signal declaration ----------------------------------------

  -- To Rcv  --
  signal reg_init_ddr     : std_logic;

  -- From Rcv  --
  signal reg_ddr_bit_aligned  : std_logic_vector(kNumDaqBlock-1 downto 0);
  signal reg_ddr_bit_error    : std_logic_vector(kNumDaqBlock-1 downto 0);

  signal reg_ctrl             : std_logic_vector(7 downto 0);
  signal ddr_status           : std_logic_vector(7 downto 0);
  signal reg_user_reg         : std_logic_vector(userReg'range);
  signal reg_init_cbt         : std_logic;

  signal state_lbus	          : DCTProcessType;

  -- =============================== body ===============================
begin
  -- connection ----------------------------------
  u_io_buf : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(sync_reset = '1') then
        for i in 0 to kNumDaqBlock-1 loop
          -- reg out --
          regRcvOut(i).testModeDDR    <= '1';
          regRcvOut(i).initDDR        <= '0';
        end loop;

        forceReset                <= "00";

        -- reg in --
        reg_ddr_bit_aligned       <= "00";
        reg_ddr_bit_error         <= "00";
      else

        -- reg out --
        regRcvOut(0).testModeDDR    <= reg_ctrl(kTestModeU.Index);
        regRcvOut(0).initDDR        <= reg_init_ddr and reg_ctrl(kEnU.Index);
        regRcvOut(1).testModeDDR    <= reg_ctrl(kTestModeD.Index);
        regRcvOut(1).initDDR        <= reg_init_ddr and reg_ctrl(kEnD.Index);

        forceReset(0)               <= reg_ctrl(kFrstU.Index);
        forceReset(1)               <= reg_ctrl(kFrstD.Index);

        userReg                     <= reg_user_reg;

        -- reg in --
        reg_ddr_bit_aligned(0)    <= regRcvIn(0).bitAligned;
        reg_ddr_bit_error(0)      <= regRcvIn(0).bitError;
        reg_ddr_bit_aligned(1)    <= regRcvIn(1).bitAligned;
        reg_ddr_bit_error(1)      <= regRcvIn(1).bitError;
      end if;
    end if;
  end process;

  ddr_status <= "0000"
                & reg_ddr_bit_error
                & reg_ddr_bit_aligned;

  -- connection ----------------------------------

  u_BusProcess : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(sync_reset = '1') then
        dataLocalBusOut	<= x"00";
        readyLocalBus     <= '0';
        reg_init_ddr      <= '0';
        reg_ctrl          <= "00000011";
        state_lbus        <= Init;
      else
        case state_lbus is
          when Init =>
            reg_init_ddr  <= '0';
            reg_ctrl      <= "00000011";
            state_lbus    <= Idle;

          when Idle =>
            readyLocalBus	<= '0';
            if(weLocalBus = '1' or reLocalBus = '1') then
              state_lbus	<= Connect;
            end if;

          when Connect =>
            if(weLocalBus = '1') then
              state_lbus	<= Write;
            else
              state_lbus	<= Read;
            end if;

          when Write =>
            case addrLocalBus(kNonMultiByte'range) is
              when kInitDdr(kNonMultiByte'range) =>
                state_lbus	<= ExecuteInitDDR;
              when kCtrlReg(kNonMultiByte'range) =>
                reg_ctrl	  <= dataLocalBusIn;
                state_lbus	<= Done;
              when kUserReg(kNonMultiByte'range) =>
                case addrLocalBus(kMultiByte'range) is
                  when k1stByte =>
                    reg_user_reg(7 downto 0)  <= dataLocalBusIn;
                  when k2ndByte =>
                    reg_user_reg(15 downto 8) <= dataLocalBusIn;
                  when others =>
                    reg_user_reg(7 downto 0)  <= dataLocalBusIn;
                end case;
                state_lbus  <= Done;

              when others =>
                state_lbus	<= Done;
            end case;

          when Read =>
            case addrLocalBus is
              when kCtrlReg =>
                dataLocalBusOut <= reg_ctrl;
              when kRcvStatus =>
                dataLocalBusOut <= ddr_status;
              when others =>
                dataLocalBusOut <= x"ff";
            end case;
            state_lbus	<= Done;

          when ExecuteInitDDR =>
            reg_init_ddr          <= '1';
            state_lbus            <= Finalize;

          when Finalize =>
            reg_init_ddr          <= '0';
            state_lbus            <= Done;

          when Done =>
            readyLocalBus	<= '1';
            if(weLocalBus = '0' and reLocalBus = '0') then
              state_lbus	<= Idle;
            end if;

          -- probably this is error --
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
