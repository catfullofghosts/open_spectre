--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|      
-- Create Date: 2023
-- Created by: Rob D Jordan
-- Notes: Mix unsigned unipolar A with signed bipolar B, clamp to [0, 4095].
--        14-bit acc: 4095 + 2047 = 6142, and 0 + (-2048) = -2048, both fit.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Adder_12bit_NoOverflow is
  Port ( 
    A : in STD_LOGIC_VECTOR(11 downto 0); -- unsigned unipolar (e.g. digital video)
    B : in STD_LOGIC_VECTOR(11 downto 0); -- signed bipolar (e.g. analog matrix)
    Sum : out STD_LOGIC_VECTOR(11 downto 0);
    Overflow : out STD_LOGIC
  );
end Adder_12bit_NoOverflow;

architecture Behavioral of Adder_12bit_NoOverflow is
  signal a_ext  : signed(13 downto 0);
  signal b_ext  : signed(13 downto 0);
  signal result : signed(13 downto 0);
begin
  -- Zero-extend A so values >= 2048 stay positive (Y << 4 often sets bit 11).
  a_ext  <= signed(resize(unsigned(A), 14));
  b_ext  <= resize(signed(B), 14);
  result <= a_ext + b_ext;

  process (result)
  begin
    if result < 0 then
      Sum      <= (others => '0');
      Overflow <= '1';
    elsif result > 4095 then
      Sum      <= (others => '1');
      Overflow <= '1';
    else
      Sum      <= std_logic_vector(result(11 downto 0));
      Overflow <= '0';
    end if;
  end process;

end Behavioral;
