library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

use mylib.defDataBusAbst.all;
use mylib.defDelimiter.all;

entity DataSplitter is
  generic(
    kDivisionRatio  : integer
  );
  port(
    rst             : in std_logic;
    clk             : in std_logic;
    mznDIsAbsence   : in std_logic;
    pfullFifo       : out STD_LOGIC_VECTOR (kDivisionRatio-1 downto 0);

    -- Ports to BackMerger --
    rdEnIn          : in  STD_LOGIC_VECTOR (kDivisionRatio-1 downto 0);
    dataOut         : out DataArrayType(kDivisionRatio-1 downto 0);
    emptyOut        : out STD_LOGIC_VECTOR (kDivisionRatio-1 downto 0);
    aemptyOut       : out STD_LOGIC_VECTOR (kDivisionRatio-1 downto 0);
    validOut        : out STD_LOGIC_VECTOR (kDivisionRatio-1 downto 0);

    -- Ports to DDRReceiver --
    validIn         : in STD_LOGIC_VECTOR (kDivisionRatio-1 downto 0);
    dataIn          : in DataArrayType(kDivisionRatio-1 downto 0)
    );
end DataSplitter;

architecture RTL of DataSplitter is
  attribute mark_debug  : string;

  -- System -------------------------------------------------------------
  signal sync_reset     : std_logic;

  -- Splitter -----------------------------------------------------------
  signal is_2nd_delimiter : std_logic;

  -- Data buffer --------------------------------------------------------
  signal wren_fifo      : STD_LOGIC_VECTOR (kDivisionRatio-1 downto 0);
  signal din_fifo       : DataArrayType(kDivisionRatio-1 downto 0);

  COMPONENT ddr_data_buffer
    PORT (
      clk       : IN STD_LOGIC;
      srst      : IN STD_LOGIC;
      din       : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      wr_en     : IN STD_LOGIC;
      rd_en     : IN STD_LOGIC;
      dout      : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      full      : OUT STD_LOGIC;
      empty     : OUT STD_LOGIC;
      almost_empty : OUT STD_LOGIC;
      valid     : OUT STD_LOGIC;
      prog_full : OUT STD_LOGIC
      );
  END COMPONENT;


begin
  -- ======================================================================
  --                                 body
  -- ======================================================================

  -- Data splitting -------------------------------------------------------
  u_splitter : process(clk)
  begin
    if(clk'event and clk = '1') then
      if(sync_reset = '1') then
        is_2nd_delimiter  <= '0';
      else
        if(mznDIsAbsence = '0') then
          wren_fifo   <= validIn;
          din_fifo    <= dataIn;
        else
          wren_fifo(0)  <= validIn(0);
          din_fifo(0)   <= dataIn(0);
          if(validIn(0) = '1' and checkDelimiter(dataIn(0)(kPosHbdDataType'range)) = true) then
            wren_fifo(1)  <= '1';
            if(is_2nd_delimiter = '1') then
              din_fifo(1)(kPosHbdDataType'range)  <= dataIn(0)(kPosHbdDataType'range);
              din_fifo(1)(kPosHbdReserve1'range)  <= dataIn(0)(kPosHbdReserve1'range);
              din_fifo(1)(kPosHbdGenSize'range)   <= (others => '0');
              din_fifo(1)(kPosHbdTransSize'range) <= (others => '0');
              is_2nd_delimiter                  <= '0';
            else
              din_fifo(1)       <= dataIn(0);
              is_2nd_delimiter  <= '1';
            end if;
          else
            wren_fifo(1)  <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Data buffer --
  gen_ports : for i in 0 to kDivisionRatio-1 generate
  begin
    u_ddr_buf : ddr_data_buffer
      port map(
      clk       => clk,
      srst      => sync_reset,
      din       => din_fifo(i),
      wr_en     => wren_fifo(i),
      rd_en     => rdEnIn(i),
      dout      => dataOut(i),
      full      => open,
      empty     => emptyOut(i),
      almost_empty => aemptyOut(i),
      valid     => validOut(i),
      prog_full => pfullFifo(i)
      );
  end generate;

  -- Reset sequence --
  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rst, clk, sync_reset);


end RTL;
