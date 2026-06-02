
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity AlphaBlend is
    Port ( 
            clk : in std_logic;
            signal1 : in STD_LOGIC_VECTOR(11 downto 0);
           signal2 : in STD_LOGIC_VECTOR(11 downto 0);
           alpha   : in STD_LOGIC_VECTOR(11 downto 0);
           result  : out STD_LOGIC_VECTOR(11 downto 0));
end AlphaBlend;

architecture Behavioral of AlphaBlend is
    signal signal1_int, signal2_int, alpha_int : integer range 0 to 4095;
    signal diff          : integer range -4095 to 4095;
    signal mult_result   : integer range -4095*4095 to 4095*4095;
    signal shift_result  : integer range -4095 to 4095;
    signal result_int    : integer range 0 to 4095;

    signal result_reg    : std_logic_vector(11 downto 0);
begin

    process(clk)
    begin
        if rising_edge(clk) then
            -- Stage 1: Convert inputs
            signal1_int <= to_integer(unsigned(signal1));
            signal2_int <= to_integer(unsigned(signal2));
            alpha_int   <= to_integer(unsigned(alpha));
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            -- Stage 2: Subtract
            diff <= signal2_int - signal1_int;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            -- Stage 3: Multiply
            mult_result <= alpha_int * diff;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            -- Stage 4: Shift (divide)
            shift_result <= mult_result / 4096; -- equivalent to mult_result srl 12
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            -- Stage 5: Add and convert to output
            result_int <= signal1_int + shift_result;
            result     <= std_logic_vector(to_unsigned(result_int, 12));
        end if;
    end process;
end Behavioral;
