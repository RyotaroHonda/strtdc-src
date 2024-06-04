library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defTdc.all;
use mylib.defDelimiter.all;
--use mylib.defMerger.all;

entity MergerUnit is
  generic (
    kType           : string:= "Front"; -- "Front" or "Back"
    kNumInput       : integer:= 32;
    kOffsetBitShift : integer:= 0;      -- if kNumInput=2, kOffsetBitShift=1 (divided by 2^kOffsetBitShift) for HR-TDC base merger
    enDEBUG         : boolean:= false
  );
  port (
    -- System --
    syncReset           : in STD_LOGIC;   -- Scynchronous reset
    clk                 : in STD_LOGIC;   -- System clock
    progFullFifo        : out std_logic;  -- Merger FIFO programmed full signal
    hbfNumMismatch      : out std_logic;  -- Heartbeat frame number mismatch among input channel.

    -- Merger input --
    rdenOut             : out STD_LOGIC_VECTOR (kNumInput-1 downto 0); --input fifo read enable
    dataIn              : in  DataArrayType(kNumInput-1 downto 0);     --input fifo data out
    emptyIn             : in  STD_LOGIC_VECTOR (kNumInput-1 downto 0); --input fifo empty flag
    almostEmptyIn       : in  STD_LOGIC_VECTOR (kNumInput-1 downto 0); --input fifo almost empty flag
    validIn             : in  STD_LOGIC_VECTOR (kNumInput-1 downto 0); --input fifo valid flag

    -- Merger output --
    rdenIn              : in  STD_LOGIC;                                --output fifo read enable
    dataOut             : out STD_LOGIC_VECTOR (kWidthData-1 downto 0); --output fifo data out
    emptyOut            : out STD_LOGIC;                                --output fifo empty flag
    almostEmptyOut      : out STD_LOGIC;                                --output fifo almost empty flag
    validOut            : out STD_LOGIC                                 --output fifo valid flag
  );
end MergerUnit;

architecture Behavioral of MergerUnit is
  constant kZero                : std_logic_vector(kNumInput-1 downto 0):= (others => '0');

  -- read input fifo --
  signal rden_inputfifo         : std_logic_vector(kNumInput-1 downto 0);
  signal is_read_inputfifo      : std_logic_vector(kNumInput-1 downto 0);

  -- Data input --
  signal din_merger             : std_logic_vector(kWidthData-1 downto 0);

  -- Flag for delimiter words --
  signal mask_delimiter         : std_logic_vector(kNumInput-1 downto 0);
  signal flag_last1stdelimiter  : boolean;
  signal flag_wait2nddelimiter  : std_logic_vector(kNumInput-1 downto 0);

  -- Flag in delimiter words --
  -- 1st
  signal delimiter_flag         : std_logic_vector(kPosHbdFlag'length-1 downto 0);
  signal delimiter_offset       : unsigned(kPosHbdOffset'length-1 downto 0);
  -- 2st
  signal delimiter_userreg      : std_logic_vector(kPosHbdUserReg'length-1 downto 0);
  signal delimiter_gensize      : unsigned(kPosHbdGenSize'length-1 downto 0);

  -- Hb frame check --
  signal reg_hbfnum             : std_logic_vector(kPosHbdHBFrame'length-1 downto 0);
  signal hbfnum_mismatch        : std_logic;
  signal hbfnum_is_registered   : std_logic;

  -- full --
  signal reg_full               : std_logic;
  signal needread_full          : std_logic_vector(kNumInput-1 downto 0);

  -- write output fifo --
  signal wren_outputfifo        : std_logic;
  signal din_outputfifo         : std_logic_vector(kWidthData-1 downto 0);
  signal full_outputfifo        : std_logic;
  signal almost_empty_outputfifo: std_logic;
  signal prog_full_outputfifo   : std_logic;

  component mergerFrontFifo is
    PORT(
      clk         : in  STD_LOGIC;
      srst        : in  STD_LOGIC;

      wr_en       : in  STD_LOGIC;
      din         : in  STD_LOGIC_VECTOR (kWidthData-1 DOWNTO 0);
      full        : out STD_LOGIC;
      almost_full : out STD_LOGIC;

      rd_en       : in  STD_LOGIC;
      dout        : out STD_LOGIC_VECTOR (kWidthData-1 DOWNTO 0);
      empty       : out STD_LOGIC;
      almost_empty: out STD_LOGIC;
      valid       : out STD_LOGIC;

      prog_full   : out STD_LOGIC
    );
  end component;

  component mergerBackFifo is
    PORT(
      clk         : in  STD_LOGIC;
      srst        : in  STD_LOGIC;

      wr_en       : in  STD_LOGIC;
      din         : in  STD_LOGIC_VECTOR (kWidthData-1 DOWNTO 0);
      full        : out STD_LOGIC;
      almost_full : out STD_LOGIC;

      rd_en       : in  STD_LOGIC;
      dout        : out STD_LOGIC_VECTOR (kWidthData-1 DOWNTO 0);
      empty       : out STD_LOGIC;
      almost_empty: out STD_LOGIC;
      valid       : out STD_LOGIC;

      prog_full   : out STD_LOGIC
    );
    end component;

  -- function get_rightmost --
  function get_rightmost( din : std_logic_vector  ) return std_logic_vector is
  begin
    --return din and ((not din)+"1");
    return din and std_logic_vector(unsigned((not din)) + 1 );
  end get_rightmost;

  -- function get_needread --
  function get_needread(  remainder             : std_logic_vector;
                          valid                 : std_logic_vector;
                          rden                  : std_logic_vector;
                          rd                    : std_logic_vector;
                          mask                  : std_logic_vector;
                          din                   : std_logic_vector;
                          flag_wait2nd_hbd : std_logic_vector;
                          flag_last1st_hbd : boolean           ) return std_logic_vector is
    variable flag_delimiter : boolean;
  begin
    flag_delimiter  := checkDelimiter(din(kPosHbdDataType'range));

    if(remainder /= kZero)then
      return remainder;

    elsif((flag_delimiter and (not (rd or mask)) = kZero) or flag_last1st_hbd)then   --last delimiter
      return valid and (not rden);

    elsif((flag_delimiter and (rd and mask) = kZero) or flag_wait2nd_hbd=rden) then  --other delimiter
      return valid and (not rden) and (not rd) and (not mask);

    else                                        --normal
      return valid and (not rden) and (not mask);
    end if;
  end get_needread;

  -- check_hbfnum_mismatch --
  function check_hbfnum_mismatch(  hbf_number0 : std_logic_vector;
                          hbf_number1 : std_logic_vector ) return std_logic is
    variable result   : std_logic;
  begin
    if(hbf_number0 = hbf_number1) then
      result  := '0';
    else
      result  := '1';
    end if;
    return result;
  end check_hbfnum_mismatch;

  -- avg_delimiter_offset --
  function cal_delimiter_offset(  input_offset        : unsigned(kPosHbdOffset'length-1 downto 0);
                                  accumulation_offset : unsigned(kPosHbdOffset'length-1 downto 0)
                                  ) return unsigned is
    variable output_offsset : unsigned(kPosHbdOffset'length-1 downto 0):= (others => '0');
  begin
    output_offsset  := (others=>'0');
    if(kOffsetBitShift=0)then
      return input_offset;
    else
      output_offsset(kPosHbdOffset'length-1-kOffsetBitShift downto 0) := input_offset(kPosHbdOffset'length-1 downto kOffsetBitShift);
      return output_offsset+accumulation_offset;
    end if;
  end cal_delimiter_offset;

  -- debug --
  signal  debug_valid     : std_logic_vector(kNumInput-1 downto 0);
  signal  debug_needread  : std_logic_vector(kNumInput-1 downto 0);
  signal  debug_remainder : std_logic_vector(kNumInput-1 downto 0);

  attribute mark_debug : boolean;
  attribute mark_debug of mask_delimiter        : signal is enDEBUG;
  attribute mark_debug of flag_last1stdelimiter : signal is enDEBUG;
  attribute mark_debug of flag_wait2nddelimiter : signal is enDEBUG;
  attribute mark_debug of prog_full_outputfifo  : signal is enDEBUG;
  attribute mark_debug of hbfnum_mismatch       : signal is enDEBUG;
  attribute mark_debug of din_merger            : signal is enDEBUG;
  attribute mark_debug of reg_hbfnum            : signal is enDEBUG;

  -- Stop optimization --
  -- attribute keep  : string;
  -- attribute keep of mask_delimiter        : signal is "true";
  -- attribute keep of flag_last1stdelimiter : signal is "true";
  -- attribute keep of flag_wait2nddelimiter : signal is "true";
  -- attribute keep of prog_full_outputfifo  : signal is "true";
  -- attribute keep of debug_valid           : signal is "true";
  -- attribute keep of debug_needread        : signal is "true";
  -- attribute keep of debug_remainder       : signal is "true";
  -- attribute keep of rden_inputfifo        : signal is "true";
  -- attribute keep of is_read_inputfifo     : signal is "true";

begin
  -- ======================================================================
  --                                 body
  -- ======================================================================

  hbfNumMismatch  <= hbfnum_mismatch;
  progFullFifo    <= prog_full_outputfifo;

  --input fifo read
  rden_inputfifo_process : process(clk)
    variable needread   : std_logic_vector(kNumInput-1 downto 0);
    variable rden       : std_logic_vector(kNumInput-1 downto 0);
    variable remainder  : std_logic_vector(kNumInput-1 downto 0);
  begin
    if(clk'event and clk = '1')then
      if(syncReset = '1')then
        needread      := (others=>'0');
        rden          := (others=>'0');
        remainder     := (others=>'0');
        rden_inputfifo<= (others=>'0');
        reg_full      <= '0';
        needread_full <= (others=>'0');
      else

        if((prog_full_outputfifo='0') and reg_full='1')then                                     -- end of full mode
          needread  := needread_full;
        elsif((checkDelimiter(din_merger(kPosHbdDataType'range)) and (is_read_inputfifo and mask_delimiter) = kZero and flag_last1stdelimiter=false) or flag_wait2nddelimiter=rden_inputfifo)then  -- read the first delimiter or read the 2nd delimiter word when full mode
          needread  := get_needread(remainder,not emptyIn,rden_inputfifo,is_read_inputfifo,mask_delimiter,din_merger,flag_wait2nddelimiter,flag_last1stdelimiter);

        elsif((almostEmptyIn and rden_inputfifo) /= kZero)then                                 --read input fifo is almost empty
          needread  := get_needread(remainder,not emptyIn,rden_inputfifo,is_read_inputfifo,mask_delimiter,din_merger,flag_wait2nddelimiter,flag_last1stdelimiter);

        elsif(rden = kZero)then                                                                     --rden_inputfifo is empty (idle, not rden run)
          needread  := get_needread(remainder,not emptyIn,rden_inputfifo,is_read_inputfifo,mask_delimiter,din_merger,flag_wait2nddelimiter,flag_last1stdelimiter);

        else
          needread  := needread;

        end if;

        if(prog_full_outputfifo='1')then  -- full
          if(reg_full='0')then              -- full start
            needread_full <= needread;      -- record "needread" static until the output fifo is not full
          end if;

          needread  := (others=>'0');
        else
          needread_full <= (others=>'0');
        end if;

        rden            := get_rightmost(needread);
        remainder       := needread and (not rden);
        rden_inputfifo  <= rden;
        reg_full        <= prog_full_outputfifo;
        -- debug
        debug_valid     <= not emptyIn;
        debug_needread  <= needread;
        debug_remainder <= remainder;
      end if;
    end if;
  end process;

  rdenOut  <= rden_inputfifo;
  is_read_inputfifo   <= validIn;

  for_switch_input_to_output : for i in kNumInput-1 downto 0 generate
    din_merger  <= dataIn(i) when (is_read_inputfifo(i)='1') else (others=>'Z');
  end generate for_switch_input_to_output;

  --mask
  mask_process : process(clk)
  begin
    if(clk'event and clk = '1')then
      if(syncReset = '1') then
        mask_delimiter        <= (others=>'0');
        flag_wait2nddelimiter <= (others=>'0');
        flag_last1stdelimiter <= false;
      else
        if(checkDelimiter(din_merger(kPosHbdDataType'range)))then -- delimiter
          --if((not (is_read_inputfifo or mask_delimiter))="0")then  -- last 1st delimiter
          if((not (is_read_inputfifo or mask_delimiter)) = kZero)then  -- last 1st delimiter
            mask_delimiter        <= (others=>'0');
            flag_wait2nddelimiter <= is_read_inputfifo;
            flag_last1stdelimiter <= true;
          elsif(flag_last1stdelimiter)then                    -- last 2nd delimiter
            mask_delimiter        <= (others=>'0');
            flag_wait2nddelimiter <= (others=>'0');
            flag_last1stdelimiter <= false;
          --elsif((is_read_inputfifo and mask_delimiter) = "0")then    -- 1st delimiter
          elsif((is_read_inputfifo and mask_delimiter) = kZero)then    -- 1st delimiter
            mask_delimiter        <= mask_delimiter or is_read_inputfifo;
            flag_wait2nddelimiter <= is_read_inputfifo;
            flag_last1stdelimiter <= false;
          else                                                -- 2nd delimiter
            mask_delimiter        <= mask_delimiter;
            flag_wait2nddelimiter <= (others=>'0');
            flag_last1stdelimiter <= false;
          end if;
        end if;
      end if;
    end if;
  end process;

  --output fifo
  outputfifo_process : process(clk)
  begin
    if(clk'event and clk = '1')then
      if(syncReset = '1') then
        wren_outputfifo       <= '0';
        delimiter_flag        <= (others=>'0');
        delimiter_offset      <= (others=>'0');
        delimiter_userreg     <= (others=>'0');
        delimiter_gensize     <= (others=>'0');

        hbfnum_is_registered  <= '0';
        hbfnum_mismatch       <= '0';
      else
        -- delimiter
        if(checkDelimiter(din_merger(kPosHbdDataType'range)))then
          --- last delimiter
          if((not (is_read_inputfifo or mask_delimiter)) = kZero or flag_last1stdelimiter)then
            wren_outputfifo <= '1';
            --din_outputfifo  <= din_merger;

            -- 1st delimiter --
            if(flag_wait2nddelimiter = kZero)then
              din_outputfifo(kPosHbdDataType'range) <= din_merger(kPosHbdDataType'range);
              din_outputfifo(kPosHbdReserve1'range) <= din_merger(kPosHbdReserve1'range);
              din_outputfifo(kPosHbdFlag'range)     <= din_merger(kPosHbdFlag'range) or delimiter_flag or genFlagVector(kIndexLHbfNumMismatch, check_hbfnum_mismatch(din_merger(kPosHbdHBFrame'range), reg_hbfnum) or hbfnum_mismatch);
              din_outputfifo(kPosHbdOffset'range)   <= std_logic_vector( cal_delimiter_offset(unsigned(din_merger(kPosHbdOffset'range)),delimiter_offset) );
              din_outputfifo(kPosHbdHBFrame'range)  <= din_merger(kPosHbdHBFrame'range);

              hbfnum_mismatch                       <= check_hbfnum_mismatch(din_merger(kPosHbdHBFrame'range), reg_hbfnum) or hbfnum_mismatch;

            -- 2nd delimiter --
            else
              din_outputfifo(kPosHbdDataType'range) <= din_merger(kPosHbdDataType'range);
              din_outputfifo(kPosHbdReserve1'range) <= din_merger(kPosHbdReserve1'range);
              din_outputfifo(kPosHbdUserReg'range)  <= din_merger(kPosHbdUserReg'range) or delimiter_userreg;
              din_outputfifo(kPosHbdGenSize'range)  <= std_logic_vector( unsigned(din_merger(kPosHbdGenSize'range)) + delimiter_gensize );
              delimiter_flag        <= (others=>'0');
              delimiter_offset      <= (others=>'0');
              delimiter_userreg     <= (others=>'0');
              delimiter_gensize     <= (others=>'0');
              hbfnum_is_registered  <= '0';
              hbfnum_mismatch       <= '0';
            end if;

          --- no last delimiter
          else
            wren_outputfifo <= '0';

            -- 1st delimiter --
            if(flag_wait2nddelimiter = kZero)then
              delimiter_flag    <= din_merger(kPosHbdFlag'range) or delimiter_flag;
              delimiter_offset  <= cal_delimiter_offset(unsigned(din_merger(kPosHbdOffset'range)),delimiter_offset);
              if(hbfnum_is_registered = '1') then
                hbfnum_mismatch       <= check_hbfnum_mismatch(din_merger(kPosHbdHBFrame'range), reg_hbfnum) or hbfnum_mismatch;
              else
                hbfnum_is_registered  <= '1';
                reg_hbfnum            <= din_merger(kPosHbdHBFrame'range);
              end if;

            -- 2nd delimiter --
            else
              delimiter_userreg <= din_merger(kPosHbdUserReg'range) or delimiter_userreg;
              delimiter_gensize <= unsigned(din_merger(kPosHbdGenSize'range)) + delimiter_gensize;
            end if;
          end if;

        -- TDC data
        elsif(is_read_inputfifo /= kZero)then
            wren_outputfifo <= '1';
            din_outputfifo  <= din_merger;

        -- not data
        else
          wren_outputfifo <= '0';
        end if;
      end if;
    end if;
  end process;

  gen_front : if kType = "Front" generate
  begin

    u_mergerFifo: mergerFrontFifo port map(
      clk         => clk,
      srst        => syncReset,

      wr_en       => wren_outputfifo,
      din         => din_outputfifo,
      full        => full_outputfifo,
      almost_full => almost_empty_outputfifo,

      rd_en       => rdenIn,
      dout        => dataOut,
      empty       => emptyOut,
      almost_empty=> almostEmptyOut,
      valid       => validOut,

      prog_full   => prog_full_outputfifo
    );
  end generate;

  gen_back : if kType = "Back" generate
  begin

    u_mergerFifo: mergerBackFifo port map(
      clk         => clk,
      srst        => syncReset,

      wr_en       => wren_outputfifo,
      din         => din_outputfifo,
      full        => full_outputfifo,
      almost_full => almost_empty_outputfifo,

      rd_en       => rdenIn,
      dout        => dataOut,
      empty       => emptyOut,
      almost_empty=> almostEmptyOut,
      valid       => validOut,

      prog_full   => prog_full_outputfifo
    );
  end generate;


end Behavioral;
