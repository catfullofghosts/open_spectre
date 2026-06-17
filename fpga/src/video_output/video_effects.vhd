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

entity video_effects is
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    h_sync       : in  std_logic;
    v_sync       : in  std_logic;
    video_in     : in  std_logic_vector(23 downto 0);
    fx_ctrl      : in  std_logic_vector(31 downto 0);
    fx_bitplane  : in  std_logic_vector(31 downto 0);
    video_out    : out std_logic_vector(23 downto 0)
  );
end entity video_effects;

architecture rtl of video_effects is

  signal fx_ctrl_r     : std_logic_vector(31 downto 0);
  signal fx_bitplane_r : std_logic_vector(31 downto 0);

  signal h_sync_d  : std_logic;
  signal v_sync_d  : std_logic;
  signal line_odd  : std_logic := '0';

  signal r_in  : std_logic_vector(7 downto 0);
  signal g_in  : std_logic_vector(7 downto 0);
  signal b_in  : std_logic_vector(7 downto 0);
  signal r_out : std_logic_vector(7 downto 0);
  signal g_out : std_logic_vector(7 downto 0);
  signal b_out : std_logic_vector(7 downto 0);

  signal pixel_proc  : std_logic_vector(23 downto 0);
  signal pixel_prev  : std_logic_vector(23 downto 0) := (others => '0');
  signal pixel_logic : std_logic_vector(23 downto 0);
  signal pixel_d1    : std_logic_vector(23 downto 0);
  signal pixel_d2    : std_logic_vector(23 downto 0);

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

begin

  r_in <= video_in(7 downto 0);
  g_in <= video_in(15 downto 8);
  b_in <= video_in(23 downto 16);

  p_sync : process (clk) is
  begin
    if rising_edge(clk) then
      h_sync_d  <= h_sync;
      v_sync_d  <= v_sync;
      fx_ctrl_r     <= fx_ctrl;
      fx_bitplane_r <= fx_bitplane;

      if rst = '1' then
        line_odd <= '0';
      else
        if v_sync = '1' and v_sync_d = '0' then
          line_odd <= '0';
        elsif h_sync = '1' and h_sync_d = '0' then
          line_odd <= not line_odd;
        end if;
      end if;
    end if;
  end process p_sync;

  p_color : process (r_in, g_in, b_in, fx_ctrl_r, fx_bitplane_r)
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

    r_out <= vr;
    g_out <= vg;
    b_out <= vb;
  end process p_color;

  pixel_proc <= b_out & g_out & r_out;

  pixel_logic <= f_logic_prev(pixel_proc, pixel_prev, fx_ctrl_r(12 downto 11));

  p_output : process (clk) is
  begin
    if rising_edge(clk) then
      if h_sync = '1' and h_sync_d = '0' then
        pixel_prev <= (others => '0');
      else
        pixel_prev <= pixel_proc;
      end if;

      pixel_d1 <= pixel_logic;
      pixel_d2 <= pixel_d1;

      if fx_ctrl_r(8) = '1' and line_odd = '1' then
        case fx_ctrl_r(10 downto 9) is
          when "01"   => video_out <= pixel_d1;
          when "10"   => video_out <= pixel_d2;
          when others => video_out <= pixel_logic;
        end case;
      else
        video_out <= pixel_logic;
      end if;
    end if;
  end process p_output;

end architecture rtl;
