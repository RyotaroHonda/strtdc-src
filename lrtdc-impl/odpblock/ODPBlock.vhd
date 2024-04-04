library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

Library xpm;
use xpm.vcomponents.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defDelimiter.all;
use mylib.defTDC.all;

entity ODPBlock is
  generic(
    kNumInput     : integer:= 32;
    enDEBUG       : boolean := false
  );
  port(
    -- System --
    rst             : in  std_logic;
    tdcClk          : in  std_logic_vector(kNumTdcClock-1 downto 0);
    baseClk         : in  std_logic;
    hitOut          : out std_logic_vector(kNumInput-1 downto 0);

    -- Control registers --
    tdcMask         : in  std_logic_vector(kNumInput-1 downto 0);

    enBypassDelay   : in  std_logic;
    enBypassParing  : in  std_logic;

    enTotFilter     : in  std_logic;
    enTotZeroThrough  : in std_logic;
    totMinTh        : in  std_logic_vector(kWidthTOT-1 downto 0);
    totMaxTh        : in  std_logic_vector(kWidthTOT-1 downto 0);

    -- Data flow control --
    daqOn           : in  std_logic;
    hbfThrottlingOn : in  std_logic;
    triggerGate     : in  std_logic;

    -- heartbeat count for TDC
    hbCount         : in  std_logic_vector(kWidthStrHbc-1 downto 0);

    -- delimiter --
    validDelimiter  : in  std_logic;
    dInDelimiter    : in  std_logic_vector(kWidthData-1 downto 0);

    -- Data In --
    sigIn           : in  std_logic_vector(kNumInput-1 downto 0);

    -- Data Out --
    validOut        : out std_logic_vector(kNumInput-1 downto 0);
    dOut            : out DataArrayType(kNumInput-1 downto 0)

  );
end ODPBlock;

architecture RTL of ODPBlock is
  -- System --
  signal sync_reset    : std_logic;

  -- Signal decralation ---------------------------------------------
  signal sig_in_n           : std_logic_vector(kNumInput-1 downto 0);

  -- delimiter delay --

  -- TDC --
  signal valid_leading          : std_logic_vector(kNumInput -1 downto 0);
  signal finecount_leading      : FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);
  signal valid_trailing         : std_logic_vector(kNumInput -1 downto 0);
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
  signal dtot_hb                : TOTArrayType(kNumInput-1 downto 0)(kWidthTOT-1 downto 0);

  signal valid_inserter         : std_logic_vector(kNumInput -1 downto 0);
  signal dout_inserter          : DataArrayType(kNumInput-1 downto 0);

  -- LT Pairing --
  signal valid_pairing          : std_logic_vector(kNumInput -1 downto 0);
  signal dout_pairing           : DataArrayType(kNumInput-1 downto 0);

  -- TOTFilter --
  signal valid_tot_filter       : std_logic_vector(kNumInput -1 downto 0);
  signal dout_tot_filter        : DataArrayType(kNumInput-1 downto 0);


  attribute mark_debug : boolean;


begin
  -- =========================== body ===============================

  validOut  <= valid_tot_filter;
  dOut      <= dout_tot_filter;

  hitOut    <= valid_leading;

  -- Fine Count -----------------------------------------------------
  sig_in_n  <= not sigIn;

  gen_tdc : for i in 0 to kNumInput-1 generate

    -- leading --
    u_TDC : entity mylib.TDCUnit
      generic map(
        enDEBUG => enDEBUG
      )
      port map
      (
        -- system --
        rst     => sync_reset,
        tdcClk  => tdcClk,
        bClk    => baseClk,

        -- Data In --
        sigIn   => sigIn(i),

        -- Data Out --
        validOut=> valid_leading(i),
        dOut    => finecount_leading(i)
      );

    -- trailing --
    u_TDCT : entity mylib.TDCUnit
      generic map(
        enDEBUG => enDEBUG
      )
      port map
      (
        -- system --
        rst     => sync_reset,
        tdcClk  => tdcClk,
        bClk    => baseClk,

        -- Data In --
        sigIn   => sig_in_n(i),

        -- Data Out --
        validOut=> valid_trailing(i),
        dOut    => finecount_trailing(i)
      );

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

  end generate;


  -- TDC delay buffer --------------------------------------------------------
  valid_data_mask <= valid_data and (not tdcMask);

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
  end generate;

  u_delimiterInserter : entity mylib.DelimiterInserter
  generic map
    (
      kNumInput => kNumInput,
      enDEBUG   => false
    )
    port map
    (
      -- system --
      genChOffset     => '0',

      clk             => baseClk,
      syncReset       => sync_reset,

      -- TDC in --
      validIn         => valid_data_trigger,
      dInTiming       => dtiming_hb,
      isLeading       => is_leading_delay,
      isConflicted    => is_confilicted_delay,
      dInToT          => dtot_hb,

      -- Delimiter word input --
      validDelimiter  => validDelimiter,
      dInDelimiter    => dInDelimiter,
      daqOn           => daqOn,
      hbfThrottlingOn => hbfThrottlingOn,

      -- output --
      validOut        => valid_inserter,
      dOut            => dout_inserter
    );

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
