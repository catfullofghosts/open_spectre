--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: 
-- Created: Early 2023
-- Description: 
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE-

-- created by   :   RD Jordan

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity window_comparator is
	generic ( LOWEST_COMP : boolean  := False
    		 );
    Port ( clk : in std_logic;  -- clock for registered output
           input : in  STD_LOGIC_VECTOR(7 downto 0);
           lower : in  STD_LOGIC_VECTOR(7 downto 0);
           upper : in  STD_LOGIC_VECTOR(7 downto 0);
           output : out  STD_LOGIC);
end window_comparator;

architecture Behavioral of window_comparator is
    signal output_int : std_logic;  -- internal combinational output
begin
  -- Combinational window comparison logic
  Not_lowest_comp : if not LOWEST_COMP generate
    output_int <= '0' when (input <= lower) or (input > upper) else '1';
    end generate;
    
  is_lowest_comp : if LOWEST_COMP generate
    output_int <= '0' when (input < lower) or (input > upper) else '1';
    end generate;
    
  -- Register output for better timing in clocked designs
  process(clk)
  begin
    if rising_edge(clk) then
        output <= output_int;
    end if;
  end process;
    
end Behavioral;
