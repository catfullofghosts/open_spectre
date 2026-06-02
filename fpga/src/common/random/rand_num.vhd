-- ======================================================================================
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                                                                                   
-- Module      : rand_num
-- Description : 6-bit pseudo-random output based on a 32-bit internal LFSR
-- Author      : Originally Meher Krishna Patel, updated by RD Jordan
-- License     : MIT (open source)
-- GitHub      : https://github.com/cfoge/OPEN_SPECTRE-
-- ======================================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rand_num is
    port (
        clk    : in  std_logic;
        en     : in  std_logic;
        reset  : in  std_logic;
        q      : out std_logic_vector(5 downto 0)  -- 6-bit pseudo-random output
    );
end rand_num;

architecture rtl of rand_num is
    constant N : integer := 32;
    signal r_reg : std_logic_vector(N-1 downto 0) := (others => '0');
    signal r_next : std_logic_vector(N-1 downto 0);
    signal feedback : std_logic;
begin

    -- LFSR process
    process(clk, reset)
    begin
        if reset = '1' then
            -- Initial non-zero seed
            r_reg <= x"DEADBEEF";  -- or any other non-zero seed
        elsif rising_edge(clk) then
            if en = '1' then
                r_reg <= r_next;
            end if;
        end if;
    end process;

    -- 32-bit maximal length LFSR with taps at: x^32 + x^22 + x^2 + x^1 + 1
    feedback <= r_reg(31) xor r_reg(21) xor r_reg(1) xor r_reg(0);
    r_next <= r_reg(N-2 downto 0) & feedback;

    -- Output only the lowest 6 bits
    q <= r_reg(5 downto 0);

end rtl;
