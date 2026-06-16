-- Module Name: luma_key
-- Description: Simple luma key that keys incoming video based on brightness
-- The key can be configured to key pixels above or below a threshold range
-- 
-- Register format (32-bit):
--   [31]     : enable (1 = enable luma key, 0 = bypass)
--   [30]     : direction (0 = key pixels < threshold, 1 = key pixels > threshold)
--   [29:16]  : reserved
--   [15:8]   : threshold_high (8-bit, 0-255, byte aligned)
--   [7:0]    : threshold_low (8-bit, 0-255, byte aligned)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity luma_key is
  port (
    clk : in std_logic;
    rst : in std_logic;
    
    -- Control register
    enable        : in std_logic;
    direction     : in std_logic; -- 0 = key < threshold, 1 = key > threshold
    threshold_low : in std_logic_vector(7 downto 0);
    threshold_high: in std_logic_vector(7 downto 0);
    
    -- Video input (24-bit RGB)
    video_in : in std_logic_vector(23 downto 0);
    
    -- Video output (24-bit RGB, passed through with pipeline delay)
    video_out : out std_logic_vector(23 downto 0);
    
    -- Key signal: '1' = pixel is keyed (transparent), '0' = pixel is opaque
    key_valid : out std_logic
  );
end entity luma_key;

architecture rtl of luma_key is
  
  -- Calculate luma: Y = (R + G + B) / 3 (simple average, 8-bit result 0-255)
  signal luma : unsigned(7 downto 0);
  signal luma_reg : unsigned(7 downto 0);
  
  -- Comparison result
  signal key_match : std_logic;
  
  -- Registered video for pipeline (2 cycles delay to match luma calculation + comparison)
  signal video_in_reg1 : std_logic_vector(23 downto 0);
  signal video_in_reg2 : std_logic_vector(23 downto 0);
  
begin
  
  -- Calculate luma from RGB using simple average: (R + G + B) / 3
  process(clk)
    variable r_val : unsigned(7 downto 0);
    variable g_val : unsigned(7 downto 0);
    variable b_val : unsigned(7 downto 0);
    variable sum : unsigned(7 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        luma <= (others => '0');
        video_in_reg1 <= (others => '0');
      else
        -- Register input video (stage 1)
        video_in_reg1 <= video_in;
        
        -- Calculate luma: (R + G + B) / 3
        r_val := unsigned(video_in(23 downto 16));
        g_val := unsigned(video_in(15 downto 8));
        b_val := unsigned(video_in(7 downto 0));
        
        -- Sum three 8-bit values: max is 255+255+255 = 765, needs 10 bits
        sum := ((r_val) + (g_val) + (b_val))/3;
        luma <= sum;
      end if;
    end if;
  end process;
  
  -- Register luma and video for comparison (stage 2)
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        luma_reg <= (others => '0');
        video_in_reg2 <= (others => '0');
      else
        luma_reg <= luma;
        video_in_reg2 <= video_in_reg1;
      end if;
    end if;
  end process;
  
  -- Compare luma to threshold range and output
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        key_match <= '0';
        video_out <= (others => '0');
        key_valid <= '0';
      else
        -- Determine if pixel should be keyed based on direction
        if enable = '1' then
          if direction = '0' then
            -- Key pixels below threshold_low (luma < threshold_low)
            if luma_reg < unsigned(threshold_low) then
              key_match <= '1';
            else
              key_match <= '0';
            end if;
          else
            -- Key pixels above threshold_high (luma > threshold_high)
            if luma_reg > unsigned(threshold_high) then
              key_match <= '1';
            else
              key_match <= '0';
            end if;
          end if;
        else
          -- When disabled, no pixels are keyed (all opaque)
          key_match <= '0';
        end if;
        
        -- Output video (always pass through with pipeline delay)
        video_out <= video_in_reg2;
        
        -- Output key signal: '1' = keyed (transparent), '0' = opaque
        key_valid <= key_match;
      end if;
    end if;
  end process;
  
end architecture rtl;

