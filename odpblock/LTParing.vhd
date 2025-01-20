library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.all;

library mylib;
use mylib.defDataBusAbst.all;
use mylib.defTDC.all;
use mylib.defDelimiter.all;

entity LTParingUnit is
  generic(
    enDEBUG         : boolean:= false
  );
  port(
    syncReset       : in std_logic;   -- base reset
    clk             : in std_logic;   -- base clock
    enBypass        : in std_logic;

    -- Data In --
    validIn         : in std_logic;
    dIn             : in std_logic_vector(kWidthData-1 downto 0);

    -- Data Out --
    validOut        : out std_logic;
    dOut            : out std_logic_vector(kWidthData-1 downto 0)
  );
end LTParingUnit;

architecture RTL of LTParingUnit is

-- Signal decralation ---------------------------------------------

  signal data_type        : std_logic_vector(kWidthDataType-1 downto 0);

  constant kMaxWaitCount  : integer:= kMaxPairingCount;
  signal buf_leading      : std_logic_vector(dIn'range);
  signal data_out         : std_logic_vector(dIn'range);

  type DelimiterBufType is array (integer range 1 downto 0) of std_logic_vector(dIn'range);
  signal buf_delimiter    : DelimiterBufType;

  signal valid_out        : std_logic;
  signal delimiter_exist  : std_logic;

  type PairingProcessType is
    (
      WaitLeading, WaitTrailing, FlushDelimiter, Push2ndDelimiter
    );

  signal transition_reserve : std_logic;
  signal state_paring       : PairingProcessType;

  signal del_index_debug    : integer range 0 to 1:= 0;

  -- debug --
  attribute mark_debug      : boolean;
  attribute mark_debug of valid_out : signal is enDEBUG;
  attribute mark_debug of data_out  : signal is enDEBUG;

begin
  -- =========================== body ===============================

  -- Entity IO --
  validOut    <= valid_out when(enBypass = '0') else validIn;
  dOut        <= data_out  when(enBypass = '0') else dIn;
  data_type   <= dIn(kPosHbdDataType'range);
  -- Entity IO --

  u_sm : process(clk)
    variable  wait_count    : integer range 0 to kMaxWaitCount+1  := 0;
    variable  del_index     : integer range 0 to 1:= 0;
  begin
    if(clk'event and clk = '1') then
      if(syncReset = '1') then
        wait_count          := 0;
        del_index           := 0;
        valid_out           <= '0';
        transition_reserve  <= '0';
        delimiter_exist     <= '0';
        state_paring        <= WaitLeading;
      else
        case state_paring is
          when WaitLeading =>

            -- Process for leading data --
            if(delimiter_exist = '0') then
              if(validIn = '1' and data_type = kDatatypeTDCData) then
                buf_leading     <= dIn;
                wait_count      := 0;
                del_index       := 0;
                state_paring    <= WaitTrailing;
              elsif(transition_reserve = '1') then
                transition_reserve  <= '0';
                wait_count          := 0;
                del_index           := 0;
                state_paring        <= WaitTrailing;
              end if;
            end if;

            -- Process for delimiter data --
            if(delimiter_exist = '1') then
              data_out          <= buf_delimiter(del_index);
              valid_out         <= '1';

              if(del_index = 1) then
                delimiter_exist   <= '0';
              else
                del_index         := 1;
              end if;

              if(validIn = '1' and data_type = kDatatypeTDCData) then
                buf_leading         <= dIn;
                transition_reserve  <= '1';
              end if;

            elsif(validIn = '1' and checkDelimiter(data_type) = true) then
              data_out          <= dIn;       -- Through
              valid_out         <= validIn;   -- Through
            else
              valid_out         <= '0';
            end if;

          when WaitTrailing =>
            -- Process for L/T data --
            if(wait_count = kMaxWaitCount) then
              -- Time out. No pair. --
              data_out      <= buf_leading;
              valid_out     <= '1';

              if(validIn = '1' and data_type = kDatatypeTDCData) then
                buf_leading       <= dIn;
                wait_count        := 0;
                if(delimiter_exist = '1') then
                  del_index       := 0;
                  state_paring    <= FlushDelimiter;
                end if;
              elsif(validIn = '1' and checkDelimiter(data_type) = true) then
                buf_delimiter(del_index)  <= dIn;

                if(delimiter_exist = '1') then
                  del_index     := 0;
                  state_paring  <= WaitLeading;
                else
                  delimiter_exist   <= '1';
                  del_index         := 1;
                  state_paring      <= Push2ndDelimiter;
                end if;
              else
                del_index     := 0;
                state_paring  <= WaitLeading;
              end if;

            elsif(validIn = '1' and data_type = kDatatypeTDCDataT) then
              -- Trailing is found. Calculate TOT.
              data_out(kPosHbdDataType'range) <= buf_leading(kPosHbdDataType'range);
              data_out(kPosChannel'range)     <= buf_leading(kPosChannel'range);
              data_out(kPosTot'range)         <= std_logic_vector(unsigned(dIn(kPosTot'length+kPosTiming'low-1 downto kPosTiming'low)) - unsigned(buf_leading(kPosTot'length+kPosTiming'low-1 downto kPosTiming'low)));
              data_out(kPosTiming'high downto 0) <= (kPosTiming'range => buf_leading(kPosTiming'range), others => '0');
              valid_out                       <= '1';

              del_index                       := 0;
              state_paring                    <= WaitLeading;
            elsif(validIn = '1' and data_type = kDatatypeTDCData) then
              -- Next leading data comes. No pair. Update the buffer. --
              data_out          <= buf_leading;
              valid_out         <= '1';
              buf_leading       <= dIn;
              wait_count        := 0;
              if(delimiter_exist = '1') then
                del_index       := 0;
                state_paring    <= FlushDelimiter;
              end if;
            elsif(validIn = '1' and checkDelimiter(data_type) = true) then
              buf_delimiter(del_index)  <= dIn;
              delimiter_exist           <= '1';
              if(del_index = 0) then
                del_index := 1;
              end if;
            else
              wait_count        := wait_count +1;
              valid_out         <= '0';
            end if;

          when FlushDelimiter =>
            data_out          <= buf_delimiter(del_index);
            valid_out         <= '1';
            delimiter_exist   <= '0';

            if(del_index = 1) then
              del_index         := 0;
              state_paring      <= WaitTrailing;
            else
              del_index         := 1;
            end if;

          when Push2ndDelimiter =>
            if(validIn = '1' and checkDelimiter(data_type) = true) then
              buf_delimiter(del_index)  <= dIn;
              del_index                 := 0;
              state_paring              <= WaitLeading;
            end if;

          when others =>
            state_paring  <= WaitLeading;
        end case;

      end if;
    end if;
  end process;


end RTL;
