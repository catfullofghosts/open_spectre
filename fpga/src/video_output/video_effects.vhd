library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Pipeline (registered stages for timing):
--   color stage1/2 (+2) -> mirror BRAM (+1) -> logic prev (+1)
--   -> chromatic (+1) -> emboss/shadow (+4)
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
--   [8]     scanline effect enable (selected lines delayed)
--   [12:11] logic with previous pixel: 01=OR, 10=AND, 11=XOR, 00=off
--   [17:13] scanline delay 0-16 pixels
--   [19]    CRT darken (every other line at half brightness)
--   [22:20] scanline band: 000=1 line, 001=2, 010=4, 011=8, 100=16
--   [29:23] smear repeat 0-64 (0 = off). A channel over its threshold is
--           repeated that many pixels. Thresholds live in fx_dither.
--
-- video_fx_bitplane @ 0xE8 — per channel (R/G/B), 4 bits each:
--   [3]    1=bypass (full 8-bit), 0=slice selected bit plane
--   [2:0]  bit index 0 (LSB) .. 7 (MSB); replicated to 0x00 / 0xFF
--   [15:12] R rotate, [19:16] G rotate, [23:20] B rotate
--           0 = none, 1-7 = left (toward MSB), 8-14 = right by 1-7. Wrap. Applied first.
--
-- video_fx_dither @ 0xEC — horizontal ordered dither (no line memory):
--   [0]    1=enable, 0=bypass
--   [2:1]  depth: 00=6-bit, 01=5-bit, 10=4-bit, 11=3-bit output per channel
--   [5:3]  posterize: 000=off, 001=7-bit, 010=6, 011=5, 100=4, 101=3, 110=2, 111=1
--   [13:6]  smear threshold R, [21:14] G, [29:22] B (smear when channel is above)
--
-- video_fx_mirror @ 0xF0 — horizontal mirror (half-line BRAM, no full frame):
--   [0]      1=enable, 0=bypass
--   [11:1]   half-line width in pixels (active half stored, second half reads reversed)
--            mirror region spans 2 * half_width pixels; default half=360 (720-wide line)
--
-- video_fx_chromatic @ 0xF4 — RGB channel delay (chromatic aberration):
--   [0]    1=enable
--   [6:1]  green delay 0-32 pixels
--   [12:7] blue delay 0-32 pixels (red undelayed)
--
-- video_fx_emboss @ 0xF8 — horizontal luma edge relief:
--   [0]     1=emboss (rising luma: brighten 5 px)
--   [1]     1=shadow (falling luma: darken 5 px)
--   [15:8]  delta threshold (1-255, a stored 0 is treated as 1)
--   [23:16] add/sub strength (1-255, a stored 0 is treated as 1)
--   [24]    1=color fringe (emboss edge painted, not whitened)
--   [28:25] fringe color 0-15 (black, grey, white, then hues)

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
    fx_emboss       : in  std_logic_vector(31 downto 0);
    video_out       : out std_logic_vector(23 downto 0)
  );
end entity video_effects;

architecture rtl of video_effects is

  -- 960 covers 1080p half-line (1920/2). One BRAM36.
  constant C_MAX_HALF : positive := 960;

  type t_half_line_buf is array (0 to C_MAX_HALF - 1) of std_logic_vector(23 downto 0);

  signal fx_ctrl_r     : std_logic_vector(31 downto 0);
  signal fx_bitplane_r : std_logic_vector(31 downto 0);
  signal fx_dither_r   : std_logic_vector(31 downto 0);
  signal fx_mirror_r    : std_logic_vector(31 downto 0);
  signal fx_chromatic_r : std_logic_vector(31 downto 0);
  signal fx_emboss_r    : std_logic_vector(31 downto 0);

  signal de_active : std_logic;

  signal line_buf : t_half_line_buf;
  attribute ram_style : string;
  attribute ram_style of line_buf : signal is "block";

  signal h_sync_d  : std_logic;
  signal v_sync_d  : std_logic;
  signal line_idx  : unsigned(4 downto 0) := (others => '0');
  signal x_count   : unsigned(15 downto 0) := (others => '0');

  signal r_in  : std_logic_vector(7 downto 0);
  signal g_in  : std_logic_vector(7 downto 0);
  signal b_in  : std_logic_vector(7 downto 0);
  signal r_out : std_logic_vector(7 downto 0);
  signal g_out : std_logic_vector(7 downto 0);
  signal b_out : std_logic_vector(7 downto 0);

  signal pixel_proc     : std_logic_vector(23 downto 0);
  signal pixel_color_s1 : std_logic_vector(23 downto 0);
  signal pixel_mirrored : std_logic_vector(23 downto 0);
  signal pixel_prev     : std_logic_vector(23 downto 0) := (others => '0');
  signal pixel_logic    : std_logic_vector(23 downto 0);
  signal pixel_logic_r  : std_logic_vector(23 downto 0);
  signal pixel_filtered : std_logic_vector(23 downto 0);
  type t_scan_dly is array (0 to 15) of std_logic_vector(23 downto 0);
  signal scan_dly : t_scan_dly := (others => (others => '0'));
  signal smear_hold_r : unsigned(7 downto 0) := (others => '0');
  signal smear_hold_g : unsigned(7 downto 0) := (others => '0');
  signal smear_hold_b : unsigned(7 downto 0) := (others => '0');
  signal smear_left_r : unsigned(6 downto 0) := (others => '0');
  signal smear_left_g : unsigned(6 downto 0) := (others => '0');
  signal smear_left_b : unsigned(6 downto 0) := (others => '0');

  signal r_post_logic : std_logic_vector(7 downto 0);
  signal g_post_logic : std_logic_vector(7 downto 0);
  signal b_post_logic : std_logic_vector(7 downto 0);
  signal r_chrom      : std_logic_vector(7 downto 0);
  signal g_chrom      : std_logic_vector(7 downto 0);
  signal b_chrom      : std_logic_vector(7 downto 0);
  signal r_edge       : std_logic_vector(7 downto 0);
  signal g_edge       : std_logic_vector(7 downto 0);
  signal b_edge       : std_logic_vector(7 downto 0);
  signal fringe_rgb   : std_logic_vector(23 downto 0);

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

  function f_posterize (
    v    : std_logic_vector(7 downto 0);
    mode : std_logic_vector(2 downto 0)
  ) return std_logic_vector is
    variable bits  : integer;
    variable shift : integer;
    variable q     : unsigned(7 downto 0);
  begin
    if mode = "000" then
      return v;
    end if;
    bits := 8 - to_integer(unsigned(mode));
    shift := 8 - bits;
    q := shift_left(shift_right(unsigned(v), shift), shift);
    q := q or shift_right(q, bits);
    q := q or shift_right(q, bits * 2);
    q := q or shift_right(q, bits * 4);
    return std_logic_vector(q);
  end function f_posterize;

  -- 0 = unchanged. 1-7 rotates toward the MSB. 8-14 rotates toward the LSB by 1-7.
  function f_rot_byte (
    b    : std_logic_vector(7 downto 0);
    code : std_logic_vector(3 downto 0)
  ) return std_logic_vector is
    variable n : integer;
    variable u : unsigned(7 downto 0);
  begin
    n := to_integer(unsigned(code));
    if (n = 0) or (n > 14) then
      return b;
    end if;
    u := unsigned(b);
    if n <= 7 then
      return std_logic_vector(rotate_left(u, n));
    end if;
    return std_logic_vector(rotate_right(u, n - 7));
  end function f_rot_byte;

  -- R in [7:0], G in [15:8], B in [23:16].
  function f_fringe_rgb (idx : std_logic_vector(3 downto 0)) return std_logic_vector is
  begin
    case idx is
      when x"0" => return x"000000"; -- black
      when x"1" => return x"808080"; -- grey
      when x"2" => return x"FFFFFF"; -- white
      when x"3" => return x"0000FF"; -- red
      when x"4" => return x"00FF00"; -- green
      when x"5" => return x"FF0000"; -- blue
      when x"6" => return x"00FFFF"; -- yellow
      when x"7" => return x"FFFF00"; -- cyan
      when x"8" => return x"FF00FF"; -- magenta
      when x"9" => return x"0080FF"; -- orange
      when x"A" => return x"8040FF"; -- rose
      when x"B" => return x"FF0080"; -- purple
      when x"C" => return x"00FF80"; -- lime
      when x"D" => return x"808000"; -- teal
      when x"E" => return x"004080"; -- brown
      when others => return x"404040"; -- dark grey
    end case;
  end function f_fringe_rgb;

  function f_scan_band (
    idx  : unsigned(4 downto 0);
    mode : std_logic_vector(2 downto 0)
  ) return std_logic is
  begin
    case mode is
      when "001" => return idx(1);
      when "010" => return idx(2);
      when "011" => return idx(3);
      when "100" => return idx(4);
      when "101" => return idx(4);
      when "110" => return idx(4);
      when "111" => return idx(4);
      when others => return idx(0);
    end case;
  end function f_scan_band;

  type t_smear_step is record
    pix  : std_logic_vector(7 downto 0);
    hold : unsigned(7 downto 0);
    left : unsigned(6 downto 0);
  end record;

  function f_smear_step (
    pix   : std_logic_vector(7 downto 0);
    thr   : unsigned(7 downto 0);
    hold  : unsigned(7 downto 0);
    left  : unsigned(6 downto 0);
    rep   : unsigned(6 downto 0);
    clear : std_logic
  ) return t_smear_step is
    variable s : t_smear_step;
  begin
    s.pix  := pix;
    s.hold := hold;
    s.left := left;
    if (clear = '1') or (rep = 0) then
      s.left := (others => '0');
      return s;
    end if;
    if unsigned(pix) > thr then
      s.hold := unsigned(pix);
      s.pix  := pix;
      if rep > 1 then
        s.left := rep - 1;
      else
        s.left := (others => '0');
      end if;
    elsif left /= 0 then
      s.pix  := std_logic_vector(hold);
      s.left := left - 1;
    end if;
    return s;
  end function f_smear_step;

  function f_crt_half (pix : std_logic_vector(23 downto 0)) return std_logic_vector is
  begin
    return '0' & pix(23 downto 17) & '0' & pix(15 downto 9) & '0' & pix(7 downto 1);
  end function f_crt_half;

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
      fx_emboss_r    <= fx_emboss;

      if rst = '1' then
        line_idx <= (others => '0');
        x_count  <= (others => '0');
      else
        if v_sync = '1' and v_sync_d = '0' then
          line_idx <= (others => '0');
        elsif h_sync = '1' and h_sync_d = '0' then
          line_idx <= line_idx + 1;
        end if;

        if h_sync = '1' and h_sync_d = '0' then
          x_count <= (others => '0');
        elsif h_sync = '0' then
          x_count <= x_count + 1;
        end if;
      end if;
    end if;
  end process p_sync;

  p_color_stage1 : process (clk) is
    variable vr, vg, vb : std_logic_vector(7 downto 0);
    variable packed       : std_logic_vector(23 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pixel_color_s1 <= (others => '0');
      else
        vr := f_rot_byte(r_in, fx_bitplane_r(15 downto 12));
        vg := f_rot_byte(g_in, fx_bitplane_r(19 downto 16));
        vb := f_rot_byte(b_in, fx_bitplane_r(23 downto 20));

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

        pixel_color_s1 <= vb & vg & vr;
      end if;
    end if;
  end process p_color_stage1;

  p_color_stage2 : process (clk) is
    variable vr, vg, vb : std_logic_vector(7 downto 0);
    variable sr, sg, sb : t_smear_step;
    variable smear_rep  : unsigned(6 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        r_out <= (others => '0');
        g_out <= (others => '0');
        b_out <= (others => '0');
        smear_hold_r <= (others => '0');
        smear_hold_g <= (others => '0');
        smear_hold_b <= (others => '0');
        smear_left_r <= (others => '0');
        smear_left_g <= (others => '0');
        smear_left_b <= (others => '0');
      else
        vr := pixel_color_s1(7 downto 0);
        vg := pixel_color_s1(15 downto 8);
        vb := pixel_color_s1(23 downto 16);

        if fx_dither_r(5 downto 3) /= "000" then
          vr := f_posterize(vr, fx_dither_r(5 downto 3));
          vg := f_posterize(vg, fx_dither_r(5 downto 3));
          vb := f_posterize(vb, fx_dither_r(5 downto 3));
        end if;

        if fx_dither_r(0) = '1' then
          vr := f_horiz_dither(vr, x_count(1 downto 0), fx_dither_r(2 downto 1));
          vg := f_horiz_dither(vg, x_count(1 downto 0), fx_dither_r(2 downto 1));
          vb := f_horiz_dither(vb, x_count(1 downto 0), fx_dither_r(2 downto 1));
        end if;

        smear_rep := unsigned(fx_ctrl_r(29 downto 23));
        if smear_rep > 64 then
          smear_rep := to_unsigned(64, smear_rep'length);
        end if;
        sr := f_smear_step(vr, unsigned(fx_dither_r(13 downto 6)),
                           smear_hold_r, smear_left_r, smear_rep, h_sync);
        sg := f_smear_step(vg, unsigned(fx_dither_r(21 downto 14)),
                           smear_hold_g, smear_left_g, smear_rep, h_sync);
        sb := f_smear_step(vb, unsigned(fx_dither_r(29 downto 22)),
                           smear_hold_b, smear_left_b, smear_rep, h_sync);
        vr := sr.pix;
        vg := sg.pix;
        vb := sb.pix;
        smear_hold_r <= sr.hold;
        smear_hold_g <= sg.hold;
        smear_hold_b <= sb.hold;
        smear_left_r <= sr.left;
        smear_left_g <= sg.left;
        smear_left_b <= sb.left;

        r_out <= vr;
        g_out <= vg;
        b_out <= vb;
      end if;
    end if;
  end process p_color_stage2;

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

  p_logic_reg : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pixel_logic_r <= (others => '0');
      else
        pixel_logic_r <= pixel_logic;
      end if;
    end if;
  end process p_logic_reg;

  r_post_logic <= pixel_logic_r(7 downto 0);
  g_post_logic <= pixel_logic_r(15 downto 8);
  b_post_logic <= pixel_logic_r(23 downto 16);

  chromatic_inst : entity work.chromatic_abrasion_effect
    port map (
      clk       => clk,
      rst       => rst,
      enable    => fx_chromatic_r(0),
      delay_g   => fx_chromatic_r(6 downto 1),
      delay_b   => fx_chromatic_r(12 downto 7),
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

  fringe_rgb <= f_fringe_rgb(fx_emboss_r(28 downto 25));

  emboss_shadow_inst : entity work.emboss_shadow_effect
    port map (
      clk        => clk,
      rst        => rst,
      emboss_en  => fx_emboss_r(0),
      shadow_en  => fx_emboss_r(1),
      threshold  => fx_emboss_r(15 downto 8),
      strength   => fx_emboss_r(23 downto 16),
      fringe_en  => fx_emboss_r(24),
      fringe_r   => fringe_rgb(7 downto 0),
      fringe_g   => fringe_rgb(15 downto 8),
      fringe_b   => fringe_rgb(23 downto 16),
      r_in       => r_chrom,
      g_in       => g_chrom,
      b_in       => b_chrom,
      hsync_in   => h_sync,
      de_in      => de_active,
      r_out      => r_edge,
      g_out      => g_edge,
      b_out      => b_edge
    );

  pixel_filtered <= b_edge & g_edge & r_edge;

  p_output : process (clk) is
    variable v_scan : integer;
    variable v_pix  : std_logic_vector(23 downto 0);
  begin
    if rising_edge(clk) then
      if h_sync = '1' and h_sync_d = '0' then
        pixel_prev <= (others => '0');
      else
        pixel_prev <= pixel_mirrored;
      end if;

      scan_dly(0) <= pixel_filtered;
      for i in 1 to 15 loop
        scan_dly(i) <= scan_dly(i - 1);
      end loop;

      v_pix := pixel_filtered;
      if fx_ctrl_r(8) = '1' and f_scan_band(line_idx, fx_ctrl_r(22 downto 20)) = '1' then
        v_scan := to_integer(unsigned(fx_ctrl_r(17 downto 13)));
        if v_scan <= 0 then
          v_pix := pixel_filtered;
        elsif v_scan >= 16 then
          v_pix := scan_dly(15);
        else
          v_pix := scan_dly(v_scan - 1);
        end if;
      end if;

      if fx_ctrl_r(19) = '1' and line_idx(0) = '1' then
        v_pix := f_crt_half(v_pix);
      end if;
      video_out <= v_pix;
    end if;
  end process p_output;

end architecture rtl;
