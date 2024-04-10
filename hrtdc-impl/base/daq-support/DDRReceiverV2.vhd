library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library UNISIM;
use UNISIM.VComponents.all;

library mylib;
use mylib.defDDRReceiverV2.all;

Library xpm;
use xpm.vcomponents.all;

entity DDRReceiverV2 is
  generic
    (
      kInvertMask        : InvMaskDdr; -- If true, inverts Rx polarity

      genIDELAYCTRL      : boolean; -- Generate IDELAYCTRL
      kDiffTerm          : boolean; -- IBUF DIFF_TERM
      kIoStandard        : string;  -- IOSTANDARD of IBUFDS
      kIoDelayGroup      : string;  -- IODELAY_GROUP for IDELAYCTRL and IDELAY
      kFreqFastClk       : real;    -- Frequency of SERDES fast clock (MHz).
      kFreqRefClk        : real;    -- Frequency of refclk for IDELAYCTRL (MHz).
      enDEBUG            : boolean:= false
    );
  port
    (
      -- system port --
      rst       : in  std_logic;
      clk       : in  std_logic;
      clkIdelayRef  : in std_logic;

      regDctIn  : in  RegDct2RcvType;
      regDctOut : out RegRcv2DctType;

      -- DDR ports
      clkDDRp   : in std_logic;
      clkDDRn   : in std_logic;

      dinDDRDp  : in std_logic_vector(kNumDDR-1 downto 0);
      dinDDRDn  : in std_logic_vector(kNumDDR-1 downto 0);

      -- User Data --
      rvDdrRx   : out std_logic;
      doutDdrRx : out std_logic_vector(63 downto 0)
);
end DDRReceiverV2;

architecture RTL of DDRReceiverV2 is
  attribute mark_debug          : boolean;
  attribute IODELAY_GROUP       : string;

  -- System --
  signal sync_reset             : std_logic;
  signal sync_reset_ddr         : std_logic;
  signal idelayctrl_ready       : std_logic;

  -- signal decralation -----------------------------------------------
  -- clk_ddr ---> BUFIO (through) -> clk_in     serdes
  --          |-> BUFR  (div 1/4) -> clk_div_in serdes
  signal clk_ddr                        : std_logic; -- from mezzanine
  signal clk_serial, clk_parallel       : std_logic; -- internal clock

  -- SerDes data --
  signal dout_serdes            : SerDesDataType;
  signal ddrrx_is_ready         : std_logic_vector(kNumDDR-1 downto 0);
  signal ddrrx_bitslip_error    : std_logic_vector(kNumDDR-1 downto 0);

  -- dummy --
--  signal dout_or                : std_logic_vector(4 downto 0);


  -- initialize sequence --
  signal start_ddrrx_init          : std_logic;

  signal ddr_iserdes_ready      : std_logic;
  signal bitslip_error          : std_logic;

  -- Clock Domain Crossing --
  signal test_mode      : std_logic;

  signal rst_ddr_buf    : std_logic;
  signal empty_fifo     : std_logic_vector(kNumDDR-1 downto 0);
  signal we_fifo        : std_logic_vector(kNumDDR-1 downto 0);
  signal re_fifo        : std_logic_vector(kNumDDR-1 downto 0);
  signal re_ddr_buffer  : std_logic;
  signal rv_fifo        : std_logic_vector(kNumDDR-1 downto 0);
  signal dout_fifo      : SerDesDataType;

  COMPONENT ddr_buffer
    PORT (
      rst       : IN STD_LOGIC;
      wr_clk    : IN STD_LOGIC;
      rd_clk    : IN STD_LOGIC;
      din       : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      wr_en     : IN STD_LOGIC;
      rd_en     : IN STD_LOGIC;
      dout      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
      full      : OUT STD_LOGIC;
      empty     : OUT STD_LOGIC;
      valid     : OUT STD_LOGIC
      );
  END COMPONENT;

  signal din_ddr_data   : std_logic_vector(kWidthDdrData-1 downto 0);
  signal rv_ddr_buf     : std_logic;

  -- debug ---------------------------------------------------------------
  attribute mark_debug of ddrrx_is_ready      : signal is enDEBUG;
  attribute mark_debug of ddrrx_bitslip_error : signal is enDEBUG;

begin
  -- ======================================================================
  --                                 body
  -- ======================================================================
  gen_idelayctrl : if genIDELAYCTRL = TRUE generate
    attribute IODELAY_GROUP of IDELAYCTRL_inst : label is kIoDelayGroup;
  begin
    IDELAYCTRL_inst : IDELAYCTRL
      port map (
        RDY     => idelayctrl_ready,
        REFCLK  => clkIdelayRef,
        RST     => rst
      );
  end generate;

  -- connection ---------------------------------------------------------
  rvDdrRx     <= rv_ddr_buf;
  doutDdrRx   <= din_ddr_data;

  u_io_buf : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(sync_reset = '1') then
        -- To Dct --
        regDctOut.bitAligned  <= '0';
        regDctOut.bitError    <= '0';
      else
        -- To Dct --
        regDctOut.bitAligned  <= ddr_iserdes_ready;
        regDctOut.bitError    <= bitslip_error;
      end if;
    end if;
  end process;

  -- CDC --
  u_cdc_test_mode: xpm_cdc_single
    generic map (
      DEST_SYNC_FF   => 4,
      SIM_ASSERT_CHK => 0,
      SRC_INPUT_REG  => 1
      )
    port map (
      src_clk  => clk,          src_in   => regDctIn.testModeDDR,
      dest_clk => clk_parallel, dest_out => test_mode
      );

    -- CDC --
  xpm_cdc_pulse_inst: xpm_cdc_pulse
    generic map (
      -- Common module generics
      DEST_SYNC_FF   => 4,
      REG_OUTPUT     => 0,
      RST_USED       => 1,
      SIM_ASSERT_CHK => 0
      )
    port map (
      src_clk  => clk,          src_rst  => sync_reset,     src_pulse  => regDctIn.initDDR,
      dest_clk => clk_parallel, dest_rst => sync_reset_ddr, dest_pulse => start_ddrrx_init
      );

  -- connection ---------------------------------------------------------

  -- DDR clock to Clock buffer --------------------------------------------
  u_CLKDDR_Inst : IBUFDS
    generic map ( DIFF_TERM => TRUE, IBUF_LOW_PWR => TRUE, IOSTANDARD => "LVDS")
    port map ( O => clk_ddr, I => clkDDRp, IB => clkDDRn );

  u_BUFIO_Inst : BUFIO
    port map ( O => clk_serial, I => clk_ddr );

  u_BUFR_inst : BUFR
    generic map (  BUFR_DIVIDE => "4", SIM_DEVICE  => "7SERIES" )
    port map ( O => clk_parallel, CE => '1', CLR => '0', I => clk_ddr );

  -- DDR serdes -----------------------------------------------------------
  rst_ddr_buf           <= start_ddrrx_init or sync_reset;
  re_ddr_buffer         <= and_reduce(re_fifo);

  gen_iserdes : for i in 0 to kNumDDR-1 generate
    u_ddrrx : entity mylib.DdrRxV2
      generic map
      (
        kDiffTerm          => kDiffTerm,
        kRxPolarity        => kInvertMask(i),
        kIoStandard        => kIoStandard,
        kIoDelayGroup      => kIoDelayGroup,
        kFreqFastClk       => kFreqFastClk,
        kFreqRefClk        => kFreqRefClk,
        enDEBUG            => enDEBUG
      )
      port map
      (
        -- SYSTEM port --
        srst          => sync_reset_ddr,
        clkSer        => clk_serial,
        clkPar        => clk_parallel,
        clkIdelayRef  => clkIdelayRef,
        initStartIn   => start_ddrrx_init,

        -- Status --
        isReady       => ddrrx_is_ready(i),
        idelayTapNum  => open,

        -- Error status --
        bitslipErr    => ddrrx_bitslip_error(i),
        patternErr    => open,

        -- ISERDES input ports
        RXP           => dInDDRDp(i),
        RXN           => dInDDRDn(i),
        dOutSerdes    => dout_serdes(i)
      );

    -- CDC Buffer --
    we_fifo(i)  <= dout_serdes(i)(7) and (not test_mode) and ddr_iserdes_ready;
    re_fifo(i)  <= not empty_fifo(i);
    u_ddr_buf : ddr_buffer
      port map
      (
        rst       => rst_ddr_buf,
        wr_clk    => clk_parallel,
        rd_clk    => clk,
        din       => dout_serdes(i),
        wr_en     => we_fifo(i),
        rd_en     => re_ddr_buffer,
        dout      => dout_fifo(i),
        full      => open,
        empty     => empty_fifo(i),
        valid     => rv_fifo(i)
      );

  end generate;

  -- data reconstruction --
  rv_ddr_buf    <= and_reduce(rv_fifo) and ddr_iserdes_ready;
  din_ddr_data  <= '0' & dout_fifo(8)(6 downto 0)
                       & dout_fifo(7)(6 downto 0)
                       & dout_fifo(6)(6 downto 0)
                       & dout_fifo(5)(6 downto 0)
                       & dout_fifo(4)(6 downto 0)
                       & dout_fifo(3)(6 downto 0)
                       & dout_fifo(2)(6 downto 0)
                       & dout_fifo(1)(6 downto 0)
                       & dout_fifo(0)(6 downto 0);


  -- Initialize process --------------------------------------------------------------
  ddr_iserdes_ready   <= and_reduce(ddrrx_is_ready);
  bitslip_error       <= or_reduce(ddrrx_bitslip_error);

  -- Reset sequence --
  u_reset_gen_ddr   : entity mylib.ResetGen
    port map(rst or (not idelayctrl_ready), clk_parallel, sync_reset_ddr);

  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rst, clk, sync_reset);


end RTL;
