library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Per-frame RGB / brightness analysis on the final video stream (active pixels only).
-- Results are box-filtered over G_FILTER_FRAMES completed frames before export.
--
-- video_in / video_out packing: B(23:16) & G(15:8) & R(7:0)
--
-- Brightness per pixel: approx (R + G + B) / 3 via (R+G+B)*85 >> 8
--
-- Read-only register map (see digital_reg_file @ 0x180):
--   luma/R/G/B min, max, avg (8-bit each), frame_id byte increments each update
--   @ 0x190: frame_hash — unfiltered 32-bit hash of active pixels (scan order)
--   @ 0x194: frame_pix_count — active pixel count for the hashed frame
--
-- Hash (replicate in software for golden values):
--   h = 5381
--   for each active pixel p (24-bit BGR as on the video bus):
--     h = ((h << 5) + h + p) mod 2^32    -- djb2-style

entity frame_video_stats is
  generic (
    G_FILTER_FRAMES : positive := 4;
    G_DIV_CYCLES    : positive := 32  -- sequential bits for sum/count division
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    h_sync    : in  std_logic;
    v_sync    : in  std_logic;
    video_in  : in  std_logic_vector(23 downto 0);
    video_out : out std_logic_vector(23 downto 0);

    stats_luma_min : out std_logic_vector(7 downto 0);
    stats_luma_max : out std_logic_vector(7 downto 0);
    stats_luma_avg : out std_logic_vector(7 downto 0);
    stats_r_min    : out std_logic_vector(7 downto 0);
    stats_r_max    : out std_logic_vector(7 downto 0);
    stats_r_avg    : out std_logic_vector(7 downto 0);
    stats_g_min    : out std_logic_vector(7 downto 0);
    stats_g_max    : out std_logic_vector(7 downto 0);
    stats_g_avg    : out std_logic_vector(7 downto 0);
    stats_b_min    : out std_logic_vector(7 downto 0);
    stats_b_max    : out std_logic_vector(7 downto 0);
    stats_b_avg    : out std_logic_vector(7 downto 0);
    stats_frame_id : out std_logic_vector(7 downto 0);
    stats_frame_hash      : out std_logic_vector(31 downto 0);
    stats_frame_pix_count : out std_logic_vector(31 downto 0)
  );
end entity frame_video_stats;

architecture rtl of frame_video_stats is

  type t_byte_hist is array (0 to G_FILTER_FRAMES - 1) of unsigned(7 downto 0);
  type t_sum_array is array (0 to 3) of unsigned(31 downto 0);

  constant C_HASH_INIT : unsigned(31 downto 0) := to_unsigned(5381, 32);
  constant C_LUMA_MUL  : unsigned(7 downto 0)  := to_unsigned(85, 8); -- ~1/3 via >>8

  type t_post_state is (POST_IDLE, POST_DIV, POST_PUBLISH);
  signal post_state : t_post_state := POST_IDLE;

  signal active_video : std_logic;
  signal v_sync_d     : std_logic;
  signal frame_end    : std_logic;

  -- Pixel pipeline (breaks hash / sum carry paths across clocks)
  signal s1_active    : std_logic;
  signal s1_video     : std_logic_vector(23 downto 0);
  signal s1_r         : unsigned(7 downto 0);
  signal s1_g         : unsigned(7 downto 0);
  signal s1_b         : unsigned(7 downto 0);
  signal s1_luma      : unsigned(7 downto 0);

  signal min_r        : unsigned(7 downto 0);
  signal max_r        : unsigned(7 downto 0);
  signal min_g        : unsigned(7 downto 0);
  signal max_g        : unsigned(7 downto 0);
  signal min_b        : unsigned(7 downto 0);
  signal max_b        : unsigned(7 downto 0);
  signal min_luma     : unsigned(7 downto 0);
  signal max_luma     : unsigned(7 downto 0);

  signal sum_r        : unsigned(31 downto 0);
  signal sum_g        : unsigned(31 downto 0);
  signal sum_b        : unsigned(31 downto 0);
  signal sum_luma     : unsigned(31 downto 0);
  signal pix_count    : unsigned(31 downto 0);

  signal h_lmin, h_lmax, h_lavg : t_byte_hist;
  signal h_rmin, h_rmax, h_ravg : t_byte_hist;
  signal h_gmin, h_gmax, h_gavg : t_byte_hist;
  signal h_bmin, h_bmax, h_bavg : t_byte_hist;

  signal hist_count   : natural range 0 to G_FILTER_FRAMES := 0;
  signal frame_id_i   : unsigned(7 downto 0);

  signal hash_acc     : unsigned(31 downto 0);

  -- Captured frame snapshot for post-processing (divider runs in parallel with next frame)
  signal cap_pending  : std_logic;
  signal cap_ack      : std_logic;
  signal cap_pix      : unsigned(31 downto 0);
  signal cap_sums     : t_sum_array;
  signal cap_min_luma : unsigned(7 downto 0);
  signal cap_max_luma : unsigned(7 downto 0);
  signal cap_min_r    : unsigned(7 downto 0);
  signal cap_max_r    : unsigned(7 downto 0);
  signal cap_min_g    : unsigned(7 downto 0);
  signal cap_max_g    : unsigned(7 downto 0);
  signal cap_min_b    : unsigned(7 downto 0);
  signal cap_max_b    : unsigned(7 downto 0);

  signal div_chan     : natural range 0 to 3;
  signal div_step     : natural range 0 to G_DIV_CYCLES;
  signal div_den      : unsigned(31 downto 0);
  signal div_rem      : unsigned(31 downto 0);
  signal div_quot     : unsigned(31 downto 0);

  signal avg_luma     : unsigned(7 downto 0);
  signal avg_r        : unsigned(7 downto 0);
  signal avg_g        : unsigned(7 downto 0);
  signal avg_b        : unsigned(7 downto 0);

  function f_box_avg (
    h     : t_byte_hist;
    count : natural
  ) return unsigned is
    variable acc  : unsigned(9 downto 0);
    variable prod : unsigned(17 downto 0);
  begin
    acc := (others => '0');
    for i in 0 to G_FILTER_FRAMES - 1 loop
      if i < count then
        acc := acc + resize(h(i), acc'length);
      end if;
    end loop;
    case count is
      when 0      => return to_unsigned(0, 8);
      when 1      => return resize(acc, 8);
      when 2      => return resize(shift_right(acc, 1), 8);
      when 3      =>
        prod := acc * to_unsigned(85, 8);
        return resize(shift_right(prod, 8), 8);
      when others => return resize(shift_right(acc, 2), 8);
    end case;
  end function f_box_avg;

begin

  active_video <= '1' when h_sync = '0' and v_sync = '0' else '0';
  video_out    <= video_in;

  -- End of active frame: v_sync leaves active-low region (0 -> 1)
  frame_end <= '1' when v_sync = '1' and v_sync_d = '0' else '0';

  p_pixel : process (clk) is
    variable v_rgb_sum : unsigned(9 downto 0);
    variable v_luma    : unsigned(7 downto 0);
    variable v_hash    : unsigned(31 downto 0);
    variable v_luma_prod : unsigned(17 downto 0);
  begin
    if rising_edge(clk) then
      v_sync_d <= v_sync;

      if rst = '1' then
        s1_active <= '0';
        s1_video  <= (others => '0');
        s1_r      <= (others => '0');
        s1_g      <= (others => '0');
        s1_b      <= (others => '0');
        s1_luma   <= (others => '0');

        min_r     <= (others => '1');
        max_r     <= (others => '0');
        min_g     <= (others => '1');
        max_g     <= (others => '0');
        min_b     <= (others => '1');
        max_b     <= (others => '0');
        min_luma  <= (others => '1');
        max_luma  <= (others => '0');
        sum_r     <= (others => '0');
        sum_g     <= (others => '0');
        sum_b     <= (others => '0');
        sum_luma  <= (others => '0');
        pix_count <= (others => '0');
        hash_acc  <= C_HASH_INIT;

        cap_pending <= '0';
      else
        -- Stage 1: register pixel and compute channel/luma values
        s1_active <= active_video;
        if active_video = '1' then
          s1_video <= video_in;
          s1_r     <= unsigned(video_in(7 downto 0));
          s1_g     <= unsigned(video_in(15 downto 8));
          s1_b     <= unsigned(video_in(23 downto 16));

          v_rgb_sum := resize(unsigned(video_in(7 downto 0)), 10)
                     + resize(unsigned(video_in(15 downto 8)), 10)
                     + resize(unsigned(video_in(23 downto 16)), 10);
          v_luma_prod := v_rgb_sum * C_LUMA_MUL;
          v_luma := resize(shift_right(v_luma_prod, 8), 8);
          s1_luma <= v_luma;
        end if;

        -- Stage 2: min/max, sums, hash (one clock after sample)
        if s1_active = '1' then
          if s1_r < min_r then min_r <= s1_r; end if;
          if s1_r > max_r then max_r <= s1_r; end if;
          if s1_g < min_g then min_g <= s1_g; end if;
          if s1_g > max_g then max_g <= s1_g; end if;
          if s1_b < min_b then min_b <= s1_b; end if;
          if s1_b > max_b then max_b <= s1_b; end if;
          if s1_luma < min_luma then min_luma <= s1_luma; end if;
          if s1_luma > max_luma then max_luma <= s1_luma; end if;

          sum_r     <= sum_r + resize(s1_r, sum_r'length);
          sum_g     <= sum_g + resize(s1_g, sum_g'length);
          sum_b     <= sum_b + resize(s1_b, sum_b'length);
          sum_luma  <= sum_luma + resize(s1_luma, sum_luma'length);
          pix_count <= pix_count + 1;

          v_hash := shift_left(hash_acc, 5) + hash_acc + unsigned(x"00" & s1_video);
          hash_acc <= v_hash;
        end if;

        if frame_end = '1' then
          stats_frame_hash      <= std_logic_vector(hash_acc);
          stats_frame_pix_count <= std_logic_vector(pix_count);

          if pix_count /= 0 and post_state = POST_IDLE and cap_pending = '0' then
            cap_pending  <= '1';
            cap_pix      <= pix_count;
            cap_sums(0)  <= sum_luma;
            cap_sums(1)  <= sum_r;
            cap_sums(2)  <= sum_g;
            cap_sums(3)  <= sum_b;
            cap_min_luma <= min_luma;
            cap_max_luma <= max_luma;
            cap_min_r    <= min_r;
            cap_max_r    <= max_r;
            cap_min_g    <= min_g;
            cap_max_g    <= max_g;
            cap_min_b    <= min_b;
            cap_max_b    <= max_b;
          end if;

          min_r     <= (others => '1');
          max_r     <= (others => '0');
          min_g     <= (others => '1');
          max_g     <= (others => '0');
          min_b     <= (others => '1');
          max_b     <= (others => '0');
          min_luma  <= (others => '1');
          max_luma  <= (others => '0');
          sum_r     <= (others => '0');
          sum_g     <= (others => '0');
          sum_b     <= (others => '0');
          sum_luma  <= (others => '0');
          pix_count <= (others => '0');
          hash_acc  <= C_HASH_INIT;
        end if;

        if cap_ack = '1' then
          cap_pending <= '0';
        end if;
      end if;
    end if;
  end process p_pixel;

  p_post : process (clk) is
    variable v_hist_count : natural range 0 to G_FILTER_FRAMES;
    variable v_shifted    : unsigned(31 downto 0);
  begin
    if rising_edge(clk) then
      cap_ack <= '0';

      if rst = '1' then
        post_state <= POST_IDLE;
        div_chan   <= 0;
        div_step   <= 0;
        div_den    <= (others => '0');
        div_rem    <= (others => '0');
        div_quot   <= (others => '0');
        hist_count <= 0;
        frame_id_i <= (others => '0');
        avg_luma   <= (others => '0');
        avg_r      <= (others => '0');
        avg_g      <= (others => '0');
        avg_b      <= (others => '0');

        stats_luma_min <= (others => '0');
        stats_luma_max <= (others => '0');
        stats_luma_avg <= (others => '0');
        stats_r_min    <= (others => '0');
        stats_r_max    <= (others => '0');
        stats_r_avg    <= (others => '0');
        stats_g_min    <= (others => '0');
        stats_g_max    <= (others => '0');
        stats_g_avg    <= (others => '0');
        stats_b_min    <= (others => '0');
        stats_b_max    <= (others => '0');
        stats_b_avg    <= (others => '0');
        stats_frame_id <= (others => '0');
      else
        case post_state is
          when POST_IDLE =>
            if cap_pending = '1' then
              cap_ack     <= '1';
              div_chan    <= 0;
              div_step    <= 0;
              div_den     <= cap_pix;
              div_rem     <= cap_sums(0);
              div_quot    <= (others => '0');
              post_state  <= POST_DIV;
            end if;

          when POST_DIV =>
            if div_step < G_DIV_CYCLES then
              v_shifted := shift_left(div_rem, 1);
              if v_shifted >= div_den then
                div_rem  <= v_shifted - div_den;
                div_quot <= shift_left(div_quot, 1) or to_unsigned(1, 32);
              else
                div_rem  <= v_shifted;
                div_quot <= shift_left(div_quot, 1);
              end if;
              div_step <= div_step + 1;
            else
              case div_chan is
                when 0 => avg_luma <= resize(div_quot, 8);
                when 1 => avg_r    <= resize(div_quot, 8);
                when 2 => avg_g    <= resize(div_quot, 8);
                when others => avg_b <= resize(div_quot, 8);
              end case;

              if div_chan = 3 then
                post_state <= POST_PUBLISH;
              else
                div_chan   <= div_chan + 1;
                div_step   <= 0;
                div_rem    <= cap_sums(div_chan + 1);
                div_quot   <= (others => '0');
                post_state <= POST_DIV;
              end if;
            end if;

          when POST_PUBLISH =>
            for i in G_FILTER_FRAMES - 1 downto 1 loop
              h_lmin(i) <= h_lmin(i - 1);
              h_lmax(i) <= h_lmax(i - 1);
              h_lavg(i) <= h_lavg(i - 1);
              h_rmin(i) <= h_rmin(i - 1);
              h_rmax(i) <= h_rmax(i - 1);
              h_ravg(i) <= h_ravg(i - 1);
              h_gmin(i) <= h_gmin(i - 1);
              h_gmax(i) <= h_gmax(i - 1);
              h_gavg(i) <= h_gavg(i - 1);
              h_bmin(i) <= h_bmin(i - 1);
              h_bmax(i) <= h_bmax(i - 1);
              h_bavg(i) <= h_bavg(i - 1);
            end loop;

            h_lmin(0) <= cap_min_luma;
            h_lmax(0) <= cap_max_luma;
            h_lavg(0) <= avg_luma;
            h_rmin(0) <= cap_min_r;
            h_rmax(0) <= cap_max_r;
            h_ravg(0) <= avg_r;
            h_gmin(0) <= cap_min_g;
            h_gmax(0) <= cap_max_g;
            h_gavg(0) <= avg_g;
            h_bmin(0) <= cap_min_b;
            h_bmax(0) <= cap_max_b;
            h_bavg(0) <= avg_b;

            if hist_count < G_FILTER_FRAMES then
              v_hist_count := hist_count + 1;
              hist_count   <= hist_count + 1;
            else
              v_hist_count := G_FILTER_FRAMES;
            end if;

            stats_luma_min <= std_logic_vector(f_box_avg(h_lmin, v_hist_count));
            stats_luma_max <= std_logic_vector(f_box_avg(h_lmax, v_hist_count));
            stats_luma_avg <= std_logic_vector(f_box_avg(h_lavg, v_hist_count));
            stats_r_min    <= std_logic_vector(f_box_avg(h_rmin, v_hist_count));
            stats_r_max    <= std_logic_vector(f_box_avg(h_rmax, v_hist_count));
            stats_r_avg    <= std_logic_vector(f_box_avg(h_ravg, v_hist_count));
            stats_g_min    <= std_logic_vector(f_box_avg(h_gmin, v_hist_count));
            stats_g_max    <= std_logic_vector(f_box_avg(h_gmax, v_hist_count));
            stats_g_avg    <= std_logic_vector(f_box_avg(h_gavg, v_hist_count));
            stats_b_min    <= std_logic_vector(f_box_avg(h_bmin, v_hist_count));
            stats_b_max    <= std_logic_vector(f_box_avg(h_bmax, v_hist_count));
            stats_b_avg    <= std_logic_vector(f_box_avg(h_bavg, v_hist_count));

            frame_id_i     <= frame_id_i + 1;
            stats_frame_id <= std_logic_vector(frame_id_i + 1);
            post_state     <= POST_IDLE;
        end case;
      end if;
    end if;
  end process p_post;

end architecture rtl;
