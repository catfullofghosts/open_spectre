library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- One coordinate for every wipe. The soft-edge block turns it into a mix alpha.
--   coord small  -> B side of the wipe
--   coord large  -> A side of the wipe
--
-- mode:
--   0000 mix         (mix_mode = 1, coord unused)
--   0001 horizontal  (origin(0): 0 from the left, 1 from the right)
--   0010 vertical    (origin(0): 0 from the top, 1 from the bottom)
--   0011 square      chebyshev distance from an origin
--   0100 diagonal    straight diagonal edge
--   0101 diamond     |dx| + |dy| from an origin
--   0110 cross       min(|dx|, |dy|) from an origin (a plus)
--   0111 barn doors  distance from the centre line
--   1000 blinds      repeating band; position wipes inside each band
--
-- square, diamond and cross origin:
--   0 centre
--   1 north, 2 east, 3 south, 4 west
--   5 NE, 6 SE, 7 SW, 8 NW
--
-- diagonal origin:
--   0 from top-left, 1 from top-right, 2 from bottom-left, 3 from bottom-right
--
-- barn doors: origin(0) = 0 opens left/right, 1 opens up/down
--
-- blinds:
--   origin(1 downto 0): 00 = x, 01 = y, 10 = x+y, 11 = x+(height-1-y)
--   origin(3 downto 2): band size 00 = 4 px, 01 = 8, 10 = 16, 11 = 32

entity wipe_shape is
  port (
    x        : in  std_logic_vector(11 downto 0);
    y        : in  std_logic_vector(11 downto 0);
    frame_w  : in  std_logic_vector(11 downto 0);
    frame_h  : in  std_logic_vector(11 downto 0);
    mode     : in  std_logic_vector(3 downto 0);
    origin   : in  std_logic_vector(3 downto 0);
    coord    : out std_logic_vector(12 downto 0);
    mix_mode : out std_logic
  );
end entity wipe_shape;

architecture rtl of wipe_shape is

  subtype u13 is unsigned(12 downto 0);

  function f_lim (
    v   : unsigned(11 downto 0);
    lim : unsigned(11 downto 0)
  ) return unsigned is
  begin
    if lim = 0 then
      return to_unsigned(0, 12);
    elsif v >= lim then
      return lim - 1;
    else
      return v;
    end if;
  end function f_lim;

  function f_absdiff (
    a : unsigned(11 downto 0);
    b : unsigned(11 downto 0)
  ) return unsigned is
  begin
    if a >= b then
      return a - b;
    else
      return b - a;
    end if;
  end function f_absdiff;

  -- Power-of-two band: 4, 8, 16 or 32 pixels. Low bits are the modulus.
  function f_mod_band (
    v    : u13;
    code : std_logic_vector(1 downto 0)
  ) return u13 is
    variable m : u13;
  begin
    case code is
      when "01" =>
        m := to_unsigned(7, 13);
      when "10" =>
        m := to_unsigned(15, 13);
      when "11" =>
        m := to_unsigned(31, 13);
      when others =>
        m := to_unsigned(3, 13);
    end case;
    return v and m;
  end function f_mod_band;

  procedure p_place (
    code   : in  std_logic_vector(3 downto 0);
    wv     : in  unsigned(11 downto 0);
    hv     : in  unsigned(11 downto 0);
    ox     : out unsigned(11 downto 0);
    oy     : out unsigned(11 downto 0)
  ) is
  begin
    ox := shift_right(wv, 1);
    oy := shift_right(hv, 1);
    case code is
      when x"1" =>
        oy := (others => '0');
      when x"2" =>
        ox := wv - 1;
      when x"3" =>
        oy := hv - 1;
      when x"4" =>
        ox := (others => '0');
      when x"5" =>
        ox := wv - 1;
        oy := (others => '0');
      when x"6" =>
        ox := wv - 1;
        oy := hv - 1;
      when x"7" =>
        ox := (others => '0');
        oy := hv - 1;
      when x"8" =>
        ox := (others => '0');
        oy := (others => '0');
      when others =>
        null;
    end case;
  end procedure p_place;

begin

  p_shape : process (x, y, frame_w, frame_h, mode, origin) is
    variable xv  : unsigned(11 downto 0);
    variable yv  : unsigned(11 downto 0);
    variable wv  : unsigned(11 downto 0);
    variable hv  : unsigned(11 downto 0);
    variable ox  : unsigned(11 downto 0);
    variable oy  : unsigned(11 downto 0);
    variable dx  : unsigned(11 downto 0);
    variable dy  : unsigned(11 downto 0);
    variable acc : unsigned(12 downto 0);
  begin
    xv := unsigned(x);
    yv := unsigned(y);
    wv := unsigned(frame_w);
    hv := unsigned(frame_h);
    if wv = 0 then
      wv := to_unsigned(1, 12);
    end if;
    if hv = 0 then
      hv := to_unsigned(1, 12);
    end if;
    xv := f_lim(xv, wv);
    yv := f_lim(yv, hv);

    mix_mode <= '0';
    coord    <= (others => '0');

    case mode is
      when "0001" =>
        if origin(0) = '0' then
          coord <= '0' & std_logic_vector(xv);
        else
          coord <= '0' & std_logic_vector(wv - 1 - xv);
        end if;

      when "0010" =>
        if origin(0) = '0' then
          coord <= '0' & std_logic_vector(yv);
        else
          coord <= '0' & std_logic_vector(hv - 1 - yv);
        end if;

      when "0011" =>
        p_place(origin, wv, hv, ox, oy);
        dx := f_absdiff(xv, ox);
        dy := f_absdiff(yv, oy);
        if dx >= dy then
          coord <= '0' & std_logic_vector(dx);
        else
          coord <= '0' & std_logic_vector(dy);
        end if;

      when "0101" =>
        p_place(origin, wv, hv, ox, oy);
        dx := f_absdiff(xv, ox);
        dy := f_absdiff(yv, oy);
        coord <= std_logic_vector(resize(dx, 13) + resize(dy, 13));

      when "0110" =>
        p_place(origin, wv, hv, ox, oy);
        dx := f_absdiff(xv, ox);
        dy := f_absdiff(yv, oy);
        if dx <= dy then
          coord <= '0' & std_logic_vector(dx);
        else
          coord <= '0' & std_logic_vector(dy);
        end if;

      when "0111" =>
        if origin(0) = '0' then
          dx := f_absdiff(xv, shift_right(wv, 1));
          coord <= '0' & std_logic_vector(dx);
        else
          dy := f_absdiff(yv, shift_right(hv, 1));
          coord <= '0' & std_logic_vector(dy);
        end if;

      when "1000" =>
        case origin(1 downto 0) is
          when "01" =>
            acc := f_mod_band(resize(yv, 13), origin(3 downto 2));
          when "10" =>
            acc := f_mod_band(resize(xv, 13) + resize(yv, 13), origin(3 downto 2));
          when "11" =>
            acc := f_mod_band(
              resize(xv, 13) + resize(hv - 1 - yv, 13),
              origin(3 downto 2)
            );
          when others =>
            acc := f_mod_band(resize(xv, 13), origin(3 downto 2));
        end case;
        coord <= std_logic_vector(acc);

      when "0100" =>
        acc := (others => '0');
        case origin(1 downto 0) is
          when "01" =>
            acc := resize(wv - 1 - xv, 13) + resize(yv, 13);
          when "10" =>
            acc := resize(xv, 13) + resize(hv - 1 - yv, 13);
          when "11" =>
            acc := resize(wv - 1 - xv, 13) + resize(hv - 1 - yv, 13);
          when others =>
            acc := resize(xv, 13) + resize(yv, 13);
        end case;
        coord <= std_logic_vector(acc);

      when others =>
        mix_mode <= '1';
    end case;
  end process p_shape;

end architecture rtl;
