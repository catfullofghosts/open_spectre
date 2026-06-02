--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|      
-- Create Date: 2023
-- Created by: Rob D Jordan
-- Notes: 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity SinWaveGenerator_TB is
end SinWaveGenerator_TB;

architecture Behavioral of SinWaveGenerator_TB is
    signal clk, reset, speed : STD_LOGIC;
    signal sync_sel :  STD_LOGIC_VECTOR(1 downto 0);
    signal sync_plus :  STD_LOGIC := '0';
    signal sync_minus :  STD_LOGIC := '0';
    signal freq :  STD_LOGIC_VECTOR(13 downto 0);
    signal wave_out : STD_LOGIC_VECTOR(11 downto 0);
    signal square_out : STD_LOGIC;
    signal dist_level      : STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); -- distortion wave level
    signal pwm_duty        : STD_LOGIC_VECTOR(8 downto 0) := "010110100"; -- PWM duty cycle (0-360, default 180 for 50%)
    signal wave_sel        : STD_LOGIC_VECTOR(1 downto 0) := "00"; -- Waveform select: 00=sine, 01=ramp up, 10=ramp down, 11=triangle
begin
    -- Instantiate the SinWaveGenerator module
    UUT: entity work.SinWaveGenerator
        Port map (
            clk => clk,
            reset => reset,
            speed => speed,
            freq => freq,
            sync_sel => sync_sel,
            sync_plus => sync_plus,
            sync_minus => sync_minus,
            dist_level => dist_level,
            pwm_duty => pwm_duty,
            wave_sel => wave_sel,
            wave_out => wave_out,
            square_out => square_out
        );

    -- Clock process
    process
    begin
        clk <= '0';
        wait for 5 ns; -- Adjust this time period based on your clock frequency
        clk <= '1';
        wait for 5 ns; -- Adjust this time period based on your clock frequency
    end process;

    -- Stimulus process
    process
    begin
        reset <= '1';
        speed <= '0';
        freq <= "00000000000000";
        sync_plus <= '0';
        sync_minus <= '0';
        sync_sel <= "00";
        dist_level <= (others => '0');
        pwm_duty <= "010110100"; -- 180 (50% duty cycle)
        wave_sel <= "00"; -- Start with sine wave
        wait for 10 ns;

        reset <= '0';
        freq <= "00000000000101"; -- Set the frequency to your desired value
        
        -- Test sine wave
        wave_sel <= "00";
        wait for 2000 ns;
        
        -- Test ramp up
        wave_sel <= "01";
        wait for 2000 ns;
        
        -- Test ramp down
        wave_sel <= "10";
        wait for 2000 ns;
        
        -- Test triangle wave
        wave_sel <= "11";
        wait for 2000 ns;
        
        -- Test with distortion
        wave_sel <= "00";
        dist_level <= "10000000"; -- 50% distortion
        wait for 2000 ns;
        
        -- Test PWM duty cycle variation
        pwm_duty <= "001011010"; -- 90 (25% duty cycle)
        wait for 2000 ns;
        
        pwm_duty <= "011001100"; -- 270 (75% duty cycle)
        wait for 2000 ns;
        
        -- Test speed mode
        speed <= '1';
        wait for 2000 ns;
        
        wait;
    end process;

end Behavioral;
