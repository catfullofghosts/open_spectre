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
-- Slow counters produce named square-wave rates.
-- Clocked by the dynamic pixel clock; periods assume 720p50 = 74.25 MHz.
-- pulse_generator toggles every toggle_period clocks, so
--   toggle_period = clk_hz / (2 * output_hz)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity slow_counter is
    Port ( clk : in STD_LOGIC;
           enable: in std_logic := '1';    -- enable input
           frame_sync : in STD_LOGIC; -- used to make it so a slow counter cant start mid way across a frame horizontaly, it looks shit
           v_sync : in STD_LOGIC := '0';
           frame_mode : in STD_LOGIC := '0'; -- 0=Hz, 1=frame periods 2/4/8/16/32/64
           div4 : in STD_LOGIC := '0'; -- 1=/4 on both Hz and frame sources
           hz6 : out STD_LOGIC;
           hz3 : out STD_LOGIC;
           hz1_5 : out STD_LOGIC;
           hz_6 : out STD_LOGIC;
           hz_4 : out STD_LOGIC;
           hz_2 : out STD_LOGIC);
end slow_counter;

architecture Behavioral of slow_counter is

      -- 720p50 pixel clock (same 74.25 MHz as 720p60; 1980*750*50).
      -- toggle_period = CLK_HZ / (2 * f_hz)
      constant CLK_HZ : natural := 74_250_000;

      signal hz6i,hz3i,hz1_5i,hz_6i,hz_4i,hz_2i      : std_logic;
      signal frame_sync_d                            : std_logic;
      signal v_sync_d                                : std_logic := '0';
      signal frame_cnt                               : unsigned(7 downto 0) := (others => '0');
      signal div4_ce_cnt                             : unsigned(1 downto 0) := (others => '0');
      signal hz_enable                               : std_logic;

begin

    hz_enable <= enable when div4 = '0' else
                 enable when div4_ce_cnt = "11" else
                 '0';

hz6_counter : entity work.pulse_generator
    generic map(
        toggle_period => CLK_HZ / 12            -- 6 Hz
    )
    port map(
        clk => clk,
        enable => hz_enable,
        output => hz6i
    );
    
hz3_counter : entity work.pulse_generator
    generic map(
        toggle_period => CLK_HZ / 6             -- 3 Hz
    )
    port map(
        clk => clk,
        enable => hz_enable,
        output => hz3i
    );

hz1_5_counter : entity work.pulse_generator
    generic map(
        toggle_period => CLK_HZ / 3             -- 1.5 Hz
    )
    port map(
        clk => clk,
        enable => hz_enable,
        output => hz1_5i
    );

hz_6_counter : entity work.pulse_generator
    generic map(
        toggle_period => CLK_HZ * 5 / 6         -- 0.6 Hz
    )
    port map(
        clk => clk,
        enable => hz_enable,
        output => hz_6i
    );
    
hz_4_counter : entity work.pulse_generator
    generic map(
        toggle_period => CLK_HZ * 5 / 4         -- 0.4 Hz
    )
    port map(
        clk => clk,
        enable => hz_enable,
        output => hz_4i
    );

hz_2_counter : entity work.pulse_generator
    generic map(
        toggle_period => CLK_HZ * 5 / 2         -- 0.2 Hz
    )
    port map(
        clk => clk,
        enable => hz_enable,
        output => hz_2i
    );

process (clk)
begin
    if rising_edge(clk) then -- keeps outputs stable untill the horz sync so that a counter cant have its pixel start mid way along the x of a frame
        if enable = '1' then
            div4_ce_cnt <= div4_ce_cnt + 1;
        end if;

        v_sync_d <= v_sync;
        if v_sync = '1' and v_sync_d = '0' then
            frame_cnt <= frame_cnt + 1;
        end if;

        frame_sync_d <= frame_sync;
        if frame_sync = '1' and frame_sync_d = '0' then
            if frame_mode = '1' then
                if div4 = '1' then
                    hz6    <= frame_cnt(2); -- period 8 frames
                    hz3    <= frame_cnt(3); -- period 16 frames
                    hz1_5  <= frame_cnt(4); -- period 32 frames
                    hz_6   <= frame_cnt(5); -- period 64 frames
                    hz_4   <= frame_cnt(6); -- period 128 frames
                    hz_2   <= frame_cnt(7); -- period 256 frames
                else
                    hz6    <= frame_cnt(0); -- period 2 frames
                    hz3    <= frame_cnt(1); -- period 4 frames
                    hz1_5  <= frame_cnt(2); -- period 8 frames
                    hz_6   <= frame_cnt(3); -- period 16 frames
                    hz_4   <= frame_cnt(4); -- period 32 frames
                    hz_2   <= frame_cnt(5); -- period 64 frames
                end if;
            else
                hz6    <= hz6i;
                hz3    <= hz3i;
                hz1_5  <= hz1_5i;
                hz_6   <= hz_6i;
                hz_4   <= hz_4i;
                hz_2   <= hz_2i;
            end if;
        end if;
    end if;
end process;

end Behavioral;
