library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity moving_average is
  generic (
    G_NBIT      : integer := 10;  -- bit width
    G_MAX_DELTA : integer := 1    -- maximum change per clock cycle
  );
  port (
    i_clk        : in  std_logic;
    i_rstb       : in  std_logic;
    i_sync_reset : in  std_logic;

    -- input
    i_data_ena   : in  std_logic;
    i_data       : in  std_logic_vector(G_NBIT-1 downto 0);

    -- output
    o_data_valid : out std_logic;
    o_data       : out std_logic_vector(G_NBIT-1 downto 0)
  );
end entity;

architecture rtl of moving_average is
  signal r_out        : unsigned(G_NBIT-1 downto 0) := (others => '0');
  signal r_data_valid : std_logic := '0';
  constant c_max_delta : unsigned(G_NBIT-1 downto 0) := to_unsigned(G_MAX_DELTA, G_NBIT);
begin

  process(i_clk, i_rstb)
    variable v_input : unsigned(G_NBIT-1 downto 0);
    variable v_diff  : unsigned(G_NBIT-1 downto 0);
  begin
    if i_rstb = '1' then
      r_out        <= (others => '0');
      r_data_valid <= '0';
      o_data       <= (others => '0');
      o_data_valid <= '0';

    elsif rising_edge(i_clk) then
      r_data_valid <= i_data_ena;
      o_data_valid <= r_data_valid;

      if i_sync_reset = '1' then
        r_out <= (others => '0');

      elsif i_data_ena = '1' then
        v_input := unsigned(i_data);

        if v_input > r_out then
          v_diff := v_input - r_out;
          if v_diff > c_max_delta then
            r_out <= r_out + c_max_delta;
          else
            r_out <= v_input;
          end if;

        elsif v_input < r_out then
          v_diff := r_out - v_input;
          if v_diff > c_max_delta then
            r_out <= r_out - c_max_delta;
          else
            r_out <= v_input;
          end if;

        else
          r_out <= v_input;
        end if;
      end if;

      o_data <= std_logic_vector(r_out);
    end if;
  end process;

end rtl;
