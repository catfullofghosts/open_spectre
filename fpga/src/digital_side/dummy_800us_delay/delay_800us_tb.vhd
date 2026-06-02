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
-- Notes: TB for file downloaded from Nandland for 800us delay of digital signal



library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity delay_800us_tb is
end entity;

architecture behavioral of delay_800us_tb is
    signal clk: std_logic := '0';
    signal input: std_logic := '0';
    signal output: std_logic;
    
    signal input_bus:  std_logic_vector(1 downto 0);
    signal output_bus:  std_logic_vector(1 downto 0);
    
begin
    -- Create a clock signal with a 50% duty cycle
    clk_process: process
    begin
        wait for 10 ns;
        clk <= not clk;
        if now > 200000 ns then
            wait;
        end if;
    end process;

    -- Instantiate the design under test
    dut: entity work.delay_800us
        generic map (
        g_DEPTH => 5
        )
        port map (
            i_clk => clk,
            i_rst_sync => '0',
            i_wr_en => '1',
            i_rd_en => '1',
            i_wr_data => input_bus,
            o_rd_data => output_bus
        );
        
     input_bus <= '0' & input;
     output <= output_bus(0);

    -- Test the delay by toggling the input signal and checking the output
    test_process: process
    begin
        -- Wait for the clock to stabilize
        wait for 50 ns;

        -- Assert that the output is 'Z' (undetermined) initially
        assert output = 'Z' report "Output is not 'Z' initially" severity note;

        -- Toggle the input signal and wait for one clock cycle
        input <= not input;
        wait for 10 ns;

        -- Assert that the output has not changed
        assert output = 'Z' report "Output changed before delay expired" severity note;

        -- Wait for the delay to expire
        wait for 200 us;

        -- Assert that the output has changed to the same value as the input
        assert output = input report "Output does not match input after delay expired" severity note;

        -- Toggle the input signal and wait for one clock cycle
        input <= not input;
        wait for 10 ns;

        -- Assert that the output has not changed
        assert output = input report "Output changed before delay expired" severity note;

        -- Wait for the delay to expire
        wait for 200 us;

        -- Assert that the output has changed to the same value as the input
        assert output = input report "Output does not match input after delay expired" severity note;

        wait;
    end process;
end architecture;
