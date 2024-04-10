library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use mylib.defDDRTransmitter.all;

entity DataTransmitter is
  port
    (
      -- system --
      rstClk    : in std_logic; -- clk_reset
      testMode  : in std_logic;

      -- Data In --
      clkSer    : in std_logic;
      clkPar    : in std_logic;
      dIn       : in std_logic_vector(63 downto 0);
      weIn      : in std_logic;
--      reOut     : out std_logic;

      -- DDR Out --
      clkDDRp   : out std_logic; -- clk forward p
      clkDDRn   : out std_logic; -- clk forward n

      dOutDDRDp : out std_logic_vector(kNumDDR-1 downto 0);
      dOutDDRDn : out std_logic_vector(kNumDDR-1 downto 0)

);
end DataTransmitter;

architecture RTL of DataTransmitter is

  -- Signal decralation ------------------------------------------------------
  signal delay_reset    : std_logic_vector(kNumResetDelay-1 downto 0);
  signal rst_io         : std_logic;

  signal ddrd_p         : DDRDataType;
  signal ddrd_n         : DDRDataType;

  signal data_in        : SerDesDataType;

  -- ODDR ip (with clk forward)
  component ddr_oserdes_clk_fwd
    generic
      (-- width of the data for the system
        SYS_W       : integer := 1;
        -- width of the data for the device
        DEV_W       : integer := 8);
    port
      (
        -- From the device out to the system
        data_out_from_device    : in  std_logic_vector(DEV_W-1 downto 0);
        data_out_to_pins_p      : out std_logic_vector(SYS_W-1 downto 0);
        data_out_to_pins_n      : out std_logic_vector(SYS_W-1 downto 0);
        clk_to_pins_p           : out std_logic;
        clk_to_pins_n           : out std_logic;

        -- Clock and reset signals
        clk_in                  : in    std_logic;  -- Fast clock from PLL/MMCM
        clk_div_in              : in    std_logic;  -- Slow clock from PLL/MMCM
        clk_reset               : in    std_logic;  -- Reset signal for Clock circuit
        io_reset                : in    std_logic); -- Reset signal for IO circuit
  end component;

  -- ODDR ip (without clk forward)
  component ddr_oserdes
    generic
      (-- width of the data for the system
        SYS_W       : integer := 1;
        -- width of the data for the device
        DEV_W       : integer := 8);
    port
      (
        -- From the device out to the system
        data_out_from_device    : in  std_logic_vector(DEV_W-1 downto 0);
        data_out_to_pins_p      : out std_logic_vector(SYS_W-1 downto 0);
        data_out_to_pins_n      : out std_logic_vector(SYS_W-1 downto 0);

        -- Clock and reset signals
        clk_in                  : in    std_logic;  -- Fast clock from PLL/MMCM
        clk_div_in              : in    std_logic;  -- Slow clock from PLL/MMCM
        io_reset                : in    std_logic); -- Reset signal for IO circuit
  end component;


begin
  -- ============================== body ==================================
  -- connection -----------------------------------------------------------
--  reOut         <= '1';


  -- Reset for I/O --------------------------------------------------------
  rst_io        <= delay_reset(kNumResetDelay-1);
  u_rstIO : process(rstClk, clkPar)
  begin
    if(rstClk = '1') then
      delay_reset       <= (others => '1');
    elsif(clkPar'event and clkPar = '1') then
      delay_reset       <= delay_reset(kNumResetDelay-2 downto 0) & '0';
    end if;
  end process;

  -- Data in selector -----------------------------------------------------
  u_data_sel : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(rst_io = '1') then
        for i in 0 to kNumDDR-1 loop
          data_in(i)      <= (others => '0');
        end loop;
      else
        if(testMode = '1') then
          for i in 0 to kNumDDR-1 loop
            data_in(i)      <= kRefBit;
          end loop;
        else
          if(weIn = '1') then
  --          -- Write enable --
  --          data_in(4)(7)   <= '1';
  --          data_in(3)(7)   <= '1';
  --          data_in(2)(7)   <= '1';
  --          data_in(1)(7)   <= '1';
  --          data_in(0)(7)   <= '1';
  --
  --          -- Data body --
  --          data_in(4)(6 downto 0)   <= "000" & dIn(31 downto 28);
  --          data_in(3)(6 downto 0)   <= dIn(27 downto 21);
  --          data_in(2)(6 downto 0)   <= dIn(20 downto 14);
  --          data_in(1)(6 downto 0)   <= dIn(13 downto 7);
  --          data_in(0)(6 downto 0)   <= dIn(6  downto 0);

            for i in 0 to kNumDDR-1 loop
              data_in(i)(7)           <= '1';
              data_in(i)(6 downto 0)  <= dIn(7*(i+1)-1 downto 7*i);
            end loop;
          else
            for i in 0 to kNumDDR-1 loop
              data_in(i)      <= "01011010";
            end loop;
          end if;
        end if;
      end if;

    end if;
  end process;

  -- SERDES instance ------------------------------------------------------
  u_gen_oserdes : for i in 0 to kNumDDR-1 generate
    dOutDDRDp(i)        <= ddrd_p(i)(0);
    dOutDDRDn(i)        <= ddrd_n(i)(0);

    -- 1st serdes with clk forward --
    gen_serdes_wclk : if (i = 0) generate
      u_oserdes_wclk : ddr_oserdes_clk_fwd
        port map
        (
          data_out_from_device      => data_in(i),
          data_out_to_pins_p        => ddrd_p(i),
          data_out_to_pins_n        => ddrd_n(i),
          clk_to_pins_p             => clkDDRp,
          clk_to_pins_n             => clkDDRn,
          clk_in                    => clkSer,
          clk_div_in                => clkPar,
          clk_reset                 => rstClk,
          io_reset                  => rst_io
        );
    end generate;

    gen_serdes : if(i /= 0) generate
      u_oserdes : ddr_oserdes
        port map
        (
          data_out_from_device      => data_in(i),
          data_out_to_pins_p        => ddrd_p(i),
          data_out_to_pins_n        => ddrd_n(i),
          clk_in                    => clkSer,
          clk_div_in                => clkPar,
          io_reset                  => rst_io
        );
    end generate;

  end generate;


end RTL;
