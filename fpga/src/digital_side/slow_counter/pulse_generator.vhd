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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pulse_generator is
    generic (
        toggle_period : natural := 156_250_000 -- Number of clock cycles for 0.4 Hz toggle frequency
    );
    port (
        clk : in std_logic;
        enable: in std_logic;    -- enable input
        output : out std_logic
    );
end entity pulse_generator;

architecture Behavioral of pulse_generator is
    signal toggle_counter : unsigned(27 downto 0) := (others => '0'); -- 28 bits for 156_250_000
    signal toggle_output  : std_logic := '0';
    constant toggle_period_c : unsigned(27 downto 0) := to_unsigned(toggle_period - 1, 28);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if enable = '1' then
                if toggle_counter = toggle_period_c then
                    toggle_output <= not toggle_output;
                    toggle_counter <= (others => '0');
                else
                    toggle_counter <= toggle_counter + 1;
                end if;
            end if;
            -- Register output: ensures clean, glitch-free output synchronized to clock
            output <= toggle_output;
        end if;
    end process;
end architecture;

