----------------------------------------------------------------------------------
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
--
-- Module Name: compare_7 - Behavioral
-- Description: 
-- 
-- Dependencies: 
-- 
-- Additional Comments:

library IEEE;
use IEEE.std_logic_signed.all;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity compare_7 is
    Port ( clk    : in std_logic ;
           luma_i : in STD_LOGIC_VECTOR (7 downto 0);
           output : out STD_LOGIC_VECTOR (6 downto 0);
           span : in STD_LOGIC_VECTOR (7 downto 0));
end compare_7;

architecture Behavioral of compare_7 is
signal span_div,span_1,span_2,span_3,span_4:  STD_LOGIC_VECTOR (7 downto 0); --create signals to hold comparitor values
signal wc_out : std_logic_vector (5 downto 0);
signal xor_a : std_logic_vector (6 downto 0);
signal xor_b : std_logic_vector (6 downto 0);
signal xor_output : std_logic_vector (6 downto 0); -- registered xor output

constant comp_num : integer  := 6;

begin
    
    

    wc_5: entity work.window_comparator
        port map (clk => clk, input => luma_i, lower => span_4, upper => x"ff", output => wc_out(5));
    wc_4: entity work.window_comparator
        port map (clk => clk, input => luma_i, lower => span_3, upper => span_4, output => wc_out(4));
    wc_3: entity work.window_comparator
        port map (clk => clk, input => luma_i, lower => span_2, upper => span_3, output => wc_out(3));
    wc_2: entity work.window_comparator
        port map (clk => clk, input => luma_i, lower => span_1, upper => span_2, output => wc_out(2));
    wc_1: entity work.window_comparator
        port map (clk => clk, input => luma_i, lower => span_div, upper => span_1, output => wc_out(1));
    wc_0: entity work.window_comparator
--        generic map(LOWEST_COMP => true)
        port map (clk => clk, input => luma_i, lower => x"00", upper => span_div, output => wc_out(0)); -- lewer is 1 so that 0 always sets window comp 1
        
        
    xor_n: entity work.xor_n
        generic map (n => 7) port map (a => xor_a, b => xor_b, y => xor_output);

process (clk)   --update comparitor values and register output
    begin
     if rising_edge(clk) then
        span_div <= std_logic_vector(to_unsigned(to_integer(unsigned(span)) / comp_num,8)) ;
        span_1 <= span_div + span_div;
        span_2 <= span_div + span_div + span_div;
        span_3 <= span_div + span_div + span_div + span_div;
        span_4 <= span_div + span_div + span_div + span_div + span_div;

        xor_a <= '0'       & wc_out(5) & wc_out(4) & wc_out(3) & wc_out(2) & wc_out(1) & wc_out(0);
        xor_b <= wc_out(5) & wc_out(4) & wc_out(3) & wc_out(2) & wc_out(1) & wc_out(0) & '1';
        
        -- Register xor output to fix timing path (all signals now properly registered)
        output <= xor_output;
    end if;
    end process;


end Behavioral;
