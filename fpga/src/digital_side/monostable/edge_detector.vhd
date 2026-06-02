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
-- edge detector

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity edge_detector is
    port (
        -- input
        x: in std_logic;  -- input signal
        clk : in std_logic;
        rst : in std_logic := '0';  -- optional reset (active high)

        -- outputs
        rising_edge_O: out std_logic;  -- rising edge detected (registered)
        falling_edge_O: out std_logic  -- falling edge detected (registered)
    );
end entity;

architecture behavioral of edge_detector is
    signal x_reg: std_logic := '0';  -- flip-flop for storing the previous value of x
    signal rising_edge_int: std_logic := '0';  -- internal rising edge signal
    signal falling_edge_int: std_logic := '0';  -- internal falling edge signal
begin
    -- Edge detection process: register the previous value and detect edges
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                x_reg <= '0';
                rising_edge_int <= '0';
                falling_edge_int <= '0';
            else
                -- Store previous value
                x_reg <= x;
                
                -- Detect rising edge (registered to avoid glitches)
                if x_reg = '0' and x = '1' then
                    rising_edge_int <= '1';
                else
                    rising_edge_int <= '0';
                end if;
                
                -- Detect falling edge (registered to avoid glitches)
                if x_reg = '1' and x = '0' then
                    falling_edge_int <= '1';
                else
                    falling_edge_int <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- Registered outputs (glitch-free)
    rising_edge_O <= rising_edge_int;
    falling_edge_O <= falling_edge_int;
        
end architecture;
