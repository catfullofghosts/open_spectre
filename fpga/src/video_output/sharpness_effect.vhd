library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Horizontal 3-tap blur/sharpen on luma, applied proportionally to RGB.
-- Pipelined for timing (3 active-video cycles when enabled):
--   stage 0: pixel shift
--   stage 1: luminance of 3-tap window
--   stage 2: kernel + strength blend
--   stage 3: per-channel scale

entity sharpness_effect is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    enable     : in  std_logic;
    mode       : in  std_logic;
    strength   : in  std_logic_vector(7 downto 0);
    r_in       : in  std_logic_vector(7 downto 0);
    g_in       : in  std_logic_vector(7 downto 0);
    b_in       : in  std_logic_vector(7 downto 0);
    hsync_in   : in  std_logic;
    vsync_in   : in  std_logic;
    de_in      : in  std_logic;
    r_out      : out std_logic_vector(7 downto 0);
    g_out      : out std_logic_vector(7 downto 0);
    b_out      : out std_logic_vector(7 downto 0);
    hsync_out  : out std_logic;
    vsync_out  : out std_logic;
    de_out     : out std_logic
  );
end entity sharpness_effect;

architecture rtl of sharpness_effect is

  constant SHARP_K_LEFT   : integer := -1;
  constant SHARP_K_CENTER : integer := 3;
  constant SHARP_K_RIGHT  : integer := -1;

  constant BLUR_K_LEFT   : integer := 1;
  constant BLUR_K_CENTER : integer := 2;
  constant BLUR_K_RIGHT  : integer := 1;

  signal pixel_left   : std_logic_vector(23 downto 0);
  signal pixel_center : std_logic_vector(23 downto 0);
  signal pixel_right  : std_logic_vector(23 downto 0);

  signal luminance_left   : unsigned(7 downto 0);
  signal luminance_center : unsigned(7 downto 0);
  signal luminance_right  : unsigned(7 downto 0);

  signal pixel_center_d : std_logic_vector(23 downto 0);
  signal luma_center_d  : unsigned(7 downto 0);
  signal blended_luma_d : unsigned(7 downto 0);

  signal strength_r : unsigned(7 downto 0);
  signal mode_r     : std_logic;
  signal enable_r   : std_logic;

  signal hsync_pipe : std_logic_vector(2 downto 0);
  signal vsync_pipe : std_logic_vector(2 downto 0);
  signal de_pipe    : std_logic_vector(2 downto 0);

begin

  p_pipe : process (clk) is
    variable v_kernel   : signed(31 downto 0);
    variable v_filtered : unsigned(7 downto 0);
    variable v_diff     : signed(16 downto 0);
    variable v_blended  : unsigned(15 downto 0);
    variable v_ratio    : unsigned(15 downto 0);
    variable v_scaled   : unsigned(15 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pixel_left       <= (others => '0');
        pixel_center     <= (others => '0');
        pixel_right      <= (others => '0');
        luminance_left   <= (others => '0');
        luminance_center <= (others => '0');
        luminance_right  <= (others => '0');
        pixel_center_d   <= (others => '0');
        luma_center_d    <= (others => '0');
        blended_luma_d   <= (others => '0');
        strength_r       <= (others => '0');
        mode_r           <= '0';
        enable_r         <= '0';
        hsync_pipe       <= (others => '0');
        vsync_pipe       <= (others => '0');
        de_pipe          <= (others => '0');
        r_out            <= (others => '0');
        g_out            <= (others => '0');
        b_out            <= (others => '0');
        hsync_out        <= '0';
        vsync_out        <= '0';
        de_out           <= '0';
      else
        enable_r   <= enable;
        mode_r     <= mode;
        strength_r <= unsigned(strength);

        hsync_pipe <= hsync_pipe(1 downto 0) & hsync_in;
        vsync_pipe <= vsync_pipe(1 downto 0) & vsync_in;
        de_pipe    <= de_pipe(1 downto 0) & de_in;

        hsync_out <= hsync_pipe(2);
        vsync_out <= vsync_pipe(2);
        de_out    <= de_pipe(2);

        if enable = '0' then
          r_out <= r_in;
          g_out <= g_in;
          b_out <= b_in;
        else
          -- Stage 0: horizontal pixel window
          if de_in = '1' then
            pixel_left   <= pixel_center;
            pixel_center <= pixel_right;
            pixel_right  <= b_in & g_in & r_in;
          end if;

          -- Stage 1: luminance
          if de_pipe(0) = '1' then
            luminance_left <= (
              unsigned(pixel_left(23 downto 16)) * 77 +
              unsigned(pixel_left(15 downto 8)) * 150 +
              unsigned(pixel_left(7 downto 0)) * 29
            ) srl 8;
            luminance_center <= (
              unsigned(pixel_center(23 downto 16)) * 77 +
              unsigned(pixel_center(15 downto 8)) * 150 +
              unsigned(pixel_center(7 downto 0)) * 29
            ) srl 8;
            luminance_right <= (
              unsigned(pixel_right(23 downto 16)) * 77 +
              unsigned(pixel_right(15 downto 8)) * 150 +
              unsigned(pixel_right(7 downto 0)) * 29
            ) srl 8;
          end if;

          -- Stage 2: filter + blend
          if de_pipe(1) = '1' then
            pixel_center_d <= pixel_center;
            luma_center_d  <= luminance_center;

            if mode_r = '1' then
              v_kernel := SHARP_K_LEFT * signed("00000000" & std_logic_vector(luminance_left)) +
                          SHARP_K_CENTER * signed("00000000" & std_logic_vector(luminance_center)) +
                          SHARP_K_RIGHT * signed("00000000" & std_logic_vector(luminance_right));
            else
              v_kernel := (
                BLUR_K_LEFT * signed("00000000" & std_logic_vector(luminance_left)) +
                BLUR_K_CENTER * signed("00000000" & std_logic_vector(luminance_center)) +
                BLUR_K_RIGHT * signed("00000000" & std_logic_vector(luminance_right))
              ) / 4;
            end if;

            if v_kernel < 0 then
              v_filtered := (others => '0');
            elsif v_kernel > 255 then
              v_filtered := (others => '1');
            else
              v_filtered := unsigned(v_kernel(7 downto 0));
            end if;

            v_diff := signed("0" & v_filtered) - signed("0" & luminance_center);
            v_blended := resize(luminance_center, v_blended'length) +
              (unsigned(v_diff(7 downto 0)) * strength_r) / 255;
            if v_blended > 255 then
              blended_luma_d <= to_unsigned(255, 8);
            else
              blended_luma_d <= v_blended(7 downto 0);
            end if;
          end if;

          -- Stage 3: scale RGB
          if de_pipe(2) = '1' then
            if luma_center_d = 0 then
              r_out <= pixel_center_d(7 downto 0);
              g_out <= pixel_center_d(15 downto 8);
              b_out <= pixel_center_d(23 downto 16);
            else
              v_ratio := (blended_luma_d * 255) / luma_center_d;

              v_scaled := (unsigned(pixel_center_d(7 downto 0)) * v_ratio) / 255;
              if v_scaled > 255 then
                r_out <= (others => '1');
              else
                r_out <= std_logic_vector(v_scaled(7 downto 0));
              end if;

              v_scaled := (unsigned(pixel_center_d(15 downto 8)) * v_ratio) / 255;
              if v_scaled > 255 then
                g_out <= (others => '1');
              else
                g_out <= std_logic_vector(v_scaled(7 downto 0));
              end if;

              v_scaled := (unsigned(pixel_center_d(23 downto 16)) * v_ratio) / 255;
              if v_scaled > 255 then
                b_out <= (others => '1');
              else
                b_out <= std_logic_vector(v_scaled(7 downto 0));
              end if;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process p_pipe;

end architecture rtl;
