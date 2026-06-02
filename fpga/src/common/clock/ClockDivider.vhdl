
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: ClockDevider by RD Jordan
-- Created: 20.05.2022 14:34:42
-- Description: -- creates enable signals at clk/2 /4 and/8
-- global clock is 100mhz in, digital counters change at 25mhz or lower
-- slow counters run at 25mhz
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE-



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity ClockDivider is
    Port ( clk_in : in STD_LOGIC;
           reset : in STD_LOGIC;
           enable_out_2 : out STD_LOGIC;
           enable_out_4 : out STD_LOGIC;
           enable_out_8 : out STD_LOGIC);
end ClockDivider;

architecture Behavioral of ClockDivider is
    signal shift_reg : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal rising_edge_detected : STD_LOGIC := '0';

begin
    process (clk_in, reset)
    begin
        if reset = '1' then
            shift_reg <= "000";
            rising_edge_detected <= '0';
        elsif rising_edge(clk_in) then
            shift_reg <= shift_reg(1 downto 0) & clk_in;
            rising_edge_detected <= '1';
        else
            rising_edge_detected <= '0';
        end if;
    end process;

    enable_out_2 <= rising_edge_detected and (shift_reg = "001");
    enable_out_4 <= rising_edge_detected and (shift_reg = "010");
    enable_out_8 <= rising_edge_detected and (shift_reg = "100");

end Behavioral;
