library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Final-stage pixel video effects (controlled via video_fx_ctrl register).
-- video_in / video_out packing: B(23:16) & G(15:8) & R(7:0) — matches spector_wrapper bg path.
--
-- video_fx_ctrl bit map:
--   [0]     invert R
--   [1]     invert G
--   [2]     invert B
--   [4:3]   RGB swap: 00=RGB, 01=BGR, 10=GRB, 11=RBG
--   [5]     bit-reverse R (MSB<->LSB within byte)
--   [6]     bit-reverse G
--   [7]     bit-reverse B
--   [8]     scanline effect enable (odd lines delayed)
--   [10:9]  scanline delay: 01=1 pixel, 10=2 pixels
--   [12:11] logic with previous pixel: 01=OR, 10=AND, 11=XOR, 00=off
--
-- video_fx_bitplane @ 0xE8 — per channel (R/G/B), 4 bits each:
--   [3]    1=bypass (full 8-bit), 0=slice selected bit plane
--   [2:0]  bit index 0 (LSB) .. 7 (MSB); replicated to 0x00 / 0xFF
--
-- video_fx_dither @ 0xEC — horizontal ordered dither (no line memory):
--   [0]    1=enable, 0=bypass
--   [2:1]  depth: 00=6-bit, 01=5-bit, 10=4-bit, 11=3-bit output per channel
--
-- video_fx_mirror @ 0xF0 — horizontal mirror (half-line BRAM, no full frame):
--   [0]      1=enable, 0=bypass
--   [11:1]   half-line width in pixels (active half stored, second half reads reversed)
--            mirror region spans 2 * half_width pixels; default half=360 (720-wide line)
--
-- video_fx_chromatic @ 0xF4 — RGB channel delay (chromatic aberration):
--   [0]    1=enable
--   [3:1]  green delay 0-5 pixels
--   [6:4]  blue delay 0-5 pixels (red undelayed)
--
-- video_fx_sharpness @ 0xF8 — horizontal 3-tap blur/sharpen on luma:
--   [0]    1=enable
--   [1]    0=blur, 1=sharpen
--   [15:8] strength 0-255

entity video_effects is
  port (
    clk             : in  std_logic;
    rst             : in  std_logic;
    h_sync          : in  std_logic;
    v_sync          : in  std_logic;
    video_in        : in  std_logic_vector(23 downto 0);
    fx_ctrl         : in  std_logic_vector(31 downto 0);
    fx_bitplane     : in  std_logic_vector(31 downto 0);
    fx_dither       : in  std_logic_vector(31 downto 0);
    fx_mirror       : in  std_logic_vector(31 downto 0);
    fx_chromatic    : in  std_logic_vector(31 downto 0);
    fx_sharpness    : in  std_logic_vector(31 downto 0);
    video_out       : out std_logic_vector(23 downto 0)
  );
end entity video_effects;

architecture rtl of video_effects is

  constant C_MAX_HALF : positive := 512;

  type t_half_line_buf is array (0 to C_MAX_HALF - 1) of std_logic_vector(23 downto 0);

  signal fx_ctrl_r     : std_logic_vector(31 downto 0);
  signal fx_bitplane_r : std_logic_vector(31 downto 0);
  signal fx_dither_r   : std_logic_vector(31 downto 0);
  signal fx_mirror_r    : std_logic_vector(31 downto 0);
  signal fx_chromatic_r : std_logic_vector(31 downto 0);
  signal fx_sharpness_r : std_logic_vector(31 downto 0);

  signal de_active : std_logic;

  signal line_buf : t_half_line_buf;
  attribute ram_style : string;
  attribute ram_style of line_buf : signal is "block";

  signal h_sync_d  : std_logic;
  signal v_sync_d  : std_logic;
  signal line_odd  : std_logic := '0';
  signal x_count   : unsigned(15 downto 0) := (others => '0');

  signal r_in  : std_logic_vector(7 downto 0);
  signal g_in  : std_logic_vector(7 downto 0);
  signal b_in  : std_logic_vector(7 downto 0);
  signal r_out : std_logic_vector(7 downto 0);
  signal g_out : std_logic_vector(7 downto 0);
  signal b_out : std_logic_vector(7 downto 0);

  signal pixel_proc     : std_logic_vector(23 downto 0);
  signal pixel_mirrored : std_logic_vector(23 downto 0);
  signal pixel_prev     : std_logic_vector(23 downto 0) := (others => '0');
  signal pixel_logic    : std_logic_vector(23 downto 0);
  signal pixel_filtered : std_logic_vector(23 downto 0);
  signal pixel_d1         : std_logic_vector(23 downto 0);
  signal pixel_d2         : std_logic_vector(23 downto 0);

  signal r_post_logic : std_logic_vector(7 downto 0);
  signal g_post_logic : std_logic_vector(7 downto 0);
  signal b_post_logic : std_logic_vector(7 downto 0);
  signal r_chrom      : std_logic_vector(7 downto 0);
  signal g_chrom      : std_logic_vector(7 downto 0);
  signal b_chrom      : std_logic_vector(7 downto 0);
  signal r_sharp      : std_logic_vector(7 downto 0);
  signal g_sharp      : std_logic_vector(7 downto 0);
  signal b_sharp      : std_logic_vector(7 downto 0);

  function f_reverse_byte (b : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable v : std_logic_vector(7 downto 0);
  begin
    for i in 0 to 7 loop
      v(i) := b(7 - i);
    end loop;
    return v;
  end function f_reverse_byte;

  function f_apply_swap (
    r, g, b : std_logic_vector(7 downto 0);
    mode    : std_logic_vector(1 downto 0)
  ) return std_logic_vector is
  begin
    case mode is
      when "01"   => return r & g & b; -- BGR
      when "10"   => return g & r & b; -- GRB
      when "11"   => return b & r & g; -- RBG
      when others => return b & g & r; -- RGB (passthrough)
    end case;
  end function f_apply_swap;

  function f_logic_prev (
    curr, prev : std_logic_vector(23 downto 0);
    mode       : std_logic_vector(1 downto 0)
  ) return std_logic_vector is
  begin
    case mode is
      when "01"   => return curr or prev;
      when "10"   => return curr and prev;
      when "11"   => return curr xor prev;
      when others => return curr;
    end case;
  end function f_logic_prev;

  function f_bitplane_slice (
    b    : std_logic_vector(7 downto 0);
    ctrl : std_logic_vector(3 downto 0)
  ) return std_logic_vector is
    variable bit_val : std_logic;
  begin
    if ctrl(3) = '1' then
      return b;
    else
      bit_val := b(to_integer(unsigned(ctrl(2 downto 0))));
      return (others => bit_val);
    end if;
  end function f_bitplane_slice;

  function f_horiz_dither (
    v     : std_logic_vector(7 downto 0);
    phase : unsigned(1 downto 0);
    depth : std_logic_vector(1 downto 0)
  ) return std_logic_vector is
    variable bias   : unsigned(7 downto 0);
    variable sum    : unsigned(8 downto 0);
    variable result : std_logic_vector(7 downto 0);
  begin
    case depth is
      when "00"   => bias := resize(phase * 1, 8);
      when "01"   => bias := resize(phase * 2, 8);
      when "10"   => bias := resize(phase * 4, 8);
      when others => bias := resize(phase * 8, 8);
    end case;

    sum := resize(unsigned(v), 9) + resize(bias, 9);

    case depth is
      when "00"   =>
        if sum(8) = '1' then
          result := "11111100";
        else
          result := std_logic_vector(sum(7 downto 0));
          result(1 downto 0) := "00";
        end if;
      when "01"   =>
        if sum(8) = '1' then
          result := "11111000";
        else
          result := std_logic_vector(sum(7 downto 0));
          result(2 downto 0) := "000";
        end if;
      when "10"   =>
        if sum(8) = '1' then
          result := "11110000";
        else
          result := std_logic_vector(sum(7 downto 0));
          result(3 downto 0) := "0000";
        end if;
      when others =>
        if sum(8) = '1' then
          result := "11100000";
        else
          result := std_logic_vector(sum(7 downto 0));
          result(4 downto 0) := "00000";
        end if;
    end case;

    return result;
  end function f_horiz_dither;

begin

  r_in <= video_in(7 downto 0);
  g_in <= video_in(15 downto 8);
  b_in <= video_in(23 downto 16);

  de_active <= '0' when h_sync = '1' else '1';

  p_sync : process (clk) is
  begin
    if rising_edge(clk) then
      h_sync_d  <= h_sync;
      v_sync_d  <= v_sync;
      fx_ctrl_r     <= fx_ctrl;
      fx_bitplane_r <= fx_bitplane;
      fx_dither_r   <= fx_dither;
      fx_mirror_r    <= fx_mirror;
      fx_chromatic_r <= fx_chromatic;
      fx_sharpness_r <= fx_sharpness;

      if rst = '1' then
        line_odd <= '0';
        x_count  <= (others => '0');
      else
        if v_sync = '1' and v_sync_d = '0' then
          line_odd <= '0';
        elsif h_sync = '1' and h_sync_d = '0' then
          line_odd <= not line_odd;
        end if;

        if h_sync = '1' and h_sync_d = '0' then
          x_count <= (others => '0');
        elsif h_sync = '0' then
          x_count <= x_count + 1;
        end if;
      end if;
    end if;
  end process p_sync;

  p_color : process (r_in, g_in, b_in, fx_ctrl_r, fx_bitplane_r, fx_dither_r, x_count)
    variable vr, vg, vb : std_logic_vector(7 downto 0);
    variable packed       : std_logic_vector(23 downto 0);
  begin
    vr := r_in;
    vg := g_in;
    vb := b_in;

    if fx_ctrl_r(0) = '1' then
      vr := not vr;
    end if;
    if fx_ctrl_r(1) = '1' then
      vg := not vg;
    end if;
    if fx_ctrl_r(2) = '1' then
      vb := not vb;
    end if;

    packed := f_apply_swap(vr, vg, vb, fx_ctrl_r(4 downto 3));
    vb     := packed(23 downto 16);
    vg     := packed(15 downto 8);
    vr     := packed(7 downto 0);

    if fx_ctrl_r(5) = '1' then
      vr := f_reverse_byte(vr);
    end if;
    if fx_ctrl_r(6) = '1' then
      vg := f_reverse_byte(vg);
    end if;
    if fx_ctrl_r(7) = '1' then
      vb := f_reverse_byte(vb);
    end if;

    vr := f_bitplane_slice(vr, fx_bitplane_r(3 downto 0));
    vg := f_bitplane_slice(vg, fx_bitplane_r(7 downto 4));
    vb := f_bitplane_slice(vb, fx_bitplane_r(11 downto 8));

    if fx_dither_r(0) = '1' then
      vr := f_horiz_dither(vr, x_count(1 downto 0), fx_dither_r(2 downto 1));
      vg := f_horiz_dither(vg, x_count(1 downto 0), fx_dither_r(2 downto 1));
      vb := f_horiz_dither(vb, x_count(1 downto 0), fx_dither_r(2 downto 1));
    end if;

    r_out <= vr;
    g_out <= vg;
    b_out <= vb;
  end process p_color;

  pixel_proc <= b_out & g_out & r_out;

  p_mirror : process (clk) is
    variable half_w   : unsigned(10 downto 0);
    variable x_pos    : unsigned(15 downto 0);
    variable wr_index : integer range 0 to C_MAX_HALF - 1;
    variable rd_index : integer range 0 to C_MAX_HALF - 1;
  begin
    if rising_edge(clk) then
      half_w := unsigned(fx_mirror_r(11 downto 1));
      if half_w > C_MAX_HALF then
        half_w := to_unsigned(C_MAX_HALF, half_w'length);
      end if;
      x_pos  := x_count;

      pixel_mirrored <= pixel_proc;

      if fx_mirror_r(0) = '1' and h_sync = '0' and half_w /= 0 then
        if x_pos < half_w then
          if x_pos < C_MAX_HALF then
            wr_index := to_integer(x_pos);
            line_buf(wr_index) <= pixel_proc;
          end if;
        elsif x_pos < (half_w & '0') then
          rd_index := to_integer(half_w - 1 - (x_pos - half_w));
          if rd_index < C_MAX_HALF then
            pixel_mirrored <= line_buf(rd_index);
          end if;
        end if;
      end if;
    end if;
  end process p_mirror;

  pixel_logic <= f_logic_prev(pixel_mirrored, pixel_prev, fx_ctrl_r(12 downto 11));

  r_post_logic <= pixel_logic(7 downto 0);
  g_post_logic <= pixel_logic(15 downto 8);
  b_post_logic <= pixel_logic(23 downto 16);

  chromatic_inst : entity work.chromatic_abrasion_effect
    port map (
      clk       => clk,
      rst       => rst,
      enable    => fx_chromatic_r(0),
      delay_g   => fx_chromatic_r(3 downto 1),
      delay_b   => fx_chromatic_r(6 downto 4),
      r_in      => r_post_logic,
      g_in      => g_post_logic,
      b_in      => b_post_logic,
      hsync_in  => h_sync,
      vsync_in  => v_sync,
      de_in     => de_active,
      r_out     => r_chrom,
      g_out     => g_chrom,
      b_out     => b_chrom,
      hsync_out => open,
      vsync_out => open,
      de_out    => open
    );

  sharpness_inst : entity work.sharpness_effect
    port map (
      clk       => clk,
      rst       => rst,
      enable    => fx_sharpness_r(0),
      mode      => fx_sharpness_r(1),
      strength  => fx_sharpness_r(15 downto 8),
      r_in      => r_chrom,
      g_in      => g_chrom,
      b_in      => b_chrom,
      hsync_in  => h_sync,
      vsync_in  => v_sync,
      de_in     => de_active,
      r_out     => r_sharp,
      g_out     => g_sharp,
      b_out     => b_sharp,
      hsync_out => open,
      vsync_out => open,
      de_out    => open
    );

  pixel_filtered <= b_sharp & g_sharp & r_sharp;

  p_output : process (clk) is
  begin
    if rising_edge(clk) then
      if h_sync = '1' and h_sync_d = '0' then
        pixel_prev <= (others => '0');
      else
        pixel_prev <= pixel_mirrored;
      end if;

      pixel_d1 <= pixel_filtered;
      pixel_d2 <= pixel_d1;

      if fx_ctrl_r(8) = '1' and line_odd = '1' then
        case fx_ctrl_r(10 downto 9) is
          when "01"   => video_out <= pixel_d1;
          when "10"   => video_out <= pixel_d2;
          when others => video_out <= pixel_filtered;
        end case;
      else
        video_out <= pixel_filtered;
      end if;
    end if;
  end process p_output;

end architecture rtl;
