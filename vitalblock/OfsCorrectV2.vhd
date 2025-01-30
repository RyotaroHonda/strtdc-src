library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defDelimiter.all;
use mylib.defTDC.all;

library std;
use std.env.all;
library xpm;
use xpm.vcomponents.all;

entity OfsCorrectV2 is
  generic(
    kWidthOfs           : integer;
    enDEBUG             : boolean:= false
  );
  port(
    syncReset           : in std_logic;   -- synchronous reset
    clk                 : in std_logic;
    enBypassOfsCorr     : in std_logic;
    extendedOfs         : in signed(kWidthOfs-1 downto 0); -- Range : Heartbeat counter + FineCount

    -- Data In --
    rdEnOut             : out std_logic;
    validIn             : in std_logic;
    dIn                 : in std_logic_vector(kWidthData-1 downto 0);

    -- Data Out --
    validOut            : out std_logic;
    dOut                : out std_logic_vector(kWidthData-1 downto 0)
  );
end OfsCorrectV2;

architecture RTL of OfsCorrectV2 is
  attribute mark_debug  : boolean;

  -- Internal signals -----------------------------------------------
  signal data_type      : std_logic_vector(kPosHbdDataType'length-1 downto 0);

  signal ibuf_empty, ibuf_rden, ibuf_rdvalid  : std_logic;
  signal idout : std_logic_vector(dIn'range);

  signal edge_cbuf_empty  : std_logic_vector(1 downto 0);
  signal work_mode        : std_logic;
  constant kBuffering     : std_logic:= '0';
  constant kMoving        : std_logic:= '1';

  type ModeType is (BufferingMode, WaitLatency, MovingMode);
  signal state_mode       : ModeType;

  signal cbuf_empty, cbuf_rden, cbuf_rdvalid, cbuf_wren : std_logic;
  signal cdin, cdout      : std_logic_vector(dIn'range);

  signal data_tsize_corr  : signed(kPosHbdTransSize'length-1 downto 0);

  signal valid_through    : std_logic;
  signal dout_through     : std_logic_vector(dIn'range);

  function InvertSign(value : in signed) return signed is
    variable temp_vect  : std_logic_vector(value'range);
  begin
    temp_vect := not std_logic_vector(value);
    return (signed(temp_vect) +1);
  end function;


begin
  -- =========================== body ===============================

  u_ibuf : xpm_fifo_sync
    generic map (
      DOUT_RESET_VALUE    => "0",
      ECC_MODE            => "no_ecc",
      FIFO_MEMORY_TYPE    => "auto",
      FIFO_READ_LATENCY   => 1,
      FIFO_WRITE_DEPTH    => 256,
      FULL_RESET_VALUE    => 0,
      PROG_EMPTY_THRESH   => 5,
      PROG_FULL_THRESH    => 240,
      RD_DATA_COUNT_WIDTH => 9,
      READ_DATA_WIDTH     => 64,
      USE_ADV_FEATURES    => "1707",
      WAKEUP_TIME         => 0,
      WR_DATA_COUNT_WIDTH => 9,
      WRITE_DATA_WIDTH    => 64
    )
    port map (
      sleep            => '0',
      rst              => syncReset,
      wr_clk           => clk,
      wr_en            => validIn,
      din              => dIn,
      prog_full        => open,
      rd_en            => ibuf_rden,
      dout             => idout,
      data_valid       => ibuf_rdvalid,
      empty            => ibuf_empty,
      injectsbiterr    => '0',
      injectdbiterr    => '0'
    );

  data_type   <= idout(kPosHbdDataType'range);

  u_mode : process(clk)
    variable count : integer range -1 to 7;
  begin
    if(clk'event and clk = '1') then
      if(syncReset = '1') then
        count       := 0;

        edge_cbuf_empty <= (others => '0');
        work_mode   <= kBuffering;
        rdEnOut     <= '1';
        ibuf_rden   <= '1';
        cbuf_rden   <= '0';
        state_mode  <= BufferingMode;
      else
        edge_cbuf_empty <= edge_cbuf_empty(0) & cbuf_empty;

        case state_mode is
          when BufferingMode =>
            work_mode   <= kBuffering;

            if(checkDelimiter(data_type) = true and ibuf_rdvalid = '1' and enBypassOfsCorr = '0') then
              count       := 2;
              rdEnOut     <= '0';
              ibuf_rden   <= '0';
              state_mode  <= WaitLatency;
            end if;

          when WaitLatency =>
            if(count = 0) then
              cbuf_rden   <= '1';
              work_mode   <= kMoving;
              state_mode  <= MovingMode;
            end if;
            count := count -1;

          when MovingMode =>
            if(edge_cbuf_empty = "01") then
              work_mode   <= kBuffering;
              rdEnOut     <= '1';
              ibuf_rden   <= '1';
              cbuf_rden   <= '0';
              state_mode  <= BufferingMode;
            end if;

          when others =>
            edge_cbuf_empty <= (others => '0');
            work_mode   <= kBuffering;
            rdEnOut     <= '1';
            ibuf_rden   <= '1';
            state_mode  <= BufferingMode;

        end case;
      end if;
    end if;
  end process;


  u_corr : process(clk)
    variable ctiming     : signed(kWidthOfs-1 downto 0):= (others => '0');
    variable cdata_tsize : signed(kPosHbdTransSize'range):= (others => '0');
    variable cdata_gsize : signed(kPosHbdGenSize'range):= (others => '0');
  begin
    if(clk'event and clk = '1') then
      if(syncReset = '1') then
        cbuf_wren     <= '0';
        valid_through <= '0';
        data_tsize_corr <= (others => '0');
      else
        if(ibuf_rdvalid = '1' and enBypassOfsCorr = '0') then
          if(checkDelimiter(data_type) = false) then
            -- Normal data --
            if(extendedOfs(extendedOfs'high) = '0') then
              -- Positive --
              ctiming   := signed(idout(kPosTiming'range)) + extendedOfs;

              if(ctiming(ctiming'high) /= idout(kPosTiming'high)) then
                -- across frame boundary --
                cbuf_wren   <= '1';
                cdin(idout'high downto kPosTiming'high+1)   <= idout(idout'high downto kPosTiming'high+1);
                cdin(kPosTiming'high downto 0)  <= (kPosTiming'range => std_logic_vector(ctiming), others => '0');

                data_tsize_corr  <= data_tsize_corr-8;
                --if(unsinged(idout(kPosTot'range)) = 0) then
                --  data_gsize_corr  <= data_gsize_corr-8;
                --else
                --  data_gsize_corr  <= data_gsize_corr-16;
                --end if;

                valid_through   <= '0';
              else
                cbuf_wren       <= '0';
                valid_through   <= '1';
                dout_through(idout'high downto kPosTiming'high+1)   <= idout(idout'high downto kPosTiming'high+1);
                dout_through(kPosTiming'high downto 0)  <= (kPosTiming'range => std_logic_vector(ctiming), others => '0');
              end if;
            else
              -- Negative --
              if(ctiming(ctiming'high) /= idout(kPosTiming'high)) then
                -- across frame boundary --
                cbuf_wren   <= '1';
                cdin(idout'high downto kPosTiming'high+1)   <= idout(idout'high downto kPosTiming'high+1);
                cdin(kPosTiming'high downto 0)  <= (kPosTiming'range => std_logic_vector(ctiming), others => '0');

                data_tsize_corr  <= data_tsize_corr-8;
                --if(unsinged(idout(kPosTot'range)) = 0) then
                --  data_gsize_corr  <= data_gsize_corr-8;
                --else
                --  data_gsize_corr  <= data_gsize_corr-16;
                --end if;

                valid_through <= '0';
              else
                cbuf_wren       <= '0';
                valid_through   <= '1';
                dout_through(idout'high downto kPosTiming'high+1)   <= idout(idout'high downto kPosTiming'high+1);
                dout_through(kPosTiming'high downto 0)  <= (kPosTiming'range => std_logic_vector(ctiming), others => '0');
              end if;
            end if;
          else
            -- Delimiter words --
            if(data_type = kDatatypeHeartbeatT2) then
              cdata_tsize := signed(idout(kPosHbdTransSize'range)) + data_tsize_corr;
              cdata_gsize := signed(idout(kPosHbdGenSize'range))   + data_tsize_corr;
              dout_through(kPosHbdTransSize'range)  <= std_logic_vector(cdata_tsize);
              dout_through(kPosHbdGenSize'range)    <= std_logic_vector(cdata_gsize);
              dout_through(idout'high downto kPosHbdGenSize'high+1)    <= idout(idout'high downto kPosHbdGenSize'high+1);

              data_tsize_corr <= InvertSign(data_tsize_corr);
            else
              dout_through  <= idout;
            end if;

            cbuf_wren     <= '0';
            valid_through <= '1';
          end if;
        else
          valid_through <= ibuf_rdvalid;
          dout_through  <= idout;
        end if;
      end if;
    end if;
  end process;

  u_cbuf : xpm_fifo_sync
    generic map (
      DOUT_RESET_VALUE    => "0",
      ECC_MODE            => "no_ecc",
      FIFO_MEMORY_TYPE    => "auto",
      FIFO_READ_LATENCY   => 1,
      FIFO_WRITE_DEPTH    => 256,
      FULL_RESET_VALUE    => 0,
      PROG_EMPTY_THRESH   => 5,
      PROG_FULL_THRESH    => 240,
      RD_DATA_COUNT_WIDTH => 9,
      READ_DATA_WIDTH     => 64,
      USE_ADV_FEATURES    => "1707",
      WAKEUP_TIME         => 0,
      WR_DATA_COUNT_WIDTH => 9,
      WRITE_DATA_WIDTH    => 64
    )
    port map (
      sleep            => '0',
      rst              => syncReset,
      wr_clk           => clk,
      wr_en            => cbuf_wren,
      din              => cdin,
      prog_full        => open,
      rd_en            => cbuf_rden,
      dout             => cdout,
      data_valid       => cbuf_rdvalid,
      empty            => cbuf_empty,
      injectsbiterr    => '0',
      injectdbiterr    => '0'
    );

  -- Data Output --
  validOut  <= valid_through when(work_mode = kBuffering) else cbuf_rdvalid;
  dOut      <= dout_through  when(work_mode = kBuffering) else cdout;


end RTL;