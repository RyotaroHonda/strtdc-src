library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use mylib.defHrTimingUnit.all;

library unisim;
use unisim.vcomponents.all;

entity RemappingTapsV3 is
  port (
    RST     : in std_logic;
    CLK     : in std_logic;
    TapIn   : in  std_logic_vector(kNumTaps-1 downto 0);
    TapOut  : out std_logic_vector(kNumRTaps downto 0)
    );
end RemappingTapsV3;

architecture RTL of RemappingTapsV3 is
  -- signal decralation -----------------------------------------------------
  signal reduced_taps : std_logic_vector(kNumRTaps downto 0);
  
begin
  -- =============================== body ======================================

  reduced_taps(0) <= or_reduce(TapIn(1 downto 0));
  reduced_taps(1) <= or_reduce(TapIn(5 downto 2));
  u_dff_inst0 : FDC port map(CLR=>'0', D=>reduced_taps(0), C=>CLK, Q=>TapOut(0)) ;
  u_dff_inst1 : FDC port map(CLR=>'0', D=>reduced_taps(1), C=>CLK, Q=>TapOut(1));   
  
  gen_remapping : for i in 2 to kNumRTaps-1 generate
  begin
    reduced_taps(i) <= or_reduce(TapIn(kNumOR*(i+1)-1 downto kNumOR*i));
    u_dff_inst : FDC port map(CLR=>'0', D=>reduced_taps(i), C=>CLK, Q=>TapOut(i)); 
  end generate;

  -- Extra RTap --
  reduced_taps(kNumRTaps)   <= or_reduce(TapIn(kNumTaps-1 downto kNumTaps-4));
  u_dfflst_inst : FDC port map(CLR=>'0', D=>reduced_taps(kNumRTaps), C=>CLK, Q=>TapOut(kNumRTaps));

end RTL;
