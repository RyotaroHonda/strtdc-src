library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defTDC.all;
use mylib.defDelimiter.all;

entity DelimiterInserter is
  generic(
    enDEBUG     : boolean:= false
  );
  port(
    clk         : in std_logic;   -- base clock
    syncReset   : in std_logic;   -- Synchronous reset
    userRegIn   : in std_logic_vector(kPosHbdUserReg'length-1 downto 0);
    channelNum  : in std_logic_vector(kPosChannel'length-1 downto 0);

    -- TDC in --
    validIn         : in  std_logic;
    dInTiming       : in  std_logic_vector(kPosTiming'length-1 downto 0);
    isLeading       : in  std_logic;
    isConflicted    : in  std_logic;
    dInToT          : in  std_logic_vector(kPosTot'length-1 downto 0);

    -- delimiter in --
    validDelimiter  : in  std_logic;
    dInDelimiter    : in  std_logic_vector(kWidthData-1 downto 0);
    daqOn           : in  std_logic;
    hbfThrottlingOn : in  std_logic;

    -- Data out --
    validOut        : out std_logic;
    dOut            : out std_logic_vector(kWidthData-1 downto 0)
  );
end DelimiterInserter;

architecture RTL of DelimiterInserter is
  attribute mark_debug  : boolean;

  -- data input
  signal delimiter_valid      : std_logic;
  signal delimiter_data       : std_logic_vector(kWidthData-1 downto 0);

  signal tdc_valid            : std_logic;
  signal tdc_data             : std_logic_vector(kWidthData-1 downto 0);

  -- data merge
  constant kBuffLength         : integer:= 3;
  signal buff_delimiter_valid : std_logic_vector(kBuffLength-1 downto 0)  := (others=>'0');
  signal buff_delimiter_data  : DataArrayType(kBuffLength-1 downto 0);

  signal delayed_daq_on       : std_logic;
  signal sr_daq_on            : std_logic_vector(kBuffLength-1 downto 0);

  signal buff_tdc_valid       : std_logic_vector(kBuffLength-1 downto 0)  := (others=>'0');
  signal buff_tdc_data        : DataArrayType(kBuffLength-1 downto 0);

  signal merge_valid          : std_logic;
  signal merge_data           : std_logic_vector(kWidthData-1 downto 0);

  -- data output
  signal is_2nd_delimiter     : std_logic;
  signal num_word             : unsigned(kPosHbdGenSize'length-4 downto 0);

  signal data_valid_out       : std_logic;
  signal data_out             : std_logic_vector(kWidthData-1 downto 0);

  -- debug ----------------------------------------------------------
--  attribute mark_debug of delimiter_data  : signal is enDEBUG;
  attribute mark_debug of delimiter_valid : signal is enDEBUG;

--  attribute mark_debug of data_out        : signal is enDEBUG;
  attribute mark_debug of data_valid_out  : signal is enDEBUG;

begin
  -- =========================== body ===============================

  -- data input
  delimiter_valid <= validDelimiter;
  delimiter_data  <= dInDelimiter;

  u_tdc : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(syncReset = '1') then
        tdc_valid  <= '0';
      else
        if(validIn ='1' and hbfThrottlingOn = '0') then
          if(isLeading = '1') then
            tdc_data(kPosHbdDataType'range)  <= kDatatypeTDCData;
          else
            tdc_data(kPosHbdDataType'range)  <= kDatatypeTDCDataT;
          end if;

          tdc_valid                           <= '1';
          tdc_data(kPosChannel'range)         <= channelNum;
          tdc_data(kPosTot'range)             <= dInToT;
          tdc_data(kPosTiming'high downto 0)  <= (kPosTiming'range => dInTiming, others => '0');
        else
          tdc_valid  <= '0';
        end if;
      end if;
    end if;
  end process;

  -- data merge
  delayed_daq_on  <= sr_daq_on(kBuffLength-1);
  buff_delimiter : process(clk)
  begin
    if(clk'event and clk = '1') then
      sr_daq_on <= sr_daq_on(kBuffLength-2 downto 0) & daqOn;

      buff_delimiter_valid(kBuffLength-1) <= delimiter_valid;
      buff_delimiter_data(kBuffLength-1)  <= delimiter_data;
      for i in 0 to kBuffLength-2 loop
        buff_delimiter_valid(i) <= buff_delimiter_valid(i+1);
        buff_delimiter_data(i)  <= buff_delimiter_data(i+1);
      end loop;
    end if;
  end process;

  buff_tdc_2 : process(clk)
  begin
    if(clk'event and clk = '1') then
      -- without conflict (clean buffer)
      if(buff_delimiter_valid(0)='0')then
        if(buff_tdc_valid(2)='1')then
          buff_tdc_valid(2) <= tdc_valid;
          buff_tdc_data(2)  <= tdc_data;
        end if;
      -- conflicted with delimiter (buff is emtyp)
      else
        if(buff_tdc_valid(2)='0' and buff_tdc_valid(1)='1')then
          buff_tdc_valid(2) <= tdc_valid;
          buff_tdc_data(2)  <= tdc_data;
        end if;
      end if;
    end if;
  end process;

  buff_tdc_1 : process(clk)
  begin
    if(clk'event and clk = '1') then
      -- without conflict (clean buffer)
      if(buff_delimiter_valid(0)='0')then
        if(buff_tdc_valid(2)='1')then
          buff_tdc_valid(1) <= buff_tdc_valid(2);
          buff_tdc_data(1)  <= buff_tdc_data(2);
        elsif(buff_tdc_valid(1)='1')then
          buff_tdc_valid(1) <= tdc_valid;
          buff_tdc_data(1)  <= tdc_data;
        end if;
      -- conflicted with delimiter (buff is emtyp)
      else
        if(buff_tdc_valid(1)='0' and buff_tdc_valid(0)='1')then
          buff_tdc_valid(1) <= tdc_valid;
          buff_tdc_data(1)  <= tdc_data;
        end if;
      end if;
    end if;
  end process;

  buff_tdc_0 : process(clk)
  begin
    if(clk'event and clk = '1') then
      -- without conflict (clean buffer)
      if(buff_delimiter_valid(0)='0')then
        if(buff_tdc_valid(1)='1')then
          buff_tdc_valid(0) <= buff_tdc_valid(1);
          buff_tdc_data(0)  <= buff_tdc_data(1);
        else
          buff_tdc_valid(0) <= tdc_valid;
          buff_tdc_data(0)  <= tdc_data;
        end if;
      -- conflicted with delimiter (buff is emtyp)
      else
        if(buff_tdc_valid(0)='0')then
          buff_tdc_valid(0) <= tdc_valid;
          buff_tdc_data(0)  <= tdc_data;
        end if;
      end if;
    end if;
  end process;

  -- data output
  merger : process(clk)
  begin
    if(clk'event and clk = '1') then
      -- reset or daq_off
      if(syncReset = '1' or delayed_daq_on = '0') then
        data_valid_out    <= '0';
        is_2nd_delimiter  <= '0';
        num_word          <= (others=>'0');

      -- delimiter
      elsif(buff_delimiter_valid(0)='1')then
        data_valid_out    <= '1';
        -- insert the gen tdc size into the 2nd delimiter word.
        if(is_2nd_delimiter='1')then
          data_out(kPosHbdGenSize'range) <= std_logic_vector(num_word) & "000";
          data_out(kPosHbdUserReg'range) <= userRegIn;
          is_2nd_delimiter  <= '0';
          num_word          <= (others=>'0');
        else
          data_out          <= buff_delimiter_data(0);
          is_2nd_delimiter  <= '1';
        end if;

      -- tdc data
      else
        data_valid_out  <= buff_tdc_valid(0);
        data_out        <= buff_tdc_data(0);
        -- count the leading tdc data
        if(buff_tdc_data(0)(kPosHbdDataType'range)=kDatatypeTDCData and buff_tdc_valid(0) = '1')then
          num_word      <= num_word + 1;
        end if;

      end if;
    end if;
  end process;

  validOut  <= data_valid_out;
  dOut      <= data_out;

end RTL;
