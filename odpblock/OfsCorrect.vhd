library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library mylib;

entity OfsCorrect is
  generic(
    kWidthOfs   : integer;
    enDEBUG     : boolean:= false
  );
  port(
    clk             : in std_logic;   -- base clock
    syncReset       : in std_logic;   -- Synchronous reset

    -- LACCP --
    enOfsCorr       : in std_logic;
    reducedOfs      : in signed(kWidthOfs-1 downto 0); -- Range : LSB of heartbeat counter + FineCount

    -- TDC in --
    validIn         : in  std_logic;
    dInTiming       : in  std_logic_vector(kWidthOfs-2 downto 0); -- FineCount

    -- Data out --
    validOut        : out std_logic;
    dOut            : out std_logic_vector(kWidthOfs-2 downto 0) -- Corrected FineCout
  );
end OfsCorrect;

architecture RTL of OfsCorrect is
  attribute mark_debug  : boolean;
  constant kZero        : std_logic_vector(kWidthOfs-2 downto 0):= (others => '0');

  -- Ofs correction --
  constant kLengthCorrBuf     : integer:= 3;
  type FCArrayType is array(kLengthCorrBuf-1 downto 0) of std_logic_vector(kWidthOfs-2 downto 0);

  signal tdc_valid            : std_logic_vector(kLengthCorrBuf-1 downto 0);
  signal tdc_data             : FCArrayType;

  -- debug ----------------------------------------------------------
--  attribute mark_debug of data_out        : signal is enDEBUG;

begin
  -- =========================== body ===============================

  validOut  <= tdc_valid(kLengthCorrBuf-1);
  dOut      <= tdc_data(kLengthCorrBuf-1);

  u_tdc : process(clk)
    variable temp_fine_count      : std_logic_vector(kWidthOfs-1 downto 0);
    variable carry_check          : signed(kWidthOfs-1 downto 0);
    variable index                : integer range 0 to 2:= 1;
  begin
    if(clk'event and clk = '1') then
      if(syncReset = '1') then
        tdc_valid   <= (others => '0');
      else
        if(validIn ='1') then
          temp_fine_count     := '0' & dInTiming;
          carry_check         := signed(temp_fine_count) + signed(reducedOfs);
          if((carry_check(kWidthOfs-1) xor temp_fine_count(kWidthOfs-1)) = '1' and enOfsCorr = '1') then
            if(reducedOfs(reducedOfs'high) = '1') then
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

          tdc_valid(index)  <= '1';
          if(enOfsCorr = '1') then
            tdc_data(index) <= std_logic_vector(carry_check(kWidthOfs-2 downto 0));
          else
            tdc_data(index) <= dInTiming;
          end if;
        else
          tdc_valid   <= tdc_valid(kLengthCorrBuf-2 downto 0) & '0';
          tdc_data    <= tdc_data(kLengthCorrBuf-2 downto 0) & kZero;
        end if;
      end if;
    end if;
  end process;

end RTL;
