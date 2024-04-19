library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use mylib.defHrTimingUnit.all;

entity LeadFinder is
    port (
        CLK     : in std_logic;
        TapIn   : in  std_logic_vector(kNumTaps-1 downto 0);
        LeadOut : out std_logic_vector(kNumTaps-1 downto 0)
    );
end LeadFinder;

architecture RTL of LeadFinder is
    -- signal decralation ----------------------------------------------------------
    signal virtual_tapin    : std_logic_vector(TapIn'high+2 downto 0);

    signal lead_vector      : std_logic_vector(LeadOut'range);

begin
    -- =============================== body =======================================
    --virtual_tapin   <= '0' & TapIn;
    virtual_tapin   <= "01" & TapIn(kNumTaps-1 downto 0);

    u_lead_find : for i in 0 to kNumTaps-1 generate
    begin
        lead_vector(i) <= virtual_tapin(i) AND (NOT virtual_tapin(i+1)) AND (NOT virtual_tapin(i+2));
    end generate;

    u_buf : process(CLK)
    begin
        if(CLK'event AND CLK = '1') then
            LeadOut <= lead_vector;
        end if;
    end process;

end RTL;
