library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defTDC.all;
use mylib.defLACCP.all;
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

    -- LACCP --
    enOfsCorr       : in std_logic;
    LaccpFineOffset : in signed(kWidthLaccpFineOffset-1 downto 0);

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

  -- Ofs correction --
  constant kWidthCarryCheck   : integer:= kWidthLaccpFineOffset-2;
  constant kLengthCorrBuf     : integer:= 3;

  -- data input
  signal delimiter_valid      : std_logic;
  signal delimiter_data       : std_logic_vector(kWidthData-1 downto 0);

  signal tdc_valid            : std_logic_vector(kLengthCorrBuf-1 downto 0);
  signal tdc_data             : DataArrayType(kLengthCorrBuf-1 downto 0);

  -- data merge
  constant kBuffLength        : integer:= 3;
  constant kDelimiterBuffLength : integer:= 3+1;
  signal buff_delimiter_valid : std_logic_vector(kDelimiterBuffLength-1 downto 0)  := (others=>'0');
  signal buff_delimiter_data  : DataArrayType(kDelimiterBuffLength-1 downto 0);

  signal delayed_daq_on       : std_logic;
  signal sr_daq_on            : std_logic_vector(kDelimiterBuffLength-1 downto 0);

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
    variable full_length_timing   : signed(28 downto 0);
    variable full_length_ofs      : signed(28 downto 0);
    variable full_length_ctime    : signed(28 downto 0);
    variable temp_fine_count      : std_logic_vector(kWidthCarryCheck-1 downto 0);
    variable carry_check          : signed(kWidthCarryCheck-1 downto 0);
    variable index                : integer range 0 to 2:= 1;
  begin
    if(clk'event and clk = '1') then
      if(syncReset = '1') then
        tdc_valid   <= (others => '0');
      else
        if(validIn ='1' and hbfThrottlingOn = '0') then
          full_length_ofs     := (LaccpFineOffset'high downto 0 => LaccpFineOffset, others => LaccpFineOffset(LaccpFineOffset'high));
          full_length_timing  := (full_length_timing'high downto full_length_timing'high - dInTiming'length +1 => signed(dInTiming), others => '0');
          full_length_ctime   := full_length_timing + full_length_ofs;

          temp_fine_count     := (dInTiming(kWidthFineCount downto 0), others => '0');
          carry_check         := signed(temp_fine_count) + signed(LaccpFineOffset(kWidthCarryCheck-1 downto 0));
          if((carry_check(kWidthCarryCheck-1) xor temp_fine_count(kWidthCarryCheck-1)) = '1' and enOfsCorr = '1') then
            if(LaccpFineOffset(LaccpFineOffset'high) = '1') then
              index       := 2;

              tdc_valid(0)  <= '0';
              tdc_valid(1)  <= tdc_valid(2);
              tdc_data(1)   <= tdc_data(2);

            else
              index       := 0;

              tdc_valid(2)  <= tdc_valid(1);
              tdc_valid(1)  <= tdc_valid(0);
              tdc_data(2)   <= tdc_data(1);
              tdc_data(1)   <= tdc_data(0);
            end if;
          else
            index       := 1;

            tdc_valid(0)  <= '0';
            tdc_valid(2)  <= tdc_valid(1);
            tdc_data(2)   <= tdc_data(1);
          end if;

          if(isLeading = '1') then
            tdc_data(index)(kPosHbdDataType'range)  <= kDatatypeTDCData;
          else
            tdc_data(index)(kPosHbdDataType'range)  <= kDatatypeTDCDataT;
          end if;

          tdc_valid(index)                           <= '1';
          tdc_data(index)(kPosChannel'range)         <= channelNum;
          tdc_data(index)(kPosTot'range)             <= dInToT;

          if(enOfsCorr = '1') then
            tdc_data(index)(kPosTiming'high downto 0)  <= (kPosTiming'range => std_logic_vector(full_length_ctime(full_length_ctime'high downto full_length_ctime'high - dInTiming'length +1)), others => '0');
          else
            tdc_data(index)(kPosTiming'high downto 0)  <= (kPosTiming'range => dInTiming, others => '0');
          end if;
        else
          tdc_valid   <= tdc_valid(1 downto 0) & '0';
          tdc_data    <= tdc_data(1 downto 0) & X"0000000000000000";
        end if;
      end if;
    end if;
  end process;

  -- data merge
  delayed_daq_on  <= sr_daq_on(kDelimiterBuffLength-1);
  buff_delimiter : process(clk)
  begin
    if(clk'event and clk = '1') then
      sr_daq_on <= sr_daq_on(kDelimiterBuffLength-2 downto 0) & daqOn;

      buff_delimiter_valid(kDelimiterBuffLength-1) <= delimiter_valid;
      buff_delimiter_data(kDelimiterBuffLength-1)  <= delimiter_data;
      for i in 0 to kDelimiterBuffLength-2 loop
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
          buff_tdc_valid(2) <= tdc_valid(2);
          buff_tdc_data(2)  <= tdc_data(2);
        end if;
      -- conflicted with delimiter (buff is emtyp)
      else
        if(buff_tdc_valid(2)='0' and buff_tdc_valid(1)='1')then
          buff_tdc_valid(2) <= tdc_valid(2);
          buff_tdc_data(2)  <= tdc_data(2);
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
          buff_tdc_valid(1) <= tdc_valid(2);
          buff_tdc_data(1)  <= tdc_data(2);
        end if;
      -- conflicted with delimiter (buff is emtyp)
      else
        if(buff_tdc_valid(1)='0' and buff_tdc_valid(0)='1')then
          buff_tdc_valid(1) <= tdc_valid(2);
          buff_tdc_data(1)  <= tdc_data(2);
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
          buff_tdc_valid(0) <= tdc_valid(2);
          buff_tdc_data(0)  <= tdc_data(2);
        end if;
      -- conflicted with delimiter (buff is emtyp)
      else
        if(buff_tdc_valid(0)='0')then
          buff_tdc_valid(0) <= tdc_valid(2);
          buff_tdc_data(0)  <= tdc_data(2);
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
