-----------------------------------------------------------------------------------------------
-- Tapped Delay Line
-- Originally designed by T.N. Takahashi
-- Reused by R. Honda
-----------------------------------------------------------------------------------------------

-- description of CARRY4 primitive
  -- all S (MUXCY's select inputs) must be set '1' to select Cin channels.
  -- This makes one input of the XOR gate to be '1'.
  -- When a rising edge goes through the carry chain, the outputs, CO0, CO1,
  -- CO2 and CO3 of the MUXCYs changeto '1' from '0'.
  -- When a falling edge comes, the outputs, O0, O1, O2 and O3 of the XOR gates
  -- also change to '1' from '0'.
  -- So we can use the MUXCY to detect the rising edge and the XOR gate to
  -- detect the falling edge, respectively.


-------------------------------------------------------------------------------
-- CO output
-------------------------------------------------------------------------------
library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use mylib.defHrTimingUnit.all;

library unisim;
use unisim.vcomponents.all;

-- _____________________________________________________________________________
entity TappedDelayLineV2 is
  generic
    (
      constant SliceOrigin  : string
    );
  port
    (
      CLK           : in std_logic;
      CIN           : in std_logic; -- signal input to carry chain
      calibIn       : in std_logic; -- Calibration clock
      testModeIn    : in std_logic;
      Q             : out std_logic_vector(kNumTaps-1 downto 0)
    );
end TappedDelayLineV2;

-- _____________________________________________________________________________
architecture RTL of TappedDelayLineV2 is

-- carry chain output CO
  signal co          : std_logic_vector(Q'high +1 downto 0);
  signal out_o       : std_logic_vector(Q'high +1 downto 0);
  signal ci          : std_logic_vector(kNumTaps/4-1 downto 0);

  signal first_co    : std_logic_vector(3 downto 0);
  signal di_in       : std_logic_vector(3 downto 0);
  signal s_in        : std_logic_vector(3 downto 0);
   -- data input of FF array. (co with async. delay)
  signal d_i         : std_logic_vector(Q'range);
  signal invert_sig             : std_logic;
  signal latch_1, latch_2       : std_logic;
  signal en_latch_1             : std_logic;

  signal async_latch            : std_logic;
  signal async_1                : std_logic;
  signal qa                     : std_logic_vector(kNumTaps-1 downto 0);
  signal inv_qa                 : std_logic_vector(kNumTaps-1 downto 0);

  attribute S           : string;
  attribute RLOC        : string;
  attribute RLOC_ORIGIN : string;
  attribute BEL         : string;
  attribute ASYNC_REG   : string;
  attribute S         of co                  : signal is "TRUE";
  attribute S         of ci                  : signal is "TRUE";
  attribute S         of CIN                 : signal is "TRUE";
  attribute S         of latch_1             : signal is "TRUE";
  attribute S         of Q                   : signal is "TRUE";
  attribute RLOC        of u_first_carry4_inst : label  is "X0Y0";
  attribute RLOC_ORIGIN of u_first_carry4_inst : label  is SliceOrigin;
  --attribute RLOC        of u_latch1_inst : label  is "X0Y0";
  --attribute RLOC_ORIGIN of u_latch1_inst : label  is SliceOrigin;

begin
  -- =============================================================================
  --                                    body
  -- =============================================================================
  -- signal connection -------------------------------------------------
  -- pulse stretcher (asynchronous latch) ------------------------------
  --u_latch1_inst : LDCE
  --generic map ( INIT => '0')
  --port map (Q => latch_1, CLR => RST, D => CIN, G => '1', GE => '1');

--  invert_sig    <= latch_1;
--  co(0)         <= invert_sig;
  --co(0)         <= latch_1;
  Q             <= inv_qa;
  di_in         <= "000" & calibIn;
  s_in          <= "111" & (not testModeIn);

  -- First CARRY4 ------------------------------------------------------
  --u_first_carry4_inst : CARRY4
  --  port map
  --  (
  --    CO     => first_co(3 downto 0),
  --    O      => open,
  --    CI     => '0',
  --    CYINIT => CIN,
  --    DI     => di_in,
  --    S      => s_in
  --  );

  u_first_carry4_inst : CARRY4
    port map
    (
      CO     => co(4 downto 1),
      O      => out_o(4 downto 1),
      CI     => '0',
      CYINIT => CIN,
      DI     => di_in,
      S      => s_in
    );

  -- signal connection -------------------------------------------------
  --co(0)   <= first_co(3);

  gen_carry_chain : for i in 1 to kNumTaps/4-1 generate
    --attribute RLOC_ORIGIN of u_carry4_inst : label is SliceOrigin;
    attribute RLOC of u_carry4_inst : label is "X0Y" & integer'image(i);
    --attribute RLOC of u_carry4_inst : label is "X0Y" & integer'image(i+1);
      begin
    --ci(i) <= co(4*i-1);
    ci(i) <= co(4*i);
    u_carry4_inst : CARRY4
      port map
      (
        --CO     => co(4*(i+1)-1 downto 4*i),
        CO     => co(4*(i+1) downto 4*i+1),
        O      => out_o(4*(i+1) downto 4*i+1),
        CI     => ci(i),
        CYINIT => '0',
        DI     => "0000",
        S      => "1111"
      );
  end generate;


  -- FF array
  -- FDCE : Xilinx primitive of D Flip-Flop with clock enable and asynchronous reset
  gen_ff : for i in 0 to kNumTaps/4-1 generate
    gen_case : if i = 0 generate
      --attribute RLOC of u_dff_insta : label is "X0Y" & integer'image(i+1);
      --attribute RLOC of u_dff_instb : label is "X0Y" & integer'image(i+1);
      --attribute RLOC of u_dff_instc : label is "X0Y" & integer'image(i+1);
      --attribute RLOC of u_dff_instd : label is "X0Y" & integer'image(i+1);
      attribute RLOC of u_dff_insta : label is "X0Y" & integer'image(i);
      attribute RLOC of u_dff_instb : label is "X0Y" & integer'image(i);
      attribute RLOC of u_dff_instc : label is "X0Y" & integer'image(i);
      attribute RLOC of u_dff_instd : label is "X0Y" & integer'image(i);
      attribute BEL  of u_dff_insta : label is "AFF";
      attribute BEL  of u_dff_instb : label is "BFF";
      attribute BEL  of u_dff_instc : label is "CFF";
      attribute BEL  of u_dff_instd : label is "DFF";
    begin

      d_i (4*i)   <= co(4*i+1);
      d_i (4*i+1) <= co(4*i+2);
      d_i (4*i+2) <= out_o(4*i+3);
      d_i (4*i+3) <= co(4*i+4);
      u_dff_insta : FDC port map ( CLR => '0', D => d_i(4*i  ), C => CLK, Q => qa(4*i  ) );
      u_dff_instb : FDC port map ( CLR => '0', D => d_i(4*i+1), C => CLK, Q => qa(4*i+1) );
      u_dff_instc : FDC port map ( CLR => '0', D => d_i(4*i+2), C => CLK, Q => qa(4*i+2) );
      u_dff_instd : FDC port map ( CLR => '0', D => d_i(4*i+3), C => CLK, Q => qa(4*i+3) );

      inv_qa(4*i)         <= qa(4*i);
      inv_qa(4*i+1)       <= qa(4*i+1);
      inv_qa(4*i+2)       <= not qa(4*i+2);
      inv_qa(4*i+3)       <= qa(4*i+3);
    else generate
      --attribute RLOC of u_dff_insta : label is "X0Y" & integer'image(i+1);
      --attribute RLOC of u_dff_instb : label is "X0Y" & integer'image(i+1);
      --attribute RLOC of u_dff_instc : label is "X0Y" & integer'image(i+1);
      --attribute RLOC of u_dff_instd : label is "X0Y" & integer'image(i+1);
      attribute RLOC of u_dff_insta : label is "X0Y" & integer'image(i);
      attribute RLOC of u_dff_instb : label is "X0Y" & integer'image(i);
      attribute RLOC of u_dff_instc : label is "X0Y" & integer'image(i);
      attribute RLOC of u_dff_instd : label is "X0Y" & integer'image(i);
      attribute BEL  of u_dff_insta : label is "AFF";
      attribute BEL  of u_dff_instb : label is "BFF";
      attribute BEL  of u_dff_instc : label is "CFF";
      attribute BEL  of u_dff_instd : label is "DFF";
    begin
      d_i (4*i)   <= out_o(4*i+1);
      d_i (4*i+1) <= co(4*i+2);
      d_i (4*i+2) <= out_o(4*i+3);
      d_i (4*i+3) <= co(4*i+4);
      u_dff_insta : FDC port map ( CLR => '0', D => d_i(4*i  ), C => CLK, Q => qa(4*i  ) );
      u_dff_instb : FDC port map ( CLR => '0', D => d_i(4*i+1), C => CLK, Q => qa(4*i+1) );
      u_dff_instc : FDC port map ( CLR => '0', D => d_i(4*i+2), C => CLK, Q => qa(4*i+2) );
      u_dff_instd : FDC port map ( CLR => '0', D => d_i(4*i+3), C => CLK, Q => qa(4*i+3) );

      inv_qa(4*i)         <= not qa(4*i);
      inv_qa(4*i+1)       <= qa(4*i+1);
      inv_qa(4*i+2)       <= not qa(4*i+2);
      inv_qa(4*i+3)       <= qa(4*i+3);

    end generate;
  end generate;


end RTL;





