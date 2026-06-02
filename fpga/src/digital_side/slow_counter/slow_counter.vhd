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
-- Slow counter designed for 100mhz clk

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity slow_counter is
    Port ( clk : in STD_LOGIC;
           enable: in std_logic := '1';    -- enable input
           hz6 : out STD_LOGIC;
           hz3 : out STD_LOGIC;
           hz1_5 : out STD_LOGIC;
           hz_6 : out STD_LOGIC;
           hz_4 : out STD_LOGIC;
           hz_2 : out STD_LOGIC);
end slow_counter;

architecture Behavioral of slow_counter is

begin

hz6_counter : entity work.pulse_generator
    generic map(
        toggle_period => 1_041_666  -- 4_166_666 / 4
    )
    port map(
        clk => clk,
        enable => enable,
        output => hz6
    );
    
hz3_counter : entity work.pulse_generator
    generic map(
        toggle_period => 2_083_333  -- 8_333_333 / 4
    )
    port map(
        clk => clk,
        enable => enable,
        output => hz3
    );

hz1_5_counter : entity work.pulse_generator
    generic map(
        toggle_period => 4_166_666  -- 16_666_666 / 4
    )
    port map(
        clk => clk,
        enable => enable,
        output => hz1_5
    );

hz_6_counter : entity work.pulse_generator
    generic map(
        toggle_period => 10_416_666  -- 41_666_666 / 4
    )
    port map(
        clk => clk,
        enable => enable,
        output => hz_6
    );
    
hz_4_counter : entity work.pulse_generator
    generic map(
        toggle_period => 15_625_000  -- 62_500_000 / 4
    )
    port map(
        clk => clk,
        enable => enable,
        output => hz_4
    );

hz_2_counter : entity work.pulse_generator
    generic map(
        toggle_period => 31_250_000  -- 125_000_000 / 4
    )
    port map(
        clk => clk,
        enable => enable,
        output => hz_2
    );

end Behavioral;
