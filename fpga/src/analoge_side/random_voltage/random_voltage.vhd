
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: random_voltage by RD Jordan
-- Created: Early 2023
-- Description: 
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE-
library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity random_voltage is

  port (
    Clock, recycle, rst : in std_logic;
    noise_freq : in std_logic_vector(13 downto 0);
    slew_in : in std_logic_vector(2 downto 0);
    noise_1 : out std_logic_vector(9 downto 0);
    noise_2 : out std_logic_vector(9 downto 0);
    extra_in   : in std_logic := '0';
    slowdown_sel : in std_logic_vector(1 downto 0) := "00"
    );

end random_voltage;

architecture Behavioral of random_voltage is

  signal spio_out_1, spio_out_2  : std_logic_vector(7 downto 0);
  signal count : std_logic_vector(13 downto 0);
  signal noise_1_to_slew, noise_2_to_slew, slew_out_1, slew_out_2 : std_logic_vector(9 downto 0);
  signal Sin,x , cnt_rst, cnt_match, sipo_clk  : std_logic := '0';
  signal mux_in, mux_in_des : std_logic_vector(7 downto 0) := "01100011"; -- only inputs 0,1,5,6 are set to gnd so i set the rest to 1 i guess
  signal sipo_dac_1, sipo_dac_2 : std_logic_vector(3 downto 0);
  signal mux_sel_in : std_logic_vector(2 downto 0);
  signal recycle_d : std_logic := '0';
  signal sipo_b_rst : std_logic := '0';
  signal recycle_re,recycle_re_d,recycle_re_d2,recycle_re_d3 : std_logic := '0'; -- 
  signal recycle_stretched: std_logic := '0'; 
  signal lfsr: std_logic_vector(5 downto 0);
  signal cnt_enable : std_logic := '1';
  signal slowdown_cnt : std_logic_vector(5 downto 0) := (others => '0'); -- 6 bits for 48x slowdown (0-47)

begin

--  mux_in <= extra_in & noise_1_to_slew(0) & noise_freq(2 downto 0) & extra_in & noise_1_to_slew(1) & '1';
  mux_in <= lfsr(5) & noise_1_to_slew(7) & lfsr(2) & lfsr(1 downto 0) & noise_1_to_slew(7)  & noise_1_to_slew(8) & '1';

  
  lfsr_rnd : entity work.rand_num
    port map(
    clk => Clock,
    en => sipo_clk, -- what if this were much slower like /10 then would the patterns be more repeating??
    reset => rst,
    q => lfsr
    );

  sipo_clk <= cnt_match;
  
  process (Clock)
  begin
    if rising_edge(Clock) then
    recycle_d <= recycle;
    recycle_re_d <= recycle_re;
    recycle_re_d2 <= recycle_re_d;
    recycle_re_d3 <= recycle_re_d2;
    
    recycle_stretched <= recycle or recycle_re_d or recycle_re_d2 or recycle_re_d3;
    
    if recycle = '1' and recycle_d = '0' then
        recycle_re <= '1';
        else
        recycle_re <= '0';
       end if;
    end if;
  end process;
  
  sipo_1 : entity work.shift_sipo
    port map(
      Clock => Clock, 
      shift => sipo_clk,
      SinA => Sin, 
      SinB => Sin, 
      rst => rst,
      Pout => spio_out_1
      );

      sipo_dac_1 <= spio_out_1(3 downto 0);
      sipo_dac_2 <= spio_out_1(0) & spio_out_1(1) & spio_out_1(2) & spio_out_1(3);
      


  sipo_2 : entity work.shift_sipo
      port map(
        Clock => Clock, 
        shift => sipo_clk,
        SinA => spio_out_1(7), 
        SinB => spio_out_1(7), 
        rst => '0',
        Pout => spio_out_2
        );

    mux_in_des <= mux_in(7 downto 0);
    mux_sel_in <= spio_out_2(7)&spio_out_2(5)&(recycle_stretched);
    
  mux_random : entity work.mux_8_to_1
      Port map( 
          data => mux_in_des,
          sel => mux_sel_in,
          mux_out => sin
      );
      
    process(clock) begin 
     if rising_edge(clock) then
            if (count > noise_freq) then 
                cnt_match <= '1';
            else 
                cnt_match <= '0';
            end if;
        end if;
      end process;
      
  cnt_rst <=  cnt_match or rst; -- chroma_pin_74 does it also have this pin?
  
  -- Slowdown logic: controls counter enable to slow down pseudo-random output
  process(clock) begin
    if rising_edge(clock) then
      if rst = '1' then
        slowdown_cnt <= (others => '0');
        cnt_enable <= '1';
      else
        case slowdown_sel is
          when "00" => -- Normal speed (no slowdown)
            cnt_enable <= '1';
            slowdown_cnt <= (others => '0');
          when "01" => -- 24x slower (enable every 24th clock)
            if slowdown_cnt = "010111" then  -- 23 in binary (0-23 = 24 counts)
              cnt_enable <= '1';
              slowdown_cnt <= (others => '0');
            else
              cnt_enable <= '0';
              slowdown_cnt <= std_logic_vector(unsigned(slowdown_cnt) + 1);
            end if;
          when "10" | "11" => -- 48x slower (enable every 48th clock)
            if slowdown_cnt = "101111" then  -- 47 in binary (0-47 = 48 counts)
              cnt_enable <= '1';
              slowdown_cnt <= (others => '0');
            else
              cnt_enable <= '0';
              slowdown_cnt <= std_logic_vector(unsigned(slowdown_cnt) + 1);
            end if;
          when others =>
            cnt_enable <= '1';
            slowdown_cnt <= (others => '0');
        end case;
      end if;
    end if;
  end process;
  
  random_freq: entity work.counter
    generic map (
        width => 14
    )
    port map (
        clk => clock,
        rst => cnt_rst,
        enable => cnt_enable,
        count => count
    );
  
  
slew_output_1 : entity work.slew_wraper
  Port map(
    clk => clock,
    rst => rst,
    slew_sel => slew_in,
    input => noise_1_to_slew,
    output => slew_out_1
   );
         
         
slew_output_2 : entity work.slew_wraper
  Port map(
    clk => clock,
    rst => rst,
    slew_sel => slew_in,
    input => noise_2_to_slew,
    output => slew_out_2
   );

      noise_1_to_slew(9 downto 6) <= sipo_dac_1;
      noise_1_to_slew(5 downto 0) <= (others => '0');
      noise_2_to_slew(9 downto 6) <= sipo_dac_2;
      noise_2_to_slew(5 downto 0) <= (others => '0');
      
      noise_1 <= slew_out_1;
      noise_2 <= slew_out_2;

      -- needs level contorl

end Behavioral;
