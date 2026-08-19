--VHDL2008
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 12-bit signed analog mixer column. Unmuted inputs are two's-complement;
-- muted inputs contribute 0 (centre). Sum is clamped to [-2048, 2047].
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
  type signed_12_arr    is array (natural range <>) of signed(11 downto 0);
  signal a         : signed_12_arr(15 downto 0) := (others => (others => '0'));
  signal total_sum : signed(15 downto 0) := (others => '0');
  signal mixed_reg : std_logic_vector(11 downto 0) := (others => '0');

  constant C_SIGNED_MAX : signed(15 downto 0) := to_signed(2047, 16);
  constant C_SIGNED_MIN : signed(15 downto 0) := to_signed(-2048, 16);
begin

  mixed_out <= mixed_reg;

  process(clk)
    variable partial_sum : signed(15 downto 0);
  begin
    if rising_edge(clk) then

      -- Apply mutes
      for i in 0 to 15 loop
        if mutes(i) = '1' then
          a(i) <= (others => '0');
        else
          a(i) <= signed(input_0) when i = 0 else
                  signed(input_1) when i = 1 else
                  signed(input_2) when i = 2 else
                  signed(input_3) when i = 3 else
                  signed(input_4) when i = 4 else
                  signed(input_5) when i = 5 else
                  signed(input_6) when i = 6 else
                  signed(input_7) when i = 7 else
                  signed(input_8) when i = 8 else
                  signed(input_9) when i = 9 else
                  signed(input_10) when i = 10 else
                  signed(input_11) when i = 11 else
                  signed(input_12) when i = 12 else
                  signed(input_13) when i = 13 else
                  signed(input_14) when i = 14 else
                  signed(input_15);  -- i = 15
        end if;
      end loop;

      -- Total sum of all inputs
      partial_sum := (others => '0');
      for i in 0 to 15 loop
        partial_sum := partial_sum + resize(a(i), 16);
      end loop;

      total_sum <= partial_sum;

      -- Clip to 12-bit signed range [-2048, 2047]
      if total_sum > C_SIGNED_MAX then
        mixed_reg <= std_logic_vector(to_signed(2047, 12));
      elsif total_sum < C_SIGNED_MIN then
        mixed_reg <= std_logic_vector(to_signed(-2048, 12));
      else
        mixed_reg <= std_logic_vector(total_sum(11 downto 0));
      end if;

    end if;
  end process;

end architecture;
