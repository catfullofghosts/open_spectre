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
-- Create Date: 06.09.2023 09:43:23
-- Module Name: xpoint_or - Behavioral

-- Notes: this is going to be a major issue with timing right? might need to pipeline the input to avoid huge routing times from one side of the matrix to the other

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_misc.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity xpoint_or is
    Port ( input : in STD_LOGIC_VECTOR (63 downto 0) := (others => '0');
           mask : in STD_LOGIC_VECTOR (63 downto 0);
           output : out STD_LOGIC);
end xpoint_or;

architecture Behavioral of xpoint_or is
    
    signal internal_bus : std_logic_vector (63 downto 0) := (others => '0');
    
begin
    internal_bus <= input and mask;
    
--    process(input,mask,internal_bus) -- get rid of this and use the registers to program the pullup that way we can have classic mode with the pullups and non classic mode without
--    begin
--        if or_reduce(mask) = '0' then --pullup behavior
--            output <= '1';
--        else
            output <= or_reduce(internal_bus);
--        end if;
--    end process;
    
 

end Behavioral;