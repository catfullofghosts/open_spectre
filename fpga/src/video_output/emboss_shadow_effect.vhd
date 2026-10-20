library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Horizontal luma-edge relief. No line memory, no divides.
--   emboss: large rising luma  -> brighten this pixel and the next 4 (5 total)
--   shadow: large falling luma -> darken this pixel and the next 4 (5 total)
-- Pipelined: luma (1) -> detect/apply (1). Safe at 720p / 1080p pixel clocks.

entity emboss_shadow_effect is
  port (
    clk         : in  std_logic;
    rst         : in  std_logic;
    emboss_en   : in  std_logic;
    shadow_en   : in  std_logic;
    threshold   : in  std_logic_vector(7 downto 0);
    strength    : in  std_logic_vector(7 downto 0);
    fringe_en   : in  std_logic;
    fringe_r    : in  std_logic_vector(7 downto 0);
    fringe_g    : in  std_logic_vector(7 downto 0);
    fringe_b    : in  std_logic_vector(7 downto 0);
    r_in        : in  std_logic_vector(7 downto 0);
    g_in        : in  std_logic_vector(7 downto 0);
    b_in        : in  std_logic_vector(7 downto 0);
    hsync_in    : in  std_logic;
    de_in       : in  std_logic;
    r_out       : out std_logic_vector(7 downto 0);
    g_out       : out std_logic_vector(7 downto 0);
    b_out       : out std_logic_vector(7 downto 0)
  );
end entity emboss_shadow_effect;

architecture rtl of emboss_shadow_effect is

  constant C_STREAK : unsigned(2 downto 0) := to_unsigned(5, 3);
  constant C_DEF_THR : unsigned(7 downto 0) := to_unsigned(32, 8);
  constant C_DEF_STR : unsigned(7 downto 0) := to_unsigned(80, 8);

  signal r_d     : unsigned(7 downto 0) := (others => '0');
  signal g_d     : unsigned(7 downto 0) := (others => '0');
  signal b_d     : unsigned(7 downto 0) := (others => '0');
  signal luma_d  : unsigned(7 downto 0) := (others => '0');
  signal de_d    : std_logic := '0';
  signal hsync_d : std_logic := '0';

  signal luma_prev    : unsigned(7 downto 0) := (others => '0');
  signal emboss_left  : unsigned(2 downto 0) := (others => '0');
  signal shadow_left  : unsigned(2 downto 0) := (others => '0');
  signal line_start   : std_logic := '1';

  function f_sat_add (v, amt : unsigned(7 downto 0)) return unsigned is
    variable s : unsigned(8 downto 0);
  begin
    s := resize(v, 9) + resize(amt, 9);
    if s(8) = '1' then
      return to_unsigned(255, 8);
    end if;
    return s(7 downto 0);
  end function f_sat_add;

  function f_sat_sub (v, amt : unsigned(7 downto 0)) return unsigned is
  begin
    if v < amt then
      return to_unsigned(0, 8);
    end if;
    return v - amt;
  end function f_sat_sub;

  -- out = pix + (color - pix) * amt / 256, clamped.
  function f_mix (pix, col, amt : unsigned(7 downto 0)) return unsigned is
    variable diff : signed(9 downto 0);
    variable prod : signed(18 downto 0);
    variable sum  : signed(10 downto 0);
  begin
    diff := signed(resize(col, 10)) - signed(resize(pix, 10));
    prod := diff * signed(resize(amt, 9));
    sum  := signed(resize(pix, 11)) + resize(prod(18 downto 8), 11);
    if sum < 0 then
      return to_unsigned(0, 8);
    elsif sum > 255 then
      return to_unsigned(255, 8);
    else
      return unsigned(sum(7 downto 0));
    end if;
  end function f_mix;

begin

  p_luma : process (clk) is
    variable sum : unsigned(9 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        r_d     <= (others => '0');
        g_d     <= (others => '0');
        b_d     <= (others => '0');
        luma_d  <= (others => '0');
        de_d    <= '0';
        hsync_d <= '0';
      else
        r_d     <= unsigned(r_in);
        g_d     <= unsigned(g_in);
        b_d     <= unsigned(b_in);
        de_d    <= de_in;
        hsync_d <= hsync_in;
        -- Cheap luma: (R + 2G + B) / 4
        sum := resize(unsigned(r_in), 10) +
               resize(unsigned(g_in), 10) +
               resize(unsigned(g_in), 10) +
               resize(unsigned(b_in), 10);
        luma_d <= sum(9 downto 2);
      end if;
    end if;
  end process p_luma;

  p_edge : process (clk) is
    variable thr   : unsigned(7 downto 0);
    variable str   : unsigned(7 downto 0);
    variable delta : signed(8 downto 0);
    variable e_cnt : unsigned(2 downto 0);
    variable s_cnt : unsigned(2 downto 0);
    variable vr    : unsigned(7 downto 0);
    variable vg    : unsigned(7 downto 0);
    variable vb    : unsigned(7 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        luma_prev   <= (others => '0');
        emboss_left <= (others => '0');
        shadow_left <= (others => '0');
        line_start  <= '1';
        r_out       <= (others => '0');
        g_out       <= (others => '0');
        b_out       <= (others => '0');
      else
        if unsigned(threshold) = 0 then
          thr := C_DEF_THR;
        else
          thr := unsigned(threshold);
        end if;
        if unsigned(strength) = 0 then
          str := C_DEF_STR;
        else
          str := unsigned(strength);
        end if;

        vr := r_d;
        vg := g_d;
        vb := b_d;
        e_cnt := emboss_left;
        s_cnt := shadow_left;

        if hsync_d = '1' then
          luma_prev   <= (others => '0');
          emboss_left <= (others => '0');
          shadow_left <= (others => '0');
          line_start  <= '1';
          r_out       <= std_logic_vector(r_d);
          g_out       <= std_logic_vector(g_d);
          b_out       <= std_logic_vector(b_d);
        elsif de_d = '1' then
          delta := signed(resize(luma_d, 9)) - signed(resize(luma_prev, 9));

          if line_start = '0' then
            if ((emboss_en = '1') or (fringe_en = '1')) and (delta > signed(resize(thr, 9))) then
              e_cnt := C_STREAK;
            end if;
            if (shadow_en = '1') and (delta < -signed(resize(thr, 9))) then
              s_cnt := C_STREAK;
            end if;
          end if;

          if e_cnt /= 0 then
            if fringe_en = '1' then
              vr := f_mix(vr, unsigned(fringe_r), str);
              vg := f_mix(vg, unsigned(fringe_g), str);
              vb := f_mix(vb, unsigned(fringe_b), str);
            else
              vr := f_sat_add(vr, str);
              vg := f_sat_add(vg, str);
              vb := f_sat_add(vb, str);
            end if;
            e_cnt := e_cnt - 1;
          end if;
          if s_cnt /= 0 then
            vr := f_sat_sub(vr, str);
            vg := f_sat_sub(vg, str);
            vb := f_sat_sub(vb, str);
            s_cnt := s_cnt - 1;
          end if;

          luma_prev   <= luma_d;
          emboss_left <= e_cnt;
          shadow_left <= s_cnt;
          line_start  <= '0';
          r_out       <= std_logic_vector(vr);
          g_out       <= std_logic_vector(vg);
          b_out       <= std_logic_vector(vb);
        else
          r_out <= std_logic_vector(r_d);
          g_out <= std_logic_vector(g_d);
          b_out <= std_logic_vector(b_d);
        end if;
      end if;
    end if;
  end process p_edge;

end architecture rtl;
