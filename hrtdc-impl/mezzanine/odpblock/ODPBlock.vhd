library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;
use IEEE.STD_LOGIC_MISC.ALL;

Library xpm;
use xpm.vcomponents.all;

library mylib;
use mylib.defHrTimingUnit.all;
use mylib.defFineCountLUT.all;
use mylib.defDataBusAbst.all;
use mylib.defDelimiter.all;
use mylib.defTDC.all;
use mylib.defLACCP.all;


entity ODPBlock is
  generic(
    kNumInput     : integer := 32;
    enDEBUG       : boolean := false
  );
  port(
    -- System --
    genChOffset     : in std_logic;

    rst             : in std_logic;
    tdcClk          : in std_logic;
    baseClk         : in std_logic;
    hitOut          : out std_logic_vector(kNumInput-1 downto 0);
    userReg         : in  std_logic_vector(kPosHbdUserReg'length-1 downto 0);

    -- LACCP --
    enOfsCorr       : in std_logic;
    LaccpFineOffset : in signed(kWidthLaccpFineOffset-1 downto 0);

    -- Control regisers --
    regThrough      : in std_logic;
    regAutoSW       : in std_logic;
    regSwitch       : in std_logic;
    regReadyLut     : out std_logic;

    regTdcMask      : in std_logic_vector(kNumInput-1 downto 0);

    enBypassDelay   : in  std_logic;
    enBypassParing  : in  std_logic;

    enTotFilter     : in  std_logic;
    enTotZeroThrough  : in std_logic;
    totMinTh        : in  std_logic_vector(kWidthTOT-1 downto 0);
    totMaxTh        : in  std_logic_vector(kWidthTOT-1 downto 0);

    testModeIn      : in std_logic;

    -- Data flow control --
    daqOn           : in  std_logic;
    hbfThrottlingOn : in  std_logic;
    triggerGate     : in  std_logic;

    -- Heartbeat count for TDC
    hbCount         : in  std_logic_vector(kWidthStrHbc-1 downto 0);

    -- Delimiter
    validDelimiter  : in  std_logic;
    dInDelimiter    : in  std_logic_vector(kWidthData-1 downto 0);

    -- Data In --
    sigIn           : in  std_logic_vector(kNumInput-1 downto 0);
    calibIn         : in  std_logic;

    -- Data Out --
    validOut        : out std_logic_vector(kNumInput-1 downto 0);
    dOut            : out DataArrayType(kNumInput-1 downto 0)

  );
end ODPBlock;

architecture RTL of ODPBlock is
  attribute keep : string;
  attribute keep_hierarchy : string;

  -- System --
  signal sync_reset       : std_logic;
  signal sync_reset_tdc   : std_logic_vector(kNumInput-1 downto 0);
  attribute keep of sync_reset_tdc  : signal is "true";

  function GetChOffset(genChOffset : std_logic) return integer is
  begin
    if(genChOffset = '1') then
      return 32;
    else
      return 0;
    end if;
  end function;

  -- Signal decralation ---------------------------------------------
  -- system --
  signal reg_through, reg_auto_sw, reg_switch : std_logic;
  signal reg_ready_l, reg_ready_t             : std_logic;

  signal sig_in_n           : std_logic_vector(kNumInput-1 downto 0);

  -- TDC --
  -- Delay taps -------------------------------------------------------------
  type TapArray   is array (integer range kNumInput-1 downto 0) of std_logic_vector(kNumRTaps downto 0);

  signal tap_out        : tapArray;
  signal leading_taps   : tapArray;
  signal trailing_taps  : tapArray;

  type dRawFineType is array (integer range kNumInput-1 downto 0) of std_logic_vector(kWidthFine+kWidthSemi-1 downto 0);

  signal valid_raw_leading      : std_logic_vector(kNumInput -1 downto 0);
  signal raw_fc_leading         : dRawFineType;
  signal valid_raw_trailing     : std_logic_vector(kNumInput -1 downto 0);
  signal raw_fc_trailing        : dRawFineType;

  -- Estimater LUT --
  signal ready_lut_leading      : std_logic_vector(kNumInput-1 downto 0);
  signal ready_lut_trailing     : std_logic_vector(kNumInput-1 downto 0);

  type dFclType is array (integer range kNumInput-1 downto 0) of std_logic_vector(kWidthLutOut-1 downto 0);
  signal hdout_fcl_leading      : std_logic_vector(kNumInput -1 downto 0);
  signal dout_fcl_leading       : dFclType;
  signal hdout_fcl_trailing     : std_logic_vector(kNumInput -1 downto 0);
  signal dout_fcl_trailing      : dFclType;

--  type dSemiType is array (integer range kNumInput-1 downto 0) of std_logic_vector(kWidthSemi-1 downto 0);
--  signal semi_count_leading_1   : dSemiType;
--  signal semi_count_leading_2   : dSemiType;
--  signal semi_count_leading_3   : dSemiType;
--
--  signal semi_count_trailing_1  : dSemiType;
--  signal semi_count_trailing_2  : dSemiType;
--  signal semi_count_trailing_3  : dSemiType;

  -- Generate FineCount /(Estimator+SemiFine) --
  constant fzero                : std_logic_vector(kWidthFineCount-1 downto 0):= (others => '0');
  signal pos_fc_leading         : FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);
  signal pos_fc_trailing        : FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);

  signal valid_leading          : std_logic_vector(kNumInput -1 downto 0);
  signal valid_trailing         : std_logic_vector(kNumInput -1 downto 0);
  signal finecount_leading      : FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);
  signal finecount_trailing     : FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);

  -- Data path merging --
  signal valid_data             : std_logic_vector(kNumInput -1 downto 0);
  signal valid_data_mask        : std_logic_vector(kNumInput -1 downto 0);
  signal finecount_data         : FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);
  signal finetot_data           : FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);
  signal is_leading             : std_logic_vector(kNumInput -1 downto 0);
  signal is_confilicted         : std_logic_vector(kNumInput -1 downto 0);

  -- TDC delay buffer --
  signal valid_data_delay       : std_logic_vector(kNumInput -1 downto 0);
  signal is_leading_delay       : std_logic_vector(kNumInput -1 downto 0);
  signal is_confilicted_delay   : std_logic_vector(kNumInput -1 downto 0);
  signal finecount_data_delay   : FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);
  signal finetot_data_delay     : FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);

  -- Trigger emulation --
  signal valid_data_trigger     : std_logic_vector(kNumInput -1 downto 0);

  -- Delimiter inserter --
  signal dtiming_hb             : TimingArrayType(kNumInput-1 downto 0)(kWidthTiming-1 downto 0);
  signal dtot_hb                : TotArrayType(kNumInput-1 downto 0)(kWidthTOT-1 downto 0);

  signal valid_inserter         : std_logic_vector(kNumInput -1 downto 0);
  signal dout_inserter          : DataArrayType(kNumInput-1 downto 0);

  -- LT Pairing --
  signal valid_pairing          : std_logic_vector(kNumInput -1 downto 0);
  signal dout_pairing           : DataArrayType(kNumInput-1 downto 0);

  -- TOTFilter --
  signal valid_tot_filter       : std_logic_vector(kNumInput -1 downto 0);
  signal dout_tot_filter        : DataArrayType(kNumInput-1 downto 0);

type sliceOrgArray is array(kNumInput-1 downto 0) of string(1 to 8);
constant SlicePosition              : sliceOrgArray :=
("X001Y100", "X011Y100", "X019Y100", "X037Y100", "X046Y100", "X057Y100", "X063Y100", "X075Y100",
 --"X084Y000", "X093Y000", "X057Y050", "X063Y050", "X068Y050", "X075Y050", "X084Y050", "X093Y050",
 "X019Y050", "X028Y050", "X037Y050", "X046Y050", "X057Y050", "X067Y050", "X075Y050", "X084Y050",
 --"X019Y050", "X028Y050", "X037Y050", "X046Y050", "X057Y000", "X063Y000", "X068Y000", "X075Y000",
 "X057Y000", "X067Y000", "X075Y000", "X084Y000", "X091Y000", "X100Y000", "X091Y050", "X100Y050",
 "X001Y000", "X011Y000", "X019Y000", "X028Y000", "X037Y000", "X046Y000", "X001Y050", "X011Y050"
 );

  -- Debug --
  attribute mark_debug : boolean;
--  attribute mark_debug of valid_leadingbuffer      : signal is enDEBUG;
--  attribute mark_debug of valid_trailingbuffer     : signal is enDEBUG;

begin
  -- =========================== body ===============================

  validOut  <= valid_tot_filter;
  dOut      <= dout_tot_filter;

  hitOut    <= valid_raw_leading;

  -- register buffer ------------------------------------------------
  reg_ready_l   <= and_reduce(ready_lut_leading);
  reg_ready_t   <= and_reduce(ready_lut_trailing);

  u_buf : process(baseClk)
  begin
    if(baseClk'event and baseClk = '1') then
      reg_auto_sw   <= regAutoSw;
      reg_through   <= regThrough;
      reg_switch    <= regSwitch;

      regReadyLut   <= reg_ready_l and reg_ready_t;
    end if;
  end process;

  -- Time Stamp -----------------------------------------------------
  -- Timing Unit --
  sig_in_n  <= not sigIn;

  gen_tdc : for i in 0 to kNumInput-1 generate
    attribute keep_hierarchy of u_reset_gen_tdc : label is "true";

  begin
    u_tap_inst : entity mylib.HRTimingTaps
      generic map(
        SliceOrigin    => SlicePosition(i)
        )
      port map(
        RST     => rst,
        tdcClk  => tdcClk,
        testModeIn => testModeIn,

        -- input --
        sigIn   => sigIn(i),
        calibIn => calibIn,

        -- output
        TapOut  => tap_out(i)
       );

    leading_taps(i)   <= tap_out(i);
    trailing_taps(i)  <= not tap_out(i);

--    u_tdcL_Inst : entity mylib.dummyHRTimingDecoder
--      port map(
--        tdcClk      => tdcClk,
--        sysClk      => baseClk,
--
--        -- input --
--        sigIn       => sigIn(i),
--
--        -- output --
--        hdOut       => valid_leading(i),
--        dOut        => finecount_leading(i)
--        );

    u_tdcL_Inst : entity mylib.HRTimingDecoder
      port map(
        tdcRst      => sync_reset_tdc(i),

        tdcClk      => tdcClk,
        sysClk      => baseClk,

        -- input --
        tapIn       => leading_taps(i),


        -- output --
        hdOut       => valid_raw_leading(i),
        dOut        => raw_fc_leading(i)
        );

    u_LUT_L : entity mylib.FineCountLut
      port map(
        RST         => sync_reset,
        CLK         => baseClk,

        -- control bits --
        regThrough  => reg_through,
        regSwitch   => reg_switch,
        regAutoSW   => reg_auto_sw,
        regReady    => ready_lut_leading(i),

        -- module input --
        hdIn        => valid_raw_leading(i),
        dIn         => raw_fc_leading(i),

        -- module output --
        hdOut       => hdout_fcl_leading(i),
        dOut        => dout_fcl_leading(i)
        );

--    u_tdcT_Inst : entity mylib.dummyHRTimingDecoder
--    port map(
--      tdcClk      => tdcClk,
--      sysClk      => baseClk,
--
--      -- input --
--      sigIn       => sig_in_n(i),
--
--      -- output --
--      hdOut       => valid_trailing(i),
--      dOut        => finecount_trailing(i)
--      );

    u_tdcT_Inst : entity mylib.HRTimingDecoder
      port map(
        tdcRst      => sync_reset_tdc(i),

        tdcClk      => tdcClk,
        sysClk      => baseClk,

        -- input --
        tapIn       => trailing_taps(i),

        -- output --
        hdOut       => valid_raw_trailing(i),
        dOut        => raw_fc_trailing(i)
        );

    u_LUT_T : entity mylib.FineCountLut
      port map(
        RST         => sync_reset,
        CLK         => baseClk,

        -- control bits --
        regThrough  => reg_through,
        regSwitch   => reg_switch,
        regAutoSW   => reg_auto_sw,
        regReady    => ready_lut_trailing(i),

        -- module input --
        hdIn        => valid_raw_trailing(i),
        dIn         => raw_fc_trailing(i),

        -- module output --
        hdOut       => hdout_fcl_trailing(i),
        dOut        => dout_fcl_trailing(i)
        );

--    u_semi_buf : process(baseClk)
--    begin
--      if(baseClk'event and baseClk = '1') then
--        semi_count_leading_1(i)  <= raw_fc_leading(i)(kWidthFine+1 downto kWidthFine);
--        semi_count_leading_2(i)  <= semi_count_leading_1(i);
--        semi_count_leading_3(i)  <= semi_count_leading_2(i);
--
--        semi_count_trailing_1(i) <= raw_fc_trailing(i)(kWidthFine+1 downto kWidthFine);
--        semi_count_trailing_2(i) <= semi_count_trailing_1(i);
--        semi_count_trailing_3(i) <= semi_count_trailing_2(i);
--      end if;
--    end process;

    -- Define FineCount of HR-TDC --
    valid_leading(i)      <= hdout_fcl_leading(i);
    valid_trailing(i)     <= hdout_fcl_trailing(i);

    pos_fc_leading(i)     <= dout_fcl_leading(i);
    pos_fc_trailing(i)    <= dout_fcl_trailing(i);
    finecount_leading(i)  <= std_logic_vector(unsigned(fzero) - unsigned(pos_fc_leading(i)));
    finecount_trailing(i) <= std_logic_vector(unsigned(fzero) - unsigned(pos_fc_trailing(i)));
    -- Define FineCount of HR-TDC --

    -- LTMerger --
    u_lt_merger : entity mylib.LTMerger
      port map(
        clk           => baseClk,

        -- Leading in --
        validLeading  => valid_leading(i),
        dInLeading    => finecount_leading(i),

        -- Trailing in --
        validTrailing => valid_trailing(i),
        dInTrailing   => finecount_trailing(i),

        -- Data out --
        validOut      => valid_data(i),
        isLeading     => is_leading(i),
        isConflicted  => is_confilicted(i),
        dOutTOT       => finetot_data(i),
        dOutTiming    => finecount_data(i)
      );


    u_reset_gen_tdc   : entity mylib.ResetGen
      port map(rst, tdcClk, sync_reset_tdc(i));

  end generate;

  -- TDC delay buffer ------------------------------------------------
  valid_data_mask <= valid_data and (not regTdcMask);

  u_TDCDelayBuffer : entity mylib.TDCDelayBuffer
    generic map(
      kNumInput => kNumInput,
      enDEBUG   => false
      )
    port map
    (
      -- system --
      clk             => baseClk,
      enBypass        => enBypassDelay,

      -- Data In --
      validIn         => valid_data_mask,
      isLeadingIn     => is_leading,
      --isConflictedIn  => is_confilicted,
      dInTOT          => finetot_data,
      dIn             => finecount_data,

      -- Data Out --
      vaildOut        => valid_data_delay,
      isLeadingOut    => is_leading_delay,
      --isConflictedOut => is_confilicted_delay,
      dOutTOT         => finetot_data_delay,
      dOut            => finecount_data_delay
      );

  -- Heartbeat frame definition ------------------------------------------------
  gen_tdcdata : for i in 0 to kNumInput-1 generate
  begin
    valid_data_trigger(i)   <= triggerGate and valid_data_delay(i);
    dtiming_hb(i)           <= hbCount & finecount_data_delay(i);
    dtot_hb(i)              <= std_logic_vector( to_unsigned(0, kWidthTOT-kWidthFineCount)) & finetot_data_delay(i);

    u_delimiterInserter : entity mylib.DelimiterInserter
      generic map
        (
          enDEBUG       => false
        )
      port map
      (
        -- system --
        clk             => baseClk,
        syncReset       => sync_reset,
        userRegIn       => userReg,
        channelNum      => std_logic_vector(to_unsigned(i+GetChOffset(genChOffset), kWidthChannel)),

        -- LACCP --
        enOfsCorr       => enOfsCorr,
        LaccpFineOffset => LaccpFineOffset,

        -- TDC in --
        validIn         => valid_data_trigger(i),
        dInTiming       => dtiming_hb(i),
        isLeading       => is_leading_delay(i),
        isConflicted    => is_confilicted_delay(i),
        dInToT          => dtot_hb(i),

        -- Delimiter word input --
        validDelimiter  => validDelimiter,
        dInDelimiter    => dInDelimiter,
        daqOn           => daqOn,
        hbfThrottlingOn => hbfThrottlingOn,

        -- output --
        validOut        => valid_inserter(i),
        dOut            => dout_inserter(i)
      );
  end generate;


  -- Data processing -----------------------------------------------------------
  gen_LTparing : for i in 0 to kNumInput-1 generate
  begin
    u_ltparing : entity mylib.LTParingUnit
      port map(
        syncReset => sync_reset,
        clk       => baseClk,
        enBypass  => enBypassParing,

        -- Data In --
        validIn   => valid_inserter(i),
        dIn       => dout_inserter(i),

        -- Data Out --
        validOut  => valid_pairing(i),
        dOut      => dout_pairing(i)
      );

    u_TOTFilter : entity mylib.TOTFilter
      port map(
        syncReset         => sync_reset,
        clk               => baseClk,
        enFilter          => enTotFilter,
        minTh             => totMinTh,
        maxTh             => totMaxTh,
        enZeroThrough     => enTotZeroThrough,

        -- Data In --
        validIn           => valid_pairing(i),
        dIn               => dout_pairing(i),

        -- Out --
        validOut          => valid_tot_filter(i),
        dOut              => dout_tot_filter(i)
      );
  end generate;

  -- Reset sequence --
  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rst, baseClk, sync_reset);

end RTL;
