library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Per-frame RGB / brightness analysis on the final video stream (active pixels only).
-- Results are box-filtered over G_FILTER_FRAMES completed frames before export.
--
-- video_in / video_out packing: B(23:16) & G(15:8) & R(7:0)
--
-- Brightness per pixel: (R + G + B) / 3
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
    G_FILTER_FRAMES : positive := 4
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

  signal active_video : std_logic;
  signal v_sync_d     : std_logic;
  signal frame_end    : std_logic;

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

  signal hist_count   : unsigned(2 downto 0);
  signal frame_id_i   : unsigned(7 downto 0);
  signal hash_acc     : unsigned(31 downto 0);

  constant C_HASH_INIT : unsigned(31 downto 0) := to_unsigned(5381, 32);

  function f_box_avg (
    h     : t_byte_hist;
    count : natural
  ) return unsigned is
    variable acc : unsigned(9 downto 0);
  begin
    acc := (others => '0');
    for i in 0 to count - 1 loop
      acc := acc + resize(h(i), acc'length);
    end loop;
    case count is
      when 0      => return (others => '0');
      when 1      => return resize(acc(7 downto 0), 8);
      when 2      => return resize(shift_right(acc, 1)(7 downto 0), 8);
      when 3      => return resize((acc / 3)(7 downto 0), 8);
      when others => return resize(shift_right(acc, 2)(7 downto 0), 8);
    end case;
  end function f_box_avg;

begin

  active_video <= '1' when h_sync = '0' and v_sync = '0' else '0';
  video_out    <= video_in;

  frame_end <= v_sync and not v_sync_d;

  p_analyse : process (clk) is
    variable v_r     : unsigned(7 downto 0);
    variable v_g     : unsigned(7 downto 0);
    variable v_b     : unsigned(7 downto 0);
    variable v_luma  : unsigned(7 downto 0);
    variable v_count : natural range 0 to G_FILTER_FRAMES;
    variable v_fmin, v_fmax, v_favg : unsigned(7 downto 0);
  begin
    if rising_edge(clk) then
      v_sync_d <= v_sync;

      if rst = '1' then
        min_r    <= (others => '1');
        max_r    <= (others => '0');
        min_g    <= (others => '1');
        max_g    <= (others => '0');
        min_b    <= (others => '1');
        max_b    <= (others => '0');
        min_luma <= (others => '1');
        max_luma <= (others => '0');
        sum_r     <= (others => '0');
        sum_g     <= (others => '0');
        sum_b     <= (others => '0');
        sum_luma  <= (others => '0');
        pix_count <= (others => '0');
        hist_count <= (others => '0');
        frame_id_i <= (others => '0');
        hash_acc   <= C_HASH_INIT;

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
        stats_frame_hash      <= (others => '0');
        stats_frame_pix_count <= (others => '0');
      else
        if frame_end = '1' then
          stats_frame_hash      <= std_logic_vector(hash_acc);
          stats_frame_pix_count <= std_logic_vector(pix_count);

          if pix_count /= 0 then
            v_favg := unsigned(sum_luma / pix_count)(7 downto 0);
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
            h_lmin(0) <= min_luma;
            h_lmax(0) <= max_luma;
            h_lavg(0) <= v_favg;
            h_rmin(0) <= min_r;
            h_rmax(0) <= max_r;
            h_ravg(0) <= unsigned(sum_r / pix_count)(7 downto 0);
            h_gmin(0) <= min_g;
            h_gmax(0) <= max_g;
            h_gavg(0) <= unsigned(sum_g / pix_count)(7 downto 0);
            h_bmin(0) <= min_b;
            h_bmax(0) <= max_b;
            h_bavg(0) <= unsigned(sum_b / pix_count)(7 downto 0);

            v_count := to_integer(hist_count) + 1;
            if v_count > G_FILTER_FRAMES then
              v_count := G_FILTER_FRAMES;
            end if;
            if hist_count < G_FILTER_FRAMES then
              hist_count <= hist_count + 1;
            end if;

            stats_luma_min <= std_logic_vector(f_box_avg(h_lmin, v_count));
            stats_luma_max <= std_logic_vector(f_box_avg(h_lmax, v_count));
            stats_luma_avg <= std_logic_vector(f_box_avg(h_lavg, v_count));
            stats_r_min    <= std_logic_vector(f_box_avg(h_rmin, v_count));
            stats_r_max    <= std_logic_vector(f_box_avg(h_rmax, v_count));
            stats_r_avg    <= std_logic_vector(f_box_avg(h_ravg, v_count));
            stats_g_min    <= std_logic_vector(f_box_avg(h_gmin, v_count));
            stats_g_max    <= std_logic_vector(f_box_avg(h_gmax, v_count));
            stats_g_avg    <= std_logic_vector(f_box_avg(h_gavg, v_count));
            stats_b_min    <= std_logic_vector(f_box_avg(h_bmin, v_count));
            stats_b_max    <= std_logic_vector(f_box_avg(h_bmax, v_count));
            stats_b_avg    <= std_logic_vector(f_box_avg(h_bavg, v_count));

            frame_id_i     <= frame_id_i + 1;
            stats_frame_id <= std_logic_vector(frame_id_i + 1);
          end if;

          min_r    <= (others => '1');
          max_r    <= (others => '0');
          min_g    <= (others => '1');
          max_g    <= (others => '0');
          min_b    <= (others => '1');
          max_b    <= (others => '0');
          min_luma <= (others => '1');
          max_luma <= (others => '0');
          sum_r     <= (others => '0');
          sum_g     <= (others => '0');
          sum_b     <= (others => '0');
          sum_luma  <= (others => '0');
          pix_count <= (others => '0');
          hash_acc  <= C_HASH_INIT;
        elsif active_video = '1' then
          v_r    := unsigned(video_in(7 downto 0));
          v_g    := unsigned(video_in(15 downto 8));
          v_b    := unsigned(video_in(23 downto 16));
          v_luma := (v_r + v_g + v_b) / 3;

          if v_r < min_r then min_r <= v_r; end if;
          if v_r > max_r then max_r <= v_r; end if;
          if v_g < min_g then min_g <= v_g; end if;
          if v_g > max_g then max_g <= v_g; end if;
          if v_b < min_b then min_b <= v_b; end if;
          if v_b > max_b then max_b <= v_b; end if;
          if v_luma < min_luma then min_luma <= v_luma; end if;
          if v_luma > max_luma then max_luma <= v_luma; end if;

          sum_r     <= sum_r + v_r;
          sum_g     <= sum_g + v_g;
          sum_b     <= sum_b + v_b;
          sum_luma  <= sum_luma + v_luma;
          pix_count <= pix_count + 1;
          hash_acc  <= shift_left(hash_acc, 5) + hash_acc + unsigned(x"00" & video_in);
        end if;
      end if;
    end if;
  end process p_analyse;

end architecture rtl;
