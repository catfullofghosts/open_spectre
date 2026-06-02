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
use IEEE.NUMERIC_STD.ALL;

entity monstable_4_tb is
end monstable_4_tb;

architecture behavior of monstable_4_tb is
    signal input : std_logic := '0';
    signal clk : std_logic := '0';
    signal output : STD_LOGIC_VECTOR (3 downto 0);

begin
    dut: entity work.monstable_4
        port map (
            input => input,
            clk => clk,
            output => output
        );

    -- Clock generation process
    clk_gen: process
    begin
        wait for 5 ns;
        clk <= not clk;
        if now > 500 ns then
            wait;
        end if;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        -- Wait for 100 ns to let the DUT stabilize
        wait for 100 ns;
        
        input <= '1';
        wait for 10 ns;
        assert output = "0000" report "Unexpected output value after input transition to '1'";

        wait for 10 ns;
        input <= '0';
        wait for 10 ns;
        assert output = "1010" report "Unexpected output value after input transition to '0'";

        wait;
    end process;
end behavior;
