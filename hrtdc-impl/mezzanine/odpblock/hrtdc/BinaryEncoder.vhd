library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_misc.all;
use mylib.defHrTimingUnit.all;

entity BinaryEncoder is
    port (
        RST         : in std_logic;
        CLK         : in std_logic;
        LeadIn      : in std_logic_vector(kNumRTaps-1 downto 0);
        hitDetect   : out std_logic;
        dataOut     : out std_logic_vector(kWidthFine-1 downto 0)
    );
end BinaryEncoder;

architecture RTL of BinaryEncoder is
    attribute   mark_debug : string;

    constant    NbinLow  : positive := 8;
    constant    NbinHigh : positive := 8;

    constant    NbitLow  : positive  := 3;
    constant    NbitHigh : positive  := 3;

    -- signal decralation ------------------------------------------------
    signal virtual_in     : std_logic_vector(LeadIn'length-1 downto 0);

    -- first stage --
    signal high_vector      : std_logic_vector(NbinHigh-1 downto 0);
    signal reg_high_vector  : std_logic_vector(NbinHigh-1 downto 0);
    signal bit_exist        : std_logic;
    signal bit_exist_buf    : std_logic;
    signal bit_exist_in     : std_logic;
    signal bit_exist_prev, bit_exist_current        : std_logic;

    type LowArray is array(NbinHigh-1 downto 0) of  std_logic_vector(NbinLow-1 downto 0);
    signal reg_low_vector   : LowArray;

    -- second stage --
    signal data_high    : std_logic_vector(NbitHigh-1 downto 0);
    signal buf_high     : std_logic_vector(NbitHigh-1 downto 0);
    type dataArray is array(NbinHigh-1 downto 0) of std_logic_vector(NbitLow-1 downto 0);
    signal data_low     : dataArray;

    type dataBuf is array(1 downto 0) of std_logic_vector(NbitLow-1 downto 0);
    signal buf_low     : dataArray;

    -- third stage --
    signal data_binary          : std_logic_vector(kWidthFine-1 downto 0);
    signal reg_data_binary      : std_logic_vector(kWidthFine-1 downto 0);

    -- final stage --

    -- debug --
    --attribute mark_debug of reg_high_vector : signal is "true";
    --attribute mark_debug of reg_data_binary : signal is "true";
    --attribute mark_debug of bit_exist : signal is "true";

begin
    -- ============================= body ================================
    virtual_in  <=  LeadIn;

    -- first stage ------------------------------------------------------------
    gen_high_vector : for i in 0 to NbinHigh-1 generate
    begin
        high_vector(i)  <= or_reduce(virtual_in(NbinLow*(i+1) -1 downto NbinLow*i));
    end generate;

--    u_first_buf : process(RST, CLK)
    u_first_buf : process(CLK)
    begin
--        if(RST = '1') then
--            reg_high_vector <= (others => '0');
--            for i in 0 to NbinHigh-1 loop
--                reg_low_vector(i) <= (others => '0');
--            end loop;
--    elsif(CLK'event AND CLK = '1') then
      if(CLK'event AND CLK = '1') then
            reg_high_vector <= high_vector;

            for i in 0 to NbinHigh-1 loop
                reg_low_vector(i)   <= virtual_in(NbinLow*(i+1) -1 downto NbinLow*i);
            end loop;
        end if;
    end process;

    -- second stage -----------------------------------------------------------
    -- high bits encode
--    u_highbit_encoder : process(RST, CLK)
--    begin
--        if(RST = '1') then
--            data_high   <= (others => '0');
--        elsif(CLK'event AND CLK = '1') then
    u_highbit_encoder : process(CLK)
    begin
      if(CLK'event AND CLK = '1') then
        case reg_high_vector is
          when "00000000" => data_high   <= "000"; bit_exist  <= '0';
          when "00000001" => data_high   <= "000"; bit_exist  <= '1';
          when "00000010" => data_high   <= "001"; bit_exist  <= '1';
          when "00000100" => data_high   <= "010"; bit_exist  <= '1';
          when "00001000" => data_high   <= "011"; bit_exist  <= '1';
          when "00010000" => data_high   <= "100"; bit_exist  <= '1';
          when "00100000" => data_high   <= "101"; bit_exist  <= '1';
          when "01000000" => data_high   <= "110"; bit_exist  <= '1';
          when "10000000" => data_high   <= "111"; bit_exist  <= '1';
          when others     => data_high   <= "000"; bit_exist  <= '0';
--                when "000000" => data_high   <= "000"; bit_exist  <= '0';
--                when "000001" => data_high   <= "000"; bit_exist  <= '1';
--                when "000010" => data_high   <= "001"; bit_exist  <= '1';
--                when "000100" => data_high   <= "010"; bit_exist  <= '1';
--                when "001000" => data_high   <= "011"; bit_exist  <= '1';
--                when "010000" => data_high   <= "100"; bit_exist  <= '1';
--                when "100000" => data_high   <= "101"; bit_exist  <= '1';
--                when others     => data_high   <= "000"; bit_exist  <= '0';
        end case;
      end if;
    end process;

    -- low bits encode
    gen_lowbit_encoder : for i in 0 to NbinHigh-1 generate
    begin
      -- u_lowbit_encoder : process(RST, CLK)
      -- begin
      --   if(RST = '1') then
      --     data_low(i) <= (others => '0');
      --   elsif(CLK'event AND CLK = '1') then
      u_lowbit_encoder : process(CLK)
      begin
        if(CLK'event AND CLK = '1') then
          case reg_low_vector(i) is
            when "00000000" => data_low(i)   <= "000";
            when "00000001" => data_low(i)   <= "000";
            when "00000010" => data_low(i)   <= "001";
            when "00000100" => data_low(i)   <= "010";
            when "00001000" => data_low(i)   <= "011";
            when "00010000" => data_low(i)   <= "100";
            when "00100000" => data_low(i)   <= "101";
            when "01000000" => data_low(i)   <= "110";
            when "10000000" => data_low(i)   <= "111";
            when others     => data_low(i)   <= "000";
          end case;
        end if;
      end process;
    end generate;

    -- third stage -----------------------------------------------------------
    u_buf : process(CLK)
    begin
        if(CLK'event AND CLK = '1') then
            buf_low(0)(0)   <= data_low(3)(0) OR data_low(2)(0) OR data_low(1)(0) OR data_low(0)(0);
            buf_low(1)(0)   <= data_low(7)(0) OR data_low(6)(0) OR data_low(5)(0) OR data_low(4)(0);

            buf_low(0)(1)   <= data_low(3)(1) OR data_low(2)(1) OR data_low(1)(1) OR data_low(0)(1);
            buf_low(1)(1)   <= data_low(7)(1) OR data_low(6)(1) OR data_low(5)(1) OR data_low(4)(1);

            buf_low(0)(2)   <= data_low(3)(2) OR data_low(2)(2) OR data_low(1)(2) OR data_low(0)(2);
            buf_low(1)(2)   <= data_low(7)(2) OR data_low(6)(2) OR data_low(5)(2) OR data_low(4)(2);

            buf_high        <= data_high;

            bit_exist_buf   <= bit_exist;
        end if;
    end process;

    data_binary(0)  <= buf_low(1)(0) OR buf_low(0)(0);
    data_binary(1)  <= buf_low(1)(1) OR buf_low(0)(1);
    data_binary(2)  <= buf_low(1)(2) OR buf_low(0)(2);
    data_binary(kWidthFine-1 downto 3)    <= buf_high;
    bit_exist_in    <= bit_exist_buf;

    --data_binary(0)  <= data_low(7)(0) OR data_low(6)(0) OR data_low(5)(0) OR data_low(4)(0) OR data_low(3)(0) OR data_low(2)(0) OR data_low(1)(0) OR data_low(0)(0);
    --data_binary(1)  <= data_low(7)(1) OR data_low(6)(1) OR data_low(5)(1) OR data_low(4)(1) OR data_low(3)(1) OR data_low(2)(1) OR data_low(1)(1) OR data_low(0)(1);
    --data_binary(2)  <= data_low(7)(2) OR data_low(6)(2) OR data_low(5)(2) OR data_low(4)(2) OR data_low(3)(2) OR data_low(2)(2) OR data_low(1)(2) OR data_low(0)(2);
    --data_binary(0)  <= data_low(5)(0) OR data_low(4)(0) OR data_low(3)(0) OR data_low(2)(0) OR data_low(1)(0) OR data_low(0)(0);
    --data_binary(1)  <= data_low(5)(1) OR data_low(4)(1) OR data_low(3)(1) OR data_low(2)(1) OR data_low(1)(1) OR data_low(0)(1);
    --data_binary(2)  <= data_low(5)(2) OR data_low(4)(2) OR data_low(3)(2) OR data_low(2)(2) OR data_low(1)(2) OR data_low(0)(2);

    --data_binary(kWidthFine-1 downto 3)    <= data_high;

    u_hit_detect : process(CLK)
    begin
        if(CLK'event AND CLK = '1') then
          if(RST = '1') then
            bit_exist_prev      <= '0';
            bit_exist_current   <= '0';
          else
            reg_data_binary     <= data_binary;
            bit_exist_current   <= bit_exist_in;
            bit_exist_prev      <= bit_exist_current;
          end if;
        end if;
    end process;

    u_fine_count : process(CLK)
    begin
        if(CLK'event AND CLK = '1') then
          if(RST = '1') then
            hitDetect   <= '0';
--            dataOut     <= (others => '0');
          else
            dataOut     <= reg_data_binary;
              if(bit_exist_prev = '0' AND bit_exist_current = '1') then
                  hitDetect   <= '1';
              else
                  hitDetect   <= '0';
  --                dataOut     <= (others => '0');
              end if;
            end if;
        end if;
    end process;

end RTL;
