library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defTDC.all;
use mylib.defDelimiter.all;

entity TOTFilter is
  port
    (
      syncReset         : in std_logic;
      clk               : in std_logic;
      enFilter          : in std_logic;
      minTh             : in std_logic_vector(kPosTot'length-1 downto 0);
      maxTh             : in std_logic_vector(kPosTot'length-1 downto 0);
      enZeroThrough     : in std_logic;

      -- Data In --
      validIn           : in std_logic;
      dIn               : in std_logic_vector(kWidthData-1 downto 0);

      -- Out --
      validOut          : out std_logic;
      dOut              : out std_logic_vector(kWidthData-1 downto 0)
    );
end TOTFilter;

architecture RTL of TOTFilter is
  -- Signal decralation ---------------------------------------------
  signal tot_value  : std_logic_vector(kPosTot'length-1 downto 0);
  signal data_type  : std_logic_vector(kWidthDataType-1 downto 0);

begin
  -- =========================== body ===============================
  tot_value   <= dIn(kPosTot'range);
  data_type   <= dIn(kPosHbdDataType'range);

  u_filter : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(syncReset = '1') then
        validOut  <= '0';
        dOut      <= (others => '0');
      else
        dOut          <= dIn;

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
