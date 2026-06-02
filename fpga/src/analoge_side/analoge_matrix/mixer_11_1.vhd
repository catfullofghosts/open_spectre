library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mixer_11_1 is
  port (
    clk     : in  std_logic;
    input_0 : in  std_logic_vector(11 downto 0);
    input_1 : in  std_logic_vector(11 downto 0);
    input_2 : in  std_logic_vector(11 downto 0);
    input_3 : in  std_logic_vector(11 downto 0);
    input_4 : in  std_logic_vector(11 downto 0);
    input_5 : in  std_logic_vector(11 downto 0);
    input_6 : in  std_logic_vector(11 downto 0);
    input_7 : in  std_logic_vector(11 downto 0);
    input_8 : in  std_logic_vector(11 downto 0);
    input_9 : in  std_logic_vector(11 downto 0);
    input_10: in  std_logic_vector(11 downto 0);
    input_11: in  std_logic_vector(11 downto 0);
    input_12: in  std_logic_vector(11 downto 0) := (others => '0');
    input_13: in  std_logic_vector(11 downto 0) := (others => '0');
    input_14: in  std_logic_vector(11 downto 0) := (others => '0');
    input_15: in  std_logic_vector(11 downto 0) := (others => '0');
    mutes   : in  std_logic_vector(15 downto 0);  -- '0' = unmuted, '1' = muted

    mixed_out : out std_logic_vector(11 downto 0)
  );
end entity;

architecture unpipelined of mixer_11_1 is
  type unsigned_11_arr    is array (natural range <>) of unsigned(11 downto 0);
  signal a         : unsigned_11_arr(15 downto 0);
  signal total_sum : unsigned(15 downto 0);
  signal mixed_reg : std_logic_vector(11 downto 0);
begin

  mixed_out <= mixed_reg;

  process(clk)
    variable partial_sum : unsigned(15 downto 0);
  begin
    if rising_edge(clk) then

      -- Apply mutes
      for i in 0 to 15 loop
        if mutes(i) = '1' then
          a(i) <= (others => '0');
        else
          a(i) <= unsigned(input_0) when i = 0 else
                  unsigned(input_1) when i = 1 else
                  unsigned(input_2) when i = 2 else
                  unsigned(input_3) when i = 3 else
                  unsigned(input_4) when i = 4 else
                  unsigned(input_5) when i = 5 else
                  unsigned(input_6) when i = 6 else
                  unsigned(input_7) when i = 7 else
                  unsigned(input_8) when i = 8 else
                  unsigned(input_9) when i = 9 else
                  unsigned(input_10) when i = 10 else
                  unsigned(input_11) when i = 11 else
                  unsigned(input_12) when i = 12 else
                  unsigned(input_13) when i = 13 else
                  unsigned(input_14) when i = 14 else
                  unsigned(input_15);  -- i = 15
        end if;
      end loop;

      -- Total sum of all inputs
      partial_sum := (others => '0');
      for i in 0 to 15 loop
        partial_sum := partial_sum + resize(a(i), 16);
      end loop;

      total_sum <= partial_sum;

      -- Saturation to 12 bits
      if total_sum > to_unsigned(4095, 16) then
        mixed_reg <= std_logic_vector(to_unsigned(4095, 12));
      else
        mixed_reg <= std_logic_vector(total_sum(11 downto 0));
      end if;

    end if;
  end process;

end architecture;
