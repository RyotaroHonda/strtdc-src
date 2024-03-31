library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defDelimiter.all;

entity MergerMznBlock is
  generic (
    kNumInput         : integer:= 32;
    kDivisionRatio    : integer:= 1;
    enDEBUG : boolean := false
  );
  port (
    clk                 : in STD_LOGIC;   --base clock
    syncReset           : in STD_LOGIC;   --base reset

    rdenOut             : out STD_LOGIC_VECTOR (kNumInput-1 downto 0); --input fifo read enable
    dataIn              : in  DataArrayType(kNumInput-1 downto 0);     --input fifo data out
    emptyIn             : in  STD_LOGIC_VECTOR (kNumInput-1 downto 0); --input fifo empty_from_front flag
    almostEmptyIn       : in  STD_LOGIC_VECTOR (kNumInput-1 downto 0); --input fifo almost empty flag
    validIn             : in  STD_LOGIC_VECTOR (kNumInput-1 downto 0); --input fifo valid flag

    rdenIn              : in  STD_LOGIC;                                  --output fifo read enable
    dataOut             : out STD_LOGIC_VECTOR (kWidthData-1 downto 0);   --output fifo data out
    emptyOut            : out STD_LOGIC;                                  --output fifo empty flag
    almostEmptyOut      : out STD_LOGIC;                                  --output fifo almost empty flag
    validOut            : out STD_LOGIC                                   --output fifo valid flag
  );
end MergerMznBlock;

architecture Behavioral of MergerMznBlock is

  -- System --

  -- between mergerFront and mergerBack
  signal rden_to_back             : std_logic_vector(0 downto 0);
  signal dout_from_front          : DataArrayType(0 downto 0);
  signal empty_from_front         : std_logic_vector(0 downto 0);
  signal almost_empty_from_front  : std_logic_vector(0 downto 0);
  signal valid_from_front         : std_logic_vector(0 downto 0);

  attribute mark_debug : boolean;
  attribute mark_debug of rden_to_back  : signal is enDEBUG;
  attribute mark_debug of empty_from_front : signal is enDEBUG;

begin

  gen_mergerFront: for i in kDivisionRatio-1 downto 0 generate
  begin

    u_mergerFront: entity mylib.MergerUnit
    generic map(
      kType       => "Front",
      kNumInput   => kNumInput,
      enDEBUG     => enDEBUG
    )
    port map(
      clk             => clk,
      syncReset       => syncReset,

      progFullFifo    => open,
      hbfNumMismatch  => open,

      rdenOut         => rdenOut((i+1)*kNumInput-1 downto i*kNumInput),
      dataIn          => dataIn(kNumInput*(i+1)-1 downto kNumInput*i),
      emptyIn         => emptyIn((i+1)*kNumInput-1 downto i*kNumInput),
      almostEmptyIn   => almostEmptyIn((i+1)*kNumInput-1 downto i*kNumInput),
      validIn         => validIn((i+1)*kNumInput-1 downto i*kNumInput),

      rdenIn          => rden_to_back(i),
      dataOut         => dout_from_front(i),
      emptyOut        => empty_from_front(i),
      almostEmptyOut  => almost_empty_from_front(i),
      validOut        => valid_from_front(i)

    );
  end generate;

  rden_to_back(0) <= rdenIn;
  dataOut         <= dout_from_front(0);
  emptyOut        <= empty_from_front(0);
  almostEmptyOut  <= almost_empty_from_front(0);
  validOut        <= valid_from_front(0);

end Behavioral;
