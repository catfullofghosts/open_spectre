--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: monstable_4
-- Created: Early 2023
-- Description: Four edge outputs; outs 2/3 are width-stretched rising/falling edges.
-- Dependencies: edge_detector
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE-

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity monstable_4 is
  port (
    input      : in  std_logic;
    clk        : in  std_logic;
    edge_width : in  std_logic_vector(1 downto 0); -- 00=2px, 01=4px, 10=6px, 11=8px
    output     : out std_logic_vector(3 downto 0)
  );
end monstable_4;

architecture Behavioral of monstable_4 is

  signal rise_pulse : std_logic;
  signal fall_pulse : std_logic;
  signal rise_d     : std_logic_vector(10 downto 0);
  signal fall_d     : std_logic_vector(10 downto 0);

  function f_stretch (
    pulse : std_logic;
    d     : std_logic_vector(10 downto 0);
    width : std_logic_vector(1 downto 0)
  ) return std_logic is
  begin
    case width is
      when "00"   => return pulse or d(10) or d(9) or d(8); -- by defult the thicker edge is 4 pix wide
      when "01"   => return pulse or d(10) or d(9) or d(8) or d(7) or d(6) or d(5); -- 7 pix wide
      when "10"   => return pulse or d(10) or d(9) or d(8) or d(7) or d(6) or d(5) or d(4) or d(3) or d(2); -- 10pix wide
      when others => return pulse or d(10) or d(9) or d(8) or d(7) or d(6) or d(5) or d(4) or d(3) or d(2) or d(1) or d(0); -- 12pix wide
    end case;
  end function f_stretch;

begin

  ed_rise : entity work.edge_detector
    port map (
      x             => input,
      clk           => clk,
      rising_edge_O => rise_pulse
    );

  ed_fall : entity work.edge_detector
    port map (
      x              => input,
      clk            => clk,
      falling_edge_O => fall_pulse
    );

  stretch_delay : process (clk) -- shift reg both rising and falling edges to get thicker lines in the case statement above
  begin
    if rising_edge(clk) then
      rise_d <= rise_pulse & rise_d(10 downto 1);
      fall_d <= fall_pulse & fall_d(10 downto 1);
    end if;
  end process;

  output(0) <= rise_pulse;
  output(1) <= fall_pulse;
  output(2) <= f_stretch(rise_pulse, rise_d, edge_width);
  output(3) <= f_stretch(fall_pulse, fall_d, edge_width);

end Behavioral;
