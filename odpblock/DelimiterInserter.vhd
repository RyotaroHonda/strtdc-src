library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defTDC.all;
use mylib.defDelimiter.all;

entity DelimiterInserter is
  generic(
    kNumInput   : integer:= 32;
    enDEBUG     : boolean:= false
  );
  port(
    genChOffset : in std_logic;

    clk         : in std_logic;   -- base clock
    syncReset   : in std_logic;   -- Synchronous reset

    -- TDC in --
    validIn         : in  std_logic_vector(kNumInput-1 downto 0);
    dInTiming       : in  TimingArrayType(kNumInput-1 downto 0)(kPosTiming'length-1 downto 0);
    isLeading       : in  std_logic_vector(kNumInput-1 downto 0);
    isConflicted    : in  std_logic_vector(kNumInput-1 downto 0);
    dInToT          : in  TOTArrayType(kNumInput-1 downto 0)(kPosTot'length-1 downto 0);

    -- delimiter in --
    validDelimiter  : in  std_logic;
    dInDelimiter    : in  std_logic_vector(kWidthData-1 downto 0);
    daqOn           : in  std_logic;
    hbfThrottlingOn : in  std_logic;

    -- Pairing out --
    validOut        : out std_logic_vector(kNumInput-1 downto 0);
    dOut            : out DataArrayType(kNumInput-1 downto 0)
  );
end DelimiterInserter;

architecture RTL of DelimiterInserter is
  attribute mark_debug  : boolean;


  signal channel_offset   : integer:=0;

  signal tdc_data_valid   : std_logic_vector(kNumInput-1 downto 0);
  signal tdc_data         : DataArrayType(kNumInput-1 downto 0);

  signal delimiter_valid  : std_logic;
  signal delimiter_data   : std_logic_vector(kWidthData-1 downto 0);

  signal data_valid_out   : std_logic_vector(kNumInput-1 downto 0);
  signal data_out         : DataArrayType(kNumInput-1 downto 0);

  -- debug ----------------------------------------------------------
--  attribute mark_debug of delimiter_data  : signal is enDEBUG;
  attribute mark_debug of delimiter_valid : signal is enDEBUG;

--  attribute mark_debug of data_out        : signal is enDEBUG;
  attribute mark_debug of data_valid_out  : signal is enDEBUG;

begin
  -- =========================== body ===============================

  channel_offset  <= kNumInput when(genChOffset = '1') else 0;

  delimiter_valid <= validDelimiter;
  delimiter_data  <= dInDelimiter;

--  u_delimiter : process(clk)
--  begin
--    if(clk'event and clk = '1') then
--      if(syncReset = '1') then
--        delimiter_valid   <= '0';
--      else
--        if(validDelimiter = '1') then
--          delimiter_valid   <= '1';
--          delimiter_data    <= dInDelimiter;
----          if(unsigned(validIn) /= 0) then -- conflict flag
----            delimiter_data(kIndexConflict + kLSBFlag)  <= '1';
----          end if;
--        else
--          delimiter_valid   <= '0';
--        end if;
--      end if;
--    end if;
--  end process;

  gen_ch : for i in 0 to kNumInput-1 generate

    u_tdc : process(clk)
    begin
      if(clk'event and clk = '1') then
        if(syncReset = '1') then
          tdc_data_valid(i)   <= '0';
        else
          if(validIn(i) ='1' and hbfThrottlingOn = '0') then
            if(isLeading(i) = '1') then
              tdc_data(i)(kPosHbdDataType'range)  <= kDatatypeTDCData;
            else
              tdc_data(i)(kPosHbdDataType'range)  <= kDatatypeTDCDataT;
            end if;

            tdc_data_valid(i)                <= '1';
            tdc_data(i)(kPosChannel'range)   <= std_logic_vector(to_unsigned(i+channel_offset, kPosChannel'length));
            tdc_data(i)(kPosTot'range)       <= dInToT(i);
            tdc_data(i)(kPosTiming'high downto 0) <= (kPosTiming'range => dInTiming(i), others => '0');
          else
            tdc_data_valid(i) <= '0';
          end if;
        end if;
      end if;
    end process;

    u_out : process(clk)
    begin
      if(clk'event and clk = '1') then
        if(syncReset = '1') then
          data_valid_out(i) <= '0';
        else
          if(daqOn = '1') then
            if(delimiter_valid = '1') then
              data_valid_out(i) <= '1';
              data_out(i)       <= delimiter_data;
            elsif(tdc_data_valid(i) = '1') then
              data_valid_out(i) <= '1';
              data_out(i)       <= tdc_data(i);
            else
              data_valid_out(i) <= '0';
            end if;
          else
            data_valid_out(i) <= '0';
          end if;
        end if;
      end if;
    end process;

  end generate;

  validOut  <= data_valid_out;
  dOut      <= data_out;

end RTL;
