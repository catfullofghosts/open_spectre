
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: shift_sipo by RD Jordan
-- Created: Early 2023
-- Description: 
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE-

library ieee;

use ieee.std_logic_1164.all;

entity shift_sipo is

  port (
    Clock,shift, SinA, SinB, rst : in std_logic;

    Pout : out std_logic_vector(7 downto 0));

end shift_sipo;

architecture exam of shift_sipo is

  signal temp : std_logic_vector(7 downto 0) := "10000110";
  signal Sin  : std_logic;

begin

  process (Clock)

  begin

    if (Clock'event and Clock = '1') then
    Sin <= SinA NAND SinB;
    
    if rst = '1' then
        temp <= "10000110";
    else
        if shift = '1' then
            temp <= temp(6 downto 0) & Sin;
        end if;

    end if;

    end if;

  end process;

  Pout <= temp;

end exam;
