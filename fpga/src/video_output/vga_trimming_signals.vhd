
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: vga_trimming_signals by RD Jordan
-- Created: 2023
-- Description: 
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE

--http://tinyvga.com/vga-timing/800x600@60Hz
--http://tinyvga.com/vga-timing/1280x720@60Hz
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_trimming_signals is
  port (
    px_clk                : in std_logic; -- clock input
    reset                 : in std_logic; -- reset input
    mode_select           : in std_logic; -- mode select input (0 for SVGA 800x600, 1 for 720p60)
    h_sync                : out std_logic; -- horizontal sync output
    v_sync                : out std_logic; -- vertical sync output
    video_on              : out std_logic; -- video on/off output
    start_of_frame        : out std_logic; -- start of frame output
    start_of_active_video : out std_logic; -- start of active video output
    frame_counter         : out std_logic_vector(3 downto 0) -- 4-bit frame counter
  );
end vga_trimming_signals;

architecture rtl of vga_trimming_signals is

  -- Timing parameters for SVGA 800x600 40MHz
  constant SVGA_h_front_porch : integer := 40;
  constant SVGA_h_sync_width  : integer := 128;
  constant SVGA_h_back_porch  : integer := 88;
  constant SVGA_h_total       : integer := 1056;
  constant SVGA_v_front_porch : integer := 1;
  constant SVGA_v_sync_width  : integer := 4;
  constant SVGA_v_back_porch  : integer := 23;
  constant SVGA_v_total       : integer := 628;

  -- Timing parameters for 720p60 74.25MHz
  constant HD720_h_front_porch : integer := 110;
  constant HD720_h_sync_width  : integer := 40;
  constant HD720_h_back_porch  : integer := 220;
  constant HD720_h_total       : integer := 1650;
  constant HD720_v_front_porch : integer := 5;
  constant HD720_v_sync_width  : integer := 5;
  constant HD720_v_back_porch  : integer := 20;
  constant HD720_v_total       : integer := 750;

  -- Internal counters
  signal h_count : integer range 0 to HD720_h_total - 1 := 0;
  signal v_count : integer range 0 to HD720_v_total - 1 := 0;

  signal frame_count : unsigned(3 downto 0) := (others => '0');

begin

  process (px_clk, reset)
    variable current_h_total       : integer;
    variable current_h_sync_width  : integer;
    variable current_h_front_porch : integer;
    variable current_h_back_porch  : integer;
    variable current_v_total       : integer;
    variable current_v_sync_width  : integer;
    variable current_v_front_porch : integer;
    variable current_v_back_porch  : integer;
  begin
    if reset = '1' then
      h_count               <= 0;
      v_count               <= 0;
      frame_count           <= (others => '0');
      h_sync                <= '0';
      v_sync                <= '0';
      video_on              <= '0';
      start_of_frame        <= '0';
      start_of_active_video <= '0';
    elsif rising_edge(px_clk) then
      -- Set current timing parameters based on mode_select
      if mode_select = '0' then
        current_h_total       := SVGA_h_total;
        current_h_sync_width  := SVGA_h_sync_width;
        current_h_front_porch := SVGA_h_front_porch;
        current_h_back_porch  := SVGA_h_back_porch;
        current_v_total       := SVGA_v_total;
        current_v_sync_width  := SVGA_v_sync_width;
        current_v_front_porch := SVGA_v_front_porch;
        current_v_back_porch  := SVGA_v_back_porch;
      else
        current_h_total       := HD720_h_total;
        current_h_sync_width  := HD720_h_sync_width;
        current_h_front_porch := HD720_h_front_porch;
        current_h_back_porch  := HD720_h_back_porch;
        current_v_total       := HD720_v_total;
        current_v_sync_width  := HD720_v_sync_width;
        current_v_front_porch := HD720_v_front_porch;
        current_v_back_porch  := HD720_v_back_porch;
      end if;

      -- Horizontal counter
      if h_count = current_h_total - 1 then
        h_count <= 0;
        -- Vertical counter
        if v_count = current_v_total - 1 then
          v_count        <= 0;
          frame_count    <= frame_count + 1;
          start_of_frame <= '1';
        else
          v_count        <= v_count + 1;
          start_of_frame <= '0';
        end if;
      else
        h_count        <= h_count + 1;
        start_of_frame <= '0';
      end if;

      -- Start of active video
      if h_count = current_h_sync_width + current_h_front_porch + 1 and v_count = current_v_sync_width + current_v_front_porch + 1 then
        start_of_active_video <= '1';
      else
        start_of_active_video <= '0';
      end if;

      -- Horizontal sync
      if h_count < current_h_sync_width + current_h_front_porch then
        h_sync <= '1';
      else
        h_sync <= '0';
      end if;

      -- Vertical sync
      if v_count < current_v_sync_width + current_v_front_porch then
        v_sync <= '1';
      else
        v_sync <= '0';
      end if;

      -- Video on/off
      if h_count >= current_h_sync_width + current_h_front_porch and h_count < current_h_total - current_h_back_porch and
        v_count >= current_v_sync_width + current_v_front_porch and v_count < current_v_total - current_v_back_porch then
        video_on <= '1';
      else
        video_on <= '0';
      end if;
    end if;
  end process;

  -- Assign frame_counter
  frame_counter <= std_logic_vector(frame_count);

end rtl;
