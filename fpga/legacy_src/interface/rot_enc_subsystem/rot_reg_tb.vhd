--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Created: 2024 by RD JOrdan
-- Description: Rotery encoder TB
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity rot_reg_tb is
end rot_reg_tb;

architecture sim of rot_reg_tb is
  constant CLK_PERIOD : time := 10 ns;  -- Clock period
  
  signal sw_a, sw_b, rst, clk, step_size : std_logic;
  signal input_addr : std_logic_vector(4 - 1 downto 0);
  signal output_data : std_logic_vector(12 - 1 downto 0);
  
begin

  -- Instantiate the Unit Under Test (UUT)
  uut : entity work.rot_reg
    port map (
      sw_a => sw_a,
      sw_b => sw_b,
      step_size => step_size,
      input_addr => input_addr,
      rst => rst,
      clk => clk
    );

  -- Clock process
  clk_process: process
  begin
    clk <= '0';
    wait for CLK_PERIOD / 2;
    clk <= '1';
    wait for CLK_PERIOD / 2;
  end process;

  -- Stimulus process
  stimulus_process: process
  begin
    -- Initialize inputs
    sw_a <= '0';
    sw_b <= '0';
    rst <= '1';

    
    wait for CLK_PERIOD * 5; -- Wait for some time with reset
    
    rst <= '0'; -- De-assert reset
    wait for CLK_PERIOD * 5; -- Wait for some time after reset
    
    -- TEST UP THEN DOWN:
    step_size <= '0';
    input_addr <= "0001";
    -- ADD mode

    sw_b <= '1'; -- Set input A
    sw_a <= '0'; -- Set input B
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '1'; -- Reset input A
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '0'; -- Reset input A
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '0'; -- Reset input A
    
            sw_b <= '1'; -- Set input A
    sw_a <= '0'; -- Set input B
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '1'; -- Reset input A
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '0'; -- Reset input A
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '0'; -- Reset input A
    
    wait for CLK_PERIOD * 8; -- Wait for a few clock cycles
    
--    -- Scenario 1: SUB mode

--    sw_a <= '1'; -- Set input A
--    sw_b <= '0'; -- Set input B
--    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
--    sw_b <= '1'; -- Reset input A
--    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
--    sw_a <= '0'; -- Reset input A
--        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
--    sw_b <= '0'; -- Reset input A
--        sw_a <= '1'; -- Set input A
--    sw_b <= '0'; -- Set input B
--    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
--    sw_b <= '1'; -- Reset input A
--    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
--    sw_a <= '0'; -- Reset input A
--        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
--    sw_b <= '0'; -- Reset input A
    
    
--        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
--    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
--    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
--    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles

-- TEST UP THEN DOWN:
    step_size <= '0';
    input_addr <= "0000";
    -- ADD mode

    sw_b <= '1'; -- Set input A
    sw_a <= '0'; -- Set input B
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '1'; -- Reset input A
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '0'; -- Reset input A
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '0'; -- Reset input A
    
            sw_b <= '1'; -- Set input A
    sw_a <= '0'; -- Set input B
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '1'; -- Reset input A
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '0'; -- Reset input A
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '0'; -- Reset input A
    
    wait for CLK_PERIOD * 8; -- Wait for a few clock cycles
    
    -- Scenario 1: SUB mode

    sw_a <= '1'; -- Set input A
    sw_b <= '0'; -- Set input B
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '1'; -- Reset input A
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '0'; -- Reset input A
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '0'; -- Reset input A
        sw_a <= '1'; -- Set input A
    sw_b <= '0'; -- Set input B
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '1'; -- Reset input A
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '0'; -- Reset input A
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '0'; -- Reset input A
    
    
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles

-- TEST UP THEN DOWN:
    step_size <= '1';
    input_addr <= "0010";
    -- ADD mode

    sw_b <= '1'; -- Set input A
    sw_a <= '0'; -- Set input B
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '1'; -- Reset input A
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '0'; -- Reset input A
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '0'; -- Reset input A
    
            sw_b <= '1'; -- Set input A
    sw_a <= '0'; -- Set input B
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '1'; -- Reset input A
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '0'; -- Reset input A
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '0'; -- Reset input A
    
    wait for CLK_PERIOD * 8; -- Wait for a few clock cycles
    
    -- Scenario 1: SUB mode

    sw_a <= '1'; -- Set input A
    sw_b <= '0'; -- Set input B
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '1'; -- Reset input A
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '0'; -- Reset input A
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '0'; -- Reset input A
        sw_a <= '1'; -- Set input A
    sw_b <= '0'; -- Set input B
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '1'; -- Reset input A
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_a <= '0'; -- Reset input A
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    sw_b <= '0'; -- Reset input A
    
    
        wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles
    wait for CLK_PERIOD * 2; -- Wait for a few clock cycles



    
    wait;
  end process;

  -- Output process
  output_process: process
  begin
    wait for CLK_PERIOD * 2; -- Wait for stable outputs
    -- Print output data for observation
--    report "Output data: " & to_string(output_data);
    wait;
  end process;

end sim;
