library ieee, mylib;
use ieee.std_logic_1164.all;

entity ClkDivision3 is
  port(
    RST         : in  std_logic;
    CLK         : in  std_logic;
    Q           : out std_logic
    );
end ClkDivision3;

architecture RTL of ClkDivision3 is
  -- signal ------------------------------------------
  attribute keep      : string;
  signal div_clk      : std_logic;
  attribute keep of div_clk   : signal is "true";

  signal jk_q1, jk_q2 : std_logic;
  signal jk_j1, jk_j2 : std_logic;

  component JKFF is
    port(
      arst   : in std_logic;
      J      : in std_logic;
      K      : in std_logic;
      CLK    : in std_logic;
      Q      : out std_logic
      );
  end component;

begin
  -- ============================== body =================================
  jk_j1   <= NOT jk_q2;
  jk_j2   <=     jk_q1;

  Q       <= jk_q2;

  u_JKFF1 : JKFF port map(
    arst   => RST,
    J      => jk_j1,
    K      => '1',
    CLK    => CLK,
    Q      => jk_q1
    );

  u_JKFF2 : JKFF port map(
    arst   => RST,
    J      => jk_j2,
    K      => '1',
    CLK    => CLK,
    Q      => jk_q2
    );

end RTL;
