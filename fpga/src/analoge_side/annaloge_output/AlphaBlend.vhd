
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: AlphaBlend by RD Jordan
-- Created: Early 2023
-- Description: Taken from RMIT final year project
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE-

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity AlphaBlend is
    Port ( 
            clk : in std_logic;
            signal1 : in STD_LOGIC_VECTOR(11 downto 0);
           signal2 : in STD_LOGIC_VECTOR(11 downto 0);
           alpha   : in STD_LOGIC_VECTOR(11 downto 0);
           result  : out STD_LOGIC_VECTOR(11 downto 0));
end AlphaBlend;

architecture Behavioral of AlphaBlend is

  constant c_max : integer := 4095;

  -- signal1 is delayed in step with diff/mult/shift so the final add uses
  -- the same sample that produced shift_result (fixes edge artifacts).
  signal s1_d1 : std_logic_vector(11 downto 0) := (others => '0');
  signal s1_d2 : std_logic_vector(11 downto 0) := (others => '0');
  signal s1_d3 : std_logic_vector(11 downto 0) := (others => '0');
  signal s1_d4 : std_logic_vector(11 downto 0) := (others => '0');

  signal s2_d1 : std_logic_vector(11 downto 0) := (others => '0');
  signal a_d1  : std_logic_vector(11 downto 0) := (others => '0');
  signal a_d2  : std_logic_vector(11 downto 0) := (others => '0');

  signal diff_d2  : signed(12 downto 0) := (others => '0');
  signal mult_d3  : signed(31 downto 0) := (others => '0');
  signal shift_d4 : signed(12 downto 0) := (others => '0');

begin

  pipeline : process (clk)
    variable v_sum : integer;
  begin
    if rising_edge(clk) then
      -- Stage 1: register inputs
      s1_d1 <= signal1;
      s2_d1 <= signal2;
      a_d1  <= alpha;

      -- Stage 2: diff, advance signal1/alpha delay line
      s1_d2 <= s1_d1;
      a_d2  <= a_d1;
      diff_d2 <= resize(signed('0' & s2_d1), 13) - resize(signed('0' & s1_d1), 13);

      -- Stage 3: multiply, advance signal1 delay line
      s1_d3 <= s1_d2;
      mult_d3 <= to_signed(to_integer(unsigned(a_d2)) * to_integer(diff_d2), 32);

      -- Stage 4: scale, advance signal1 delay line
      s1_d4 <= s1_d3;
      shift_d4 <= resize(shift_right(mult_d3, 12), 13);

      -- Stage 5: aligned add with clamp
      v_sum := to_integer(unsigned(s1_d4)) + to_integer(shift_d4);
      if v_sum < 0 then
        result <= (others => '0');
      elsif v_sum > c_max then
        result <= (others => '1');
      else
        result <= std_logic_vector(to_unsigned(v_sum, 12));
      end if;
    end if;
  end process;

end Behavioral;
