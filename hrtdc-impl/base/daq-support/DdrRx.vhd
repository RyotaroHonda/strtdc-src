library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

Library UNISIM;
use UNISIM.vcomponents.all;

library mylib;
use mylib.defDDRReceiverV2.all;

-- ----------------------------------------------------------------------------------
-- == Clock network ==
-- Master (recovery) clock ---> BUFG ---> clkPar
-- Fast clock              ---> BUFG ---> clkSer
-- (Fast clock is 4x faster than master clock)
-- Skew of these clocks must be adjusted.
--
--
-- isReady:
--   Its logic high indicates that the initialization process, idelay adjust and bit-slip,
--   is finished.
-- ----------------------------------------------------------------------------------


entity DdrRx is
  generic
  (
    kDiffTerm          : boolean; -- IBUF DIFF_TERM
    kRxPolarity        : boolean; -- If true, inverts Rx polarity
    kIoStandard        : string;  -- IOSTANDARD of IBUFDS
    kIoDelayGroup      : string;  -- IODELAY_GROUP for IDELAYCTRL and IDELAY
    kFreqFastClk       : real;    -- Frequency of SERDES fast clock (MHz).
    kFreqRefClk        : real;    -- Frequency of refclk for IDELAYCTRL (MHz).
    enDEBUG            : boolean:= false
  );
  port
  (
    -- SYSTEM port --
    srst          : in std_logic; -- Asynchronous assert, synchronous de-assert reset. (active high)
    clkSer        : in std_logic; -- From BUFG (5 x clkPar freq.)
    clkPar        : in std_logic; -- From BUFG
    clkIdelayRef  : in std_logic; -- 200 MHz ref. clock.
    initStartIn   : in std_logic; -- Re-do the initialization process. Sync with clkPar.

    -- Status --
    isReady       : out std_logic; -- Indicate that DdrRx is ready to receive data
    idelayTapNum  : out std_logic_vector(4 downto 0);

    -- Error status --
    bitslipErr    : out std_logic; -- Attempted bitslip but the expected pattern was not found.
    patternErr    : out std_logic; -- Idle bit pattern which does not match kRefBit

    -- ISERDES input ports
    RXP           : in std_logic;  -- Connect to TOPLEVEL port
    RXN           : in std_logic;  -- Connect to TOPLEVEL port
    dOutSerdes    : out std_logic_vector(kWidthDev-1 downto 0) -- ISERDES output
  );
end DdrRx;

architecture RTL of DdrRx is
  -- System --
  constant kPlateauThreshold  : integer:= GetPlateauLength(GetTapDelay(kFreqRefClk), kFreqFastClk);
  constant kNumTaps           : integer:= 32;

  signal cdcm_pattern_ok      : std_logic;
  signal reset_sm             : std_logic;
  signal start_ddrrx_init     : std_logic;
  signal ddrrx_is_ready       : std_logic;

  signal pattern_error        : std_logic;
  --signal idelay_error         : std_logic;
  signal bitslip_error        : std_logic;

  -- IDELAY --
  signal idelay_reset   : std_logic;
  signal delay_inc      : std_logic;
  signal inc_ce         : std_logic;
  signal idelay_check_count : std_logic_vector(kWidthCheckCount-1 downto 0);

  signal en_idelay_check      : std_logic;
  signal idelay_is_adjusted   : std_logic;
  signal state_idelay         : IdelayControlProcessType;

  signal reg_idelay_tapnum    : std_logic_vector(idelayTapNum'range);

  -- ISERDES --
  signal dout_serdes          : std_logic_vector(kWidthDev-1 downto 0);
  signal reg_dout_serdes      : std_logic_vector(kWidthDev-1 downto 0);
  signal prev_data            : std_logic_vector(kWidthDev-1 downto 0);

  signal en_bitslip           : std_logic;
  signal en_idle_check        : std_logic;
  signal idle_patt_count      : std_logic_vector(kWidthCheckCount-4 downto 0);
  signal bit_aligned          : std_logic;
  signal bitslip_failure      : std_logic;
  signal state_bitslip        : BitslipControlProcessType;

  -- IODELAY_GROUP --
  attribute IODELAY_GROUP : string;

  attribute mark_debug        : boolean;

  attribute mark_debug of state_bitslip   : signal is enDEBUG;
  attribute mark_debug of state_idelay    : signal is enDEBUG;
  attribute mark_debug of reg_dout_serdes : signal is enDEBUG;
  attribute mark_debug of reg_idelay_tapnum : signal is enDEBUG;

-- debug ---------------------------------------------------------------

begin
  -- ======================================================================
  --                                 body
  -- ======================================================================

  dOutSerdes  <= reg_dout_serdes;

  start_ddrrx_init <= initStartIn;

  -- ISerDes implementation ---------------------------------------------------------
  u_rx_iserdes : entity mylib.Cdcm8RxImpl
    generic map
    (
      kSysW         => kWidthSys,
      kDevW         => kWidthDev,
      kDiffTerm     => kDiffTerm,
      kRxPolarity   => kRxPolarity,
      kIoStandard   => kIoStandard,
      kIoDelayGroup => kIoDelayGroup,
      kFreqRefClk   => kFreqRefClk
    )
    port map
    (
      -- IBUFDS
      dInFromPinP       => RXP,
      dInFromPinN       => RXN,
      -- IDELAY
      rstIDelay         => idelay_reset,
      ceIDelay          => inc_ce,
      incIDelay         => delay_inc,
      -- ISERDES
      cdOutFromO        => open,
      dOutToDevice      => dout_serdes,
      bitslip           => en_bitslip,
      -- Clock and reset
      clkIn             => clkSer,
      clkDivIn          => clkPar,
      ioReset           => srst
    );

  u_bufdout : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      reg_dout_serdes <= dout_serdes;
    end if;
  end process;

  u_bitpattern : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
       if(srst = '1') then
         cdcm_pattern_ok <= '0';
       else
        if(bit_aligned = '1') then
          if(reg_dout_serdes = kRefBit) then
            cdcm_pattern_ok   <= '1';
          else
            cdcm_pattern_ok   <= '0';
          end if;
        else
          cdcm_pattern_ok     <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Idelay control -----------------------------------------------------------------
  idelay_reset  <= srst;
  reset_sm      <= srst;

  u_idelay_check : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(en_idelay_check = '1') then
        prev_data   <= reg_dout_serdes;
        if(prev_data = reg_dout_serdes) then
          idelay_check_count  <= std_logic_vector(unsigned(idelay_check_count) + 1);
        else
          idelay_check_count  <= (others => '0');
        end if;
      else
        idelay_check_count  <= (others => '0');
      end if;
    end if;
  end process;

  u_idelay_sm : process(clkPar)
    variable num_idelay_appropriate : integer range 0 to kNumTaps;
    variable num_cont_appropriate   : std_logic_vector(idelayTapNum'range);
    variable num_idelay_check       : integer range 0 to kNumTaps;
    variable elapsed_time           : integer range 0 to kMaxIdelayCheck;
    variable decrement_count        : integer range 0 to kNumTaps;
  begin
    if(clkPar'event and clkPar = '1') then
      if(reset_sm = '1') then
        elapsed_time            := 0;
        num_idelay_appropriate  := 0;
        num_cont_appropriate    := (others => '0');
        num_idelay_check        := 0;
        decrement_count         := 0;

        en_idelay_check     <= '0';
        inc_ce              <= '0';
        delay_inc           <= '1'; -- Increment

        idelay_is_adjusted  <= '0';
        state_idelay        <= Init;
      else
        case state_idelay is
          when Init =>
            state_idelay        <= WaitStart;

          when WaitStart =>
            if(start_ddrrx_init = '1') then
              en_idelay_check   <= '1';
              state_idelay      <= Check;
            end if;

          when Check =>
            elapsed_time  := elapsed_time +1;
            if(unsigned(idelay_check_count) = kSuccThreshold) then
              num_idelay_appropriate  := num_idelay_appropriate + 1;
              num_idelay_check        := num_idelay_check + 1;
              --num_cont_appropriate    := (others => '0');
              num_cont_appropriate    := std_logic_vector(to_unsigned(num_idelay_appropriate, 5));

              en_idelay_check   <= '0';
              state_idelay      <= NumTrialCheck;
            elsif(elapsed_time  = kMaxIdelayCheck-1) then
              -- Time out
              --num_cont_appropriate    :=

              num_idelay_appropriate  := 0;
              num_idelay_check  := num_idelay_check + 1;
              en_idelay_check   <= '0';
              state_idelay      <= NumTrialCheck;
            end if;

          when NumTrialCheck  =>
            elapsed_time  := 0;
            if(num_idelay_check = kNumTaps) then
              state_idelay    <= IdelayFailure;
            elsif(to_integer(unsigned(num_cont_appropriate)) >= kPlateauThreshold) then
--              inc_ce            <= '1';
--              delay_inc         <= '0';
--              decrement_count   := to_integer(unsigned(num_cont_appropriate(4 downto 1)) +1);
--              state_idelay      <= Decrement;
              inc_ce              <= '0';
              idelay_is_adjusted  <= '1';
              state_idelay        <= IdelayAdjusted;
            else
              inc_ce          <= '1';
              state_idelay    <= Increment;
            end if;

          when Increment =>
            inc_ce          <= '0';
            en_idelay_check <= '1';
            state_idelay    <= Check;

--          when Decrement =>
--            decrement_count   := decrement_count -1;
--            num_idelay_check  := num_idelay_check-1;
--            if(decrement_count = 0) then
--              inc_ce  <= '0';
--              idelay_is_adjusted  <= '1';
--              state_idelay        <= IdelayAdjusted;
--            end if;

          when IdelayAdjusted =>
            null;

          when IdelayFailure =>
            -- Abnormal state. Should not fall in this state.
            null;

          when others =>
            state_idelay  <= Init;

        end case;

        reg_idelay_tapnum <= std_logic_vector(to_unsigned(num_idelay_check, reg_idelay_tapnum'length));
      end if;
    end if;
  end process;


  -- Bit Slip --------------------------------------------------------------
  u_check_idle : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(en_idle_check = '1') then
        if(kRefBit = reg_dout_serdes) then
          idle_patt_count  <= std_logic_vector(unsigned(idle_patt_count) + 1);
        else
          idle_patt_count  <= (others => '0');
        end if;
      else
        idle_patt_count  <= (others => '0');
      end if;
    end if;
  end process;

  u_bitslip_sm : process(clkPar)
    variable num_patt_check       : integer range 0 to kWidthDev;
    variable elapsed_time         : integer range 0 to kMaxPattCheck;
  begin
    if(clkPar'event and clkPar = '1') then
      if(reset_sm = '1') then
        elapsed_time    := 0;
        num_patt_check  := 0;
        en_bitslip      <= '0';
        bit_aligned     <= '0';
        bitslip_failure <= '0';

        state_bitslip   <= Init;

      else
        case state_bitslip is
          when Init =>
            state_bitslip   <= WaitStart;

          when WaitStart =>
            if(idelay_is_adjusted = '1') then
              en_idle_check   <= '1';
              state_bitslip   <= CheckIdlePatt;
            end if;

          when CheckIdlePatt =>
            elapsed_time  := elapsed_time +1;
            if(unsigned(idle_patt_count) = kPattOkThreshold) then
              en_idle_check   <= '0';
              bit_aligned     <= '1';
              state_bitslip   <= BitslipFinished;
            elsif(elapsed_time = kMaxPattCheck-1) then
              num_patt_check  := num_patt_check +1;
              en_bitslip      <= '1';
              state_bitslip   <= BitSlip;
            end if;

          when NumTrialCheck  =>
            if(num_patt_check = kWidthDev) then
              bitslip_failure   <= '1';
              state_bitslip     <= BitslipFailure;
            end if;

          when BitSlip =>
            elapsed_time  := 0;
            en_bitslip    <= '0';
            state_bitslip <= CheckIdlePatt;

          when BitslipFinished =>
            null;

          when BitslipFailure =>
            null;

          when others =>
            state_bitslip         <= Init;
        end case;
      end if;
    end if;

  end process;

  -- Status register --------------------------------------------------------------
  -- For initialize process --
  isReady    <= ddrrx_is_ready;

  u_isready : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(reset_sm = '1') then
        ddrrx_is_ready    <= '0';
      else
        if(state_bitslip = BitslipFinished) then
          ddrrx_is_ready  <= '1';
        end if;
      end if;
    end if;
  end process;

  -- For error signal --
  --idelayErr  <= idelay_error;
  bitslipErr <= bitslip_error;
  patternErr <= pattern_error;

  u_error_sig : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      pattern_error   <= not cdcm_pattern_ok;

      -- if(state_idelay = IdelayFailure)  then
      --   idelay_error  <= '1';
      -- else
      --   idelay_error  <= '0';
      -- end if;

      if(state_bitslip = BitslipFailure)  then
        bitslip_error  <= '1';
      else
        bitslip_error  <= '0';
      end if;
    end if;
  end process;

end RTL;
