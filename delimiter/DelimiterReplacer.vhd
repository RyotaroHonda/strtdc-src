library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defDelimiter.all;
use mylib.defLaccp.all;

entity DelimiterReplacer is
  generic(
    enDEBUG             : boolean:= false
  );
  port(
    syncReset           : in std_logic;   -- synchronous reset
    clk                 : in std_logic;
    userReg             : in std_logic_vector(kPosHbdUserReg'length-1 downto 0);
    LaccpFineOffset     : in signed(kWidthLaccpFineOffset-1 downto 0);

    -- Data In --
    validIn             : in std_logic;
    dIn                 : in std_logic_vector(kWidthData-1 downto 0);

    -- Data Out --
    validOut            : out std_logic;
    dOut                : out std_logic_vector(kWidthData-1 downto 0)
  );
end DelimiterReplacer;

architecture RTL of DelimiterReplacer is
  attribute mark_debug  : boolean;

  -- Internal signals -----------------------------------------------
  signal data_type              : std_logic_vector(kWidthDataType-1 downto 0);
  signal num_word, reg_num_word : unsigned(kPosHbdTransSize'length-4 downto 0);

  signal is_1st_delimiter       : std_logic;

  -- debug --
  attribute mark_debug of num_word  : signal is enDEBUG;
  attribute mark_debug of validIn   : signal is enDEBUG;
  attribute mark_debug of dIn       : signal is enDEBUG;
  attribute mark_debug of is_1st_delimiter       : signal is enDEBUG;

begin
  -- =========================== body ===============================

  data_type   <= dIn(kPosHbdDataType'range);

  -- Count data ---------------------------------------------------
  u_count : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(syncReset = '1') then
        num_word  <= (others => '0');
      else
        if(validIn = '1' and checkDelimiter(data_type) = false) then
          num_word  <= num_word + 1;
        elsif(validIn = '1' and checkDelimiter(data_type) = true) then
          num_word  <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  u_replace : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(syncReset = '1') then
        is_1st_delimiter  <= '1';
        reg_num_word      <= (others => '0');
      else
        validOut          <= validIn;
        if(validIn = '1' and checkDelimiter(data_type) = true) then
          if(is_1st_delimiter = '1') then
            dOut(kPosHbdDataType'range)  <= dIn(kPosHbdDataType'range);
            dOut(kPosHbdReserve1'range)  <= dIn(kPosHbdReserve1'range);
            dOut(kPosHbdFlag'range)      <= dIn(kPosHbdFlag'range);
            dOut(kPosHbdOffset'range)    <= std_logic_vector(LaccpFineOffset);
            dOut(kPosHbdHBFrame'range)   <= dIn(kPosHbdHBFrame'range);
--            dOut              <= dIn;
            reg_num_word      <= num_word;
            is_1st_delimiter  <= '0';
          else
            dOut(kPosHbdDataType'range)  <= kDatatypeHeartbeatT2;
            dOut(kPosHbdReserve1'range)  <= dIn(kPosHbdReserve1'range);
            --dOut(kPosHbdUserReg'range)   <= dIn(kPosHbdUserReg'range);
            dOut(kPosHbdUserReg'range)   <= userReg;
            dOut(kPosHbdGenSize'range)   <= dIn(kPosHbdGenSize'range);
            dOut(kPosHbdTransSize'range) <= std_logic_vector(reg_num_word) & "000";

            is_1st_delimiter  <= '1';
          end if;
        else
          dOut   <= dIn;
        end if;
      end if;
    end if;
  end process;

end RTL;
