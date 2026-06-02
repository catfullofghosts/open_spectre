
-- pipelined devider, delay is 20clocks aporx

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipelined_divider is
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    valid_in     : in  std_logic;
    num_in       : in  unsigned(15 downto 0);
    den_in       : in  unsigned(15 downto 0);
    valid_out    : out std_logic;
    quotient_out : out unsigned(15 downto 0);
    remainder_out: out unsigned(15 downto 0);
    s_delayed    : out unsigned(15 downto 0)
  );
end entity;

architecture rtl of pipelined_divider is
  type stage_t is record
    rema  : unsigned(16 downto 0); -- 17 bits
    quo  : unsigned(15 downto 0); -- 16 bits
    den  : unsigned(15 downto 0); -- 16 bits
    vld  : std_logic;
    s    : unsigned(15 downto 0);
  end record;

  type stage_array_t is array (0 to 16) of stage_t;

  signal stage : stage_array_t;

begin

  ------------------------------------------------------------------------------
  -- Stage 0: Load inputs
  ------------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        stage(0).rema <= (others => '0');
        stage(0).quo <= (others => '0');
        stage(0).den <= (others => '0');
        stage(0).vld <= '0';
        stage(0).s <= (others => '0');
      else
        stage(0).rema <= (others => '0');
        stage(0).quo <= num_in;
        stage(0).den <= den_in;
        stage(0).vld <= valid_in;
        stage(0).s <= num_in;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Generate 16 pipeline stages
  ------------------------------------------------------------------------------
  gen_stages : for i in 0 to 15 generate
  begin
    process(clk)
      variable rem_shift : unsigned(16 downto 0);
      variable den_ext   : unsigned(16 downto 0);
      variable quo_next  : unsigned(15 downto 0);
    begin
      if rising_edge(clk) then
        if rst = '1' then
          stage(i+1).rema <= (others => '0');
          stage(i+1).quo <= (others => '0');
          stage(i+1).den <= (others => '0');
          stage(i+1).vld <= '0';
          stage(i+1).s <= (others => '0');

        else
          if stage(i).vld = '1' then
            rem_shift := stage(i).rema(15 downto 0) & stage(i).quo(15-i); -- bring down next bit
            den_ext   := ('0' & stage(i).den);
            quo_next  := stage(i).quo;
            if rem_shift >= den_ext then
              stage(i+1).rema <= rem_shift - den_ext;
              quo_next(15-i) := '1';
            else
              stage(i+1).rema <= rem_shift;
              quo_next(15-i) := '0';
            end if;
            stage(i+1).quo <= quo_next;
            stage(i+1).den <= stage(i).den;
            stage(i+1).vld <= '1';
            stage(i+1).s <= stage(i).s;
          else
            stage(i+1).rema <= (others => '0');
            stage(i+1).quo <= (others => '0');
            stage(i+1).den <= (others => '0');
            stage(i+1).vld <= '0';
            stage(i+1).s <= (others => '0');
          end if;
        end if;
      end if;
    end process;
  end generate;

  ------------------------------------------------------------------------------
  -- Outputs from final stage
  ------------------------------------------------------------------------------
  quotient_out  <= stage(16).quo;
  remainder_out <= stage(16).rema(15 downto 0);
  valid_out     <= stage(16).vld;
  s_delayed     <= stage(16).s;

end architecture;
