library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defTDC.all;
use mylib.defTDCDelayBuffer.all;

entity TDCDelayBuffer is
  generic (
    kNumInput         : integer:= 32;
    enDEBUG           : boolean:= false
  );
  port (
    -- system --
    clk               : in  std_logic;  -- base clock
    enBypass          : in  std_logic;  -- Enable bypass route

    -- Data In --
    validIn           : in  std_logic_vector(kNumInput -1 downto 0);
    isLeadingIn       : in  std_logic_vector(kNumInput -1 downto 0);
    --isConflictedIn    : in  std_logic_vector(kNumInput -1 downto 0);
    dInTOT            : in  FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);
    dIn               : in  FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);

    -- Data Out --
    vaildOut          : out std_logic_vector(kNumInput -1 downto 0);
    isLeadingOut      : out std_logic_vector(kNumInput -1 downto 0);
    --isConflictedOut   : out std_logic_vector(kNumInput -1 downto 0);
    dOutTOT           : out FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);
    dOut              : out FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0)
  );
end TDCDelayBuffer;

architecture RTL of TDCDelayBuffer is

  -- signal decralation ----------------------------------------------
  -- output --
  signal reg_valid            : std_logic_vector(kNumInput -1 downto 0);
  signal reg_is_leading       : std_logic_vector(kNumInput -1 downto 0);
  --signal reg_is_confilicted   : std_logic_vector(kNumInput -1 downto 0);
  signal reg_dout             : FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);
  signal reg_dout_tot         : FineCountArrayType(kNumInput-1 downto 0)(kWidthFineCount-1 downto 0);

  -- BRAM
  constant kWidthDataBuffer   : integer  := kWidthDataUnit*1*kNumInput;
  signal waddr  : std_logic_vector(kWidthAddrBuffer-1 downto 0) :=(others=>'0');
  signal wdata  : std_logic_vector(kWidthDataBuffer-1 downto 0);
  signal raddr  : std_logic_vector(kWidthAddrBuffer-1 downto 0);
  signal rdata  : std_logic_vector(kWidthDataBuffer-1 downto 0);

  component finecount_bram
  port (
    clka  : IN  STD_LOGIC;
    wea   : IN  STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN  STD_LOGIC_VECTOR(kWidthAddrBuffer-1 DOWNTO 0);
    dina  : IN  STD_LOGIC_VECTOR(kWidthDataBuffer-1 DOWNTO 0);
    clkb  : IN  STD_LOGIC;
    enb   : IN STD_LOGIC;
    addrb : IN  STD_LOGIC_VECTOR(kWidthAddrBuffer-1 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(kWidthDataBuffer-1 DOWNTO 0)
  );
  end component;

  attribute mark_debug : boolean;
  attribute mark_debug of waddr   : signal is enDEBUG;
  attribute mark_debug of wdata   : signal is enDEBUG;
  attribute mark_debug of raddr   : signal is enDEBUG;
  attribute mark_debug of rdata   : signal is enDEBUG;

begin
  -- ============================= body ==============================

  -- output --
  vaildOut        <= reg_valid          when(enBypass = '0') else validIn;
  isLeadingOut    <= reg_is_leading     when(enBypass = '0') else isLeadingIn;
  --isConflictedOut <= reg_is_confilicted when(enBypass = '0') else isConflictedIn;
  dOutTOT         <= reg_dout_tot       when(enBypass = '0') else dInTOT;
  dOut            <= reg_dout           when(enBypass = '0') else dIn;

  -- BRAM w/r data --
  gen_ch : for i in 0 to kNumInput-1 generate

    -- wdata --
    wdata((i+1)*kWidthDataUnit -1)                                          <= validIn(i);
    wdata((i+1)*kWidthDataUnit -2)                                          <= isLeadingIn(i);
    --wdata((i+1)*kWidthDataUnit -3)                          <= isConflictedIn(i);
    wdata((i+1)*kWidthDataUnit -3 downto i*kWidthDataUnit+kWidthFineCount)  <= dInTOT(i);
    wdata((i+1)*kWidthDataUnit -3 -kWidthFineCount downto i*kWidthDataUnit)    <= dIn(i);

    -- rdata --
    reg_valid(i)          <=  rdata((i+1)*kWidthDataUnit -1);
    reg_is_leading(i)     <=  rdata((i+1)*kWidthDataUnit -2);
    --reg_is_confilicted(i) <=  rdata((i+1)*kWidthDataUnit -3);
    reg_dout_tot(i)       <=  rdata((i+1)*kWidthDataUnit -3 downto i*kWidthDataUnit+kWidthFineCount);
    reg_dout(i)           <=  rdata((i+1)*kWidthDataUnit -3 -kWidthFineCount downto i*kWidthDataUnit);

  end generate;

  -- BRAM w/r addr --
  addr_process : process(clk)
  begin
    if(clk'event and clk = '1') then
      waddr <= std_logic_vector(unsigned(waddr)+1);
      raddr <= std_logic_vector(unsigned(waddr)+kOffsetRAddr);
    end if;
  end process;

  -- BRAM --
  u_BRAM : finecount_bram
  port map(
    clka  => clk,
    wea   => "1",
    addra => waddr,
    dina  => wdata,
    clkb  => clk,
    enb   => '1',
    addrb => raddr,
    doutb => rdata
  );

end RTL;
