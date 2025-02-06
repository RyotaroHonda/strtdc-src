library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defTDC.all;
use mylib.defDelimiter.all;

entity TOTFilter is
  generic(
    enDEBUG         : boolean:= false
  );
  port
    (
      syncReset         : in std_logic;
      clk               : in std_logic;
      enFilter          : in std_logic;
      minTh             : in std_logic_vector(kPosTot'length-1 downto 0);
      maxTh             : in std_logic_vector(kPosTot'length-1 downto 0);
      enZeroThrough     : in std_logic;
      channelNum        : in std_logic_vector(kPosChannel'length-1 downto 0);

      -- Data In --
      validIn           : in std_logic;
      dIn               : in std_logic_vector(kWidthIntData-1 downto 0);

      -- Out --
      validOut          : out std_logic;
      dOut              : out std_logic_vector(kWidthData-1 downto 0)
    );
end TOTFilter;

architecture RTL of TOTFilter is
  attribute mark_debug  : boolean;

  -- Signal decralation ---------------------------------------------
  signal tot_value  : std_logic_vector(kPosTot'length-1 downto 0);
  signal data_type  : std_logic_vector(kWidthDataType-1 downto 0);
  signal is_2nd_delimiter : std_logic;
  signal data_out   : std_logic_vector(dOut'range);

  attribute mark_debug of is_2nd_delimiter : signal is enDEBUG;
  attribute mark_debug of data_type        : signal is enDEBUG;
  attribute mark_debug of data_out         : signal is enDEBUG;
  attribute mark_debug of dIn              : signal is enDEBUG;
  attribute mark_debug of validIn          : signal is enDEBUG;

begin
  -- =========================== body ===============================
  tot_value   <= dIn(kPosITot'range);
  data_type   <= dIn(kPosIHbdDataType'range);
  dOut        <= data_out;

  u_filter : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(syncReset = '1') then
        validOut          <= '0';
        is_2nd_delimiter  <= '0';
        data_out          <= (others => '0');
      else
        if(validIn = '1') then
          if(data_type = kDatatypeTDCData or data_type = kDatatypeTDCDataT) then
            data_out(kPosHbdDataType'range)     <= dIn(kPosIHbdDataType'range);
            data_out(kPosChannel'range)         <= channelNum;
            data_out(kPosTot'range)             <= dIn(kPosITot'range);
            data_out(kPosTiming'high downto 0)  <= (kPosTiming'range => dIn(kPosITiming'range), others => '0');
          elsif(checkDelimiter(data_type) = true and is_2nd_delimiter = '0') then
            -- 1st delimiter --
            data_out(kPosHbdDataType'range)   <= dIn(kPosIHbdDataType'range);
            data_out(kPosHbdReserve1'range)   <= (others => '0');
            data_out(kPosHbdFlag'range)       <= dIn(kPosIHbdFlag'range);
            data_out(kPosHbdHBFrame'range)    <= dIn(kPosIHbdHBFrame'range);
            is_2nd_delimiter              <= '1';
          elsif(checkDelimiter(data_type) = true and is_2nd_delimiter = '1') then
            data_out(kPosHbdDataType'range)   <= dIn(kPosIHbdDataType'range);
            data_out(kPosHbdGenSize'range)    <= dIn(kPosIHbdGenSize'range) & "000";
            is_2nd_delimiter              <= '0';
          end if;
        end if;

        if(data_type = kDatatypeTDCData) then
          if(enFilter = '0') then
            validOut        <= validIn;
          elsif(enFilter = '1' and validIn = '1') then
            if(enZeroThrough = '1' and to_integer(unsigned(tot_value)) = 0) then
              validOut      <= validIn;
            elsif(unsigned(minTh) < unsigned(tot_value) and unsigned(tot_value) < unsigned(maxTh)) then
              validOut      <= validIn;
            else
              validOut      <= '0';
            end if;
          else
            validOut        <= '0';
          end if;
        else
          validOut  <= validIn;
        end if;

      end if;
    end if;
  end process;

end RTL;
