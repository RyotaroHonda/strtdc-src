library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library mylib;
use mylib.defDelimiter.all;
use mylib.defDataBusAbst.all;
use mylib.defHeartBeatUnit.all;

entity VitalBlockBase is
  generic (
    kDivisionRatio      : integer:= 2;
    enDEBUG             : boolean := false
  );
  port (
    rst                 : in STD_LOGIC;  -- User reset (asynchronous)
    clk                 : in STD_LOGIC;  -- Base clock

    -- status input --
    intputThrottlingOn  : in std_logic; -- Signal indicating InputThrottlingType2 is active
    pfullLinkIn         : in std_logic; -- Programmable full flag from LinkBuffer
    emptyLinkIn         : in std_logic; -- Empty flag from LinkBuffer

    -- status output --
    progFullFifo        : out STD_LOGIC; -- Back Merger FIFO programmed full signal
    lhbfNumMismatch     : out std_logic; -- Local heartbeat frame num mismatch
    outThrottlingOn     : out std_logic; -- Output throttling status

    -- Data input from Mezzanine --
    rdEnOut             : out STD_LOGIC_VECTOR (kDivisionRatio-1 downto 0);
    dataIn              : in  DataArrayType(kDivisionRatio-1 downto 0);
    emptyIn             : in  STD_LOGIC_VECTOR (kDivisionRatio-1 downto 0);
    almostEmptyIn       : in  STD_LOGIC_VECTOR (kDivisionRatio-1 downto 0);
    validIn             : in  STD_LOGIC_VECTOR (kDivisionRatio-1 downto 0);

    -- Data output --
    rdEnIn              : in  STD_LOGIC;
    dataOut             : out STD_LOGIC_VECTOR (kWidthData-1 downto 0);
    emptyOut            : out STD_LOGIC;
    almostEmptyOut      : out STD_LOGIC;
    validOut            : out STD_LOGIC
  );
end VitalBlockBase;

architecture Behavioral of VitalBlockBase is

  -- System --
  attribute mark_debug  : boolean;
  signal sync_reset             : std_logic;

  -- Back Merger --
  signal valid_mgr          : std_logic;
  signal empty_mgr          : std_logic;
  signal dout_mgr           : std_logic_vector(kWidthData-1 downto 0);

  signal pfull_back_merger      : std_logic;
  signal local_hbf_num_mismatch : std_logic;
  signal output_throttling_on   : std_logic;
  signal read_enable_to_merger  : std_logic;

  attribute mark_debug of valid_mgr   : signal is enDEBUG;
  attribute mark_debug of empty_mgr   : signal is enDEBUG;
  attribute mark_debug of dout_mgr    : signal is enDEBUG;

  -- Output throttling --

begin

  lhbfNumMismatch <= local_hbf_num_mismatch;
  progFullFifo    <= pfull_back_merger;
  outThrottlingOn <= output_throttling_on;

  read_enable_to_merger   <= '1' when(output_throttling_on = '1') else rdEnIn;

  -- Back Merger --
  u_BMGR : entity mylib.MergerUnit
    generic map(
      kType     => "Back",
      kNumInput => kDivisionRatio,
      enDEBUG   => false
    )
    port map(
      clk                 => clk,
      rst                 => sync_reset,
      progFullFifo        => pfull_back_merger,
      hbfNumMismatch      => local_hbf_num_mismatch,

      rdEnOut             => rdEnOut,
      dataIn              => dataIn,
      emptyIn             => emptyIn,
      almostEmptyIn       => almostEmptyIn,
      validIn             => validIn,

      rdEnIn              => read_enable_to_merger,
      dataOut             => dout_mgr,
      emptyOut            => emptyOut,
      almostEmptyOut      => almostEmptyOut,
      validOutt           => valid_mgr
    );


  u_OutThrottle: entity mylib.OutputThrottling
    generic map(
      enDEBUG => false
    )
    port map(
      rst     => sync_reset,
      clk     => clk,

      -- status input --
      intputThrottlingOn  => intputThrottlingOn,
      pfullLinkIn         => pfullLinkIn,
      emptyLinkIn         => emptyLinkIn,

      -- Status output --
      isWorking           => output_throttling_on,

      -- Data In --
      validIn             => valid_mgr,
      dIn                 => dout_mgr,

      -- Data Out --
      validOut            => validOutt,
      dOut                => dataOut

    );


  -- Reset sequence --
  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rst, clk, sync_reset);

end Behavioral;
