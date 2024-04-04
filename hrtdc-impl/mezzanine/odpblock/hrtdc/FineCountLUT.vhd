library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use mylib.defHrTimingUnit.all;
use mylib.defFineCountLUT.all;

entity FineCountLUT is
  port (
    RST         : in std_logic;
    CLK         : in std_logic;

    -- control bits --
    regThrough  : in std_logic;
    regSwitch   : in std_logic;
    regAutoSW   : in std_logic;
    regReady    : out std_logic;

    -- module input --
    hdIn        : in std_logic;
    dIn         : in std_logic_vector(kWidthFine-1 downto 0);

    -- module output --
    hdOut       : out std_logic;
    dOut        : out std_logic_vector(kWidthLutOut-1 downto 0)
    );
end FineCountLUT;

architecture RTL of FineCountLUT is
  attribute mark_debug  : string;

  -- internal signals ------------------------------------------------------
  signal reg_hdin     : std_logic;
  signal reg_din      : std_logic_vector(kWidthFine-1 downto 0);

  signal reg_through, reg_switch, reg_autosw, reg_ready  : std_logic;

  -- LUT conroll --
  signal req_switch, req_switch_auto  : std_logic;
  signal line_select                  : std_logic;

  signal read_ptr, write_ptr  : std_logic_vector(kWidthLutAddr-1 downto 0);

  -- read process --
  signal hd_buf           : std_logic;
  signal fc_buf           : std_logic_vector(kWidthFine-1 downto 0);
  signal dout_read_buf    : std_logic_vector(kWidthLutOut-1 downto 0);

  -- write process --
  constant kAllOne         : std_logic_vector(kWidthLutIn-1 downto 0):=(others => '1');

  signal state_write  : WriteProcessType;
  signal count0           : std_logic_vector(kWidthLutIn-1 downto 0);
  signal index            : std_logic_vector(kWidthFine-1 downto 0);

  signal we               : std_logic;
  signal din_write        : std_logic_vector(kWidthLutIn-1 downto 0);
  signal dout_write_buf   : std_logic_vector(kWidthLutIn-1 downto 0);
  signal d0, d1           : std_logic_vector(kWidthLutIn-1 downto 0);
  signal dsum0, dsum1     : std_logic_vector(kWidthLutIn-1 downto 0);

  -- LUT signals --
  type addrLutType is array(kNumLut-1 downto 0) of std_logic_vector(kWidthLutAddr-1 downto 0);
  signal addr_lut : addrLutType;

  type dinLutType is array(kNumLut-1 downto 0) of std_logic_vector(kWidthLutIn-1 downto 0);
  signal din_lut  : dinLutType;

  type doutLutType is array(kNumLut-1 downto 0) of std_logic_vector(kWidthLutIn-1 downto 0);
  signal dout_lut : doutLutType;

  signal we_lut   : std_logic_vector(kNumLut-1 downto 0);

  COMPONENT dram_FineCountLUT
    PORT (
      a   : IN STD_LOGIC_VECTOR(kWidthLutAddr-1 DOWNTO 0);
      d   : IN STD_LOGIC_VECTOR(kWidthLutIn-1 DOWNTO 0);
      clk : IN STD_LOGIC;
      we  : IN STD_LOGIC;
--      spo : OUT STD_LOGIC_VECTOR(KWIDTHLUTIN-1 DOWNTO 0)
      qspo : OUT STD_LOGIC_VECTOR(kWidthLutIn-1 DOWNTO 0)
      );
  END COMPONENT;

  -- debug --------------------------------------------------------------
  -- attribute mark_debug of state_write   : signal is "true";
  -- attribute mark_debug of reg_hdin      : signal is "true";
  -- attribute mark_debug of reg_din       : signal is "true";
  -- attribute mark_debug of dout_write_buf : signal is "true";
  -- attribute mark_debug of din_write     : signal is "true";
  -- attribute mark_debug of we            : signal is "true";
  -- attribute mark_debug of count0        : signal is "true";
--  attribute mark_debug of regSwitch        : signal is "true";
--  attribute mark_debug of reg_switch        : signal is "true";

  -- attribute mark_debug of index         : signal is "true";
  -- attribute mark_debug of write_ptr     : signal is "true";
  -- attribute mark_debug of d0            : signal is "true";
  -- attribute mark_debug of d1            : signal is "true";
  -- attribute mark_debug of dsum1         : signal is "true";

  -- attribute mark_debug of read_ptr      : signal is "true";
  -- attribute mark_debug of dout_read_buf : signal is "true";

  -- attribute mark_debug of addr_lut      : signal is "true";
  -- attribute mark_debug of din_lut      : signal is "true";
  -- attribute mark_debug of we_lut      : signal is "true";
  -- attribute mark_debug of dout_lut      : signal is "true";
  -- debug --------------------------------------------------------------

begin
  -- ============================== body ================================
  -- signal connection --------------------------------------------------
  u_bufin : process(CLK)
  begin
    if(CLK'event AND CLK = '1') then
      if(RST = '1') then
        reg_hdin    <= '0';
        reg_din     <= (others => '0');
      else
        reg_hdin    <= hdIn;
        reg_din     <= dIn;
      end if;
    end if;
  end process;

  reg_through <= regThrough;
--  reg_switch  <= regSwitch;
  reg_autosw  <= regAutoSW;

  u_oneshot : entity mylib.EdgeDetector port map('0', CLK, regSwitch, reg_switch);

  -- line switch ---------------------------------------------------------
--  req_switch  <= req_switch_auto when(reg_autosw = '1') else reg_switch;
  req_switch  <= reg_switch or (req_switch_auto and reg_autosw);

  u_line_sel : process(CLK)
  begin
    if(CLK'event AND CLK = '1') then
      if(RST = '1') then
        line_select <= '0';
      else
        if(req_switch = '1') then
          line_select <= NOT line_select;
        end if;
      end if;
    end if;
  end process;

  -- LUT read process ----------------------------------------------------
  read_ptr    <= reg_din;
  addr_lut(0) <= read_ptr  when(line_select = '0') else write_ptr;
  addr_lut(1) <= write_ptr when(line_select = '0') else read_ptr;

  u_delay_buffer : process(CLK)
  begin
    if(CLK'event AND CLK = '1') then
      if(RST = '1') then
        hd_buf  <= '0';
      else
        hd_buf  <= reg_hdin;
        fc_buf  <= reg_din;
      end if;
    end if;
  end process;

  dout_read_buf   <= dout_lut(0)(kWidthLutIn-1 downto kLengthDiscard) when(line_select = '0') else
                     dout_lut(1)(kWidthLutIn-1 downto kLengthDiscard);

  u_output_reg : process(CLK)
  begin
    if(CLK'event AND CLK = '1') then
      if(RST = '1') then
        hdOut       <= '0';
        regReady    <= '0';
      else
        hdOut       <= hd_buf;
        regReady    <= reg_ready;

        if(reg_through = '1') then
          dOut    <= "00000" & fc_buf;
        else
          dOut    <= dout_read_buf;
        end if;
      end if;
    end if;
  end process;

  -- LUT write process ---------------------------------------------------
  we_lut(0)   <= we when(line_select = '1') else '0';
  we_lut(1)   <= we when(line_select = '0') else '0';

  din_lut(0)  <= din_write when(line_select = '1') else (others => '0');
  din_lut(1)  <= din_write when(line_select = '0') else (others => '0');

  dout_write_buf  <= dout_lut(1) when(line_select = '0') else dout_lut(0);

  u_write_process : process(CLK)
  begin
    if(CLK'event AND CLK = '1') then
      if(RST = '1') then
        we              <= '0';
        req_switch_auto <= '0';
        reg_ready       <= '0';
        dsum0           <= (others => '0');
        dsum1           <= (others => '0');
        count0          <= (others => '0');

        state_write <= Init;
      else
        case state_write is
          when Init =>
            we              <= '0';
            req_switch_auto <= '0';
            reg_ready       <= '0';
            dsum0           <= (others => '0');
            dsum1           <= (others => '0');
            count0          <= (others => '0');
            state_write <= InitReset;

          -- Reset sequence ------------------------------------------
          when InitReset =>
            index       <= (others => '0');
            state_write <= SetAddrReset;

          when SetAddrReset =>
            write_ptr   <= index;
            state_write <= WriteReset;

          when WriteReset =>
            din_write   <= (others => '0');
            we          <= '1';
            state_write <= FinalizeReset;

          when FinalizeReset =>
            we        <= '0';
            index     <= index +1;
            if(index = kMaxPtr) then
              state_write <= SetAddr0;
            else
              state_write <= SetAddrReset;
            end if;

          -- Accumulate hits -----------------------------------------
          when SetAddr0 =>
            if(reg_hdin = '1') then
              write_ptr   <= reg_din;
              state_write <= Read0;
            end if;

          when Read0 =>
            state_write <= Record0;

          when Record0 =>
            d0          <= dout_write_buf;
            state_write <= Sum0;

          when Sum0 =>
            dsum0       <= d0 + 1;
            state_write <= Write0;

          when Write0 =>
            din_write   <= dsum0;
            we          <= '1';
            count0      <= count0 +1;
            state_write <= Finalize0;

          when Finalize0 =>
            we   <= '0';
            if(count0 = kAllOne) then
              state_write <= InitInteg;
            else
              state_write <= SetAddr0;
            end if;

          -- Integrate  -----------------------------------------------
          when InitInteg =>
            index       <= (others => '0');
            dsum1       <= (others => '0');
            state_write <= SetAddr1;

          when SetAddr1 =>
            write_ptr   <= index;
            state_write <= Read1;

          when Read1 =>
            state_write <= Record1;

          when Record1 =>
            d1          <= dout_write_buf;
            state_write <= Sum1;

          when Sum1 =>
            din_write   <= ('0' & d1(kWidthLutIn-1 downto 1)) + dsum1;
            dsum1       <= d1 + dsum1;
            state_write <= Write1;

          when Write1 =>
            we          <= '1';
            state_write <= Write2;

          when Write2 =>
            we          <= '0';
            state_write <= Finalize1;

          when Finalize1 =>
            index   <= index +1;
            if(index = kMaxPtr) then
              state_write <= DoSwitch;
            else
              state_write <= SetAddr1;
            end if;

          when DoSwitch =>
            reg_ready       <= '1';
            req_switch_auto <= '1';
            if(reg_autosw = '1' OR reg_switch = '1') then
              state_write <= Done;
            end if;

          when Done =>
            reg_ready       <= '0';
            req_switch_auto <= '0';
            count0          <= (others => '0');
            state_write     <= InitReset;

          when others =>
            state_write <= Init;

        end case;
      end if;
    end if;
  end process;

  -- LUT instance --------------------------------------------------------
  gen_dram : for i in 0 to kNumLut-1 generate
  begin
    u_LUT : dram_FineCountLUT
      PORT map(
        a   => addr_lut(i),
        d   => din_lut(i),
        clk => CLK,
        we  => we_lut(i),
--        spo => dout_lut(i)
        qspo => dout_lut(i)
        );
  end generate;

end RTL;
