library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Font and ink colours for char_gen.
-- ASCII 32..126 are an 8x8 picture, drawn doubled into the 16x16 cell.
-- Bit 15 of a font word is the left-hand pixel.
--
-- Building glyphs, full 16x16, centre-joined so neighbours meet:
--   80 horizontal   81 vertical
--   82 TL  83 TR  84 BL  85 BR
--   86 tee down  87 tee up  88 tee right  89 tee left  8A cross
--   90 left half  91 right half  92 top half  93 bottom half
--   94 TL quarter  95 TR  96 BL  97 BR
--   98 shade 25%  99 shade 50%  9A shade 75%
--   9B fill x>=y  9C fill y>=x  9D full block
--
-- Cell word: [7:0] character, [11:8] colour, [15:12] spare.
-- Colour 0 is not ink. The palette below is colours 1..15.
-- C_CHAR_LAT is the pixel delay of char_gen.

package char_font_pkg is
  constant C_CHAR_LAT : integer := 4;
  constant C_COLS     : integer := 80;
  constant C_ROWS     : integer := 45;
  constant C_FRAME_W  : integer := 1280;
  constant C_FRAME_H  : integer := 720;

  subtype t_word16 is std_logic_vector(15 downto 0);
  subtype t_rgb    is std_logic_vector(23 downto 0);
  type t_ram is array (0 to 4095) of t_word16;

  function f_font_word(addr : integer) return t_word16;
  function f_font_init return t_ram;
  function f_palette(c : std_logic_vector(3 downto 0)) return t_rgb;
end package char_font_pkg;

package body char_font_pkg is

  subtype t_byte is std_logic_vector(7 downto 0);

  function f_ascii8(ch : integer; row8 : integer) return t_byte is
  begin
    case ch is
      when 32 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"00";
          when 3 => return x"00";
          when 4 => return x"00";
          when 5 => return x"00";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 33 =>
        case row8 is
          when 0 => return x"10";
          when 1 => return x"10";
          when 2 => return x"10";
          when 3 => return x"10";
          when 4 => return x"10";
          when 5 => return x"00";
          when 6 => return x"10";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 34 =>
        case row8 is
          when 0 => return x"28";
          when 1 => return x"28";
          when 2 => return x"00";
          when 3 => return x"00";
          when 4 => return x"00";
          when 5 => return x"00";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 35 =>
        case row8 is
          when 0 => return x"28";
          when 1 => return x"7C";
          when 2 => return x"28";
          when 3 => return x"7C";
          when 4 => return x"28";
          when 5 => return x"00";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 36 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"50";
          when 2 => return x"38";
          when 3 => return x"14";
          when 4 => return x"38";
          when 5 => return x"10";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 37 =>
        case row8 is
          when 0 => return x"44";
          when 1 => return x"48";
          when 2 => return x"08";
          when 3 => return x"10";
          when 4 => return x"20";
          when 5 => return x"44";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 38 =>
        case row8 is
          when 0 => return x"30";
          when 1 => return x"48";
          when 2 => return x"30";
          when 3 => return x"54";
          when 4 => return x"34";
          when 5 => return x"00";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 39 =>
        case row8 is
          when 0 => return x"10";
          when 1 => return x"10";
          when 2 => return x"00";
          when 3 => return x"00";
          when 4 => return x"00";
          when 5 => return x"00";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 40 =>
        case row8 is
          when 0 => return x"08";
          when 1 => return x"10";
          when 2 => return x"20";
          when 3 => return x"20";
          when 4 => return x"20";
          when 5 => return x"10";
          when 6 => return x"08";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 41 =>
        case row8 is
          when 0 => return x"20";
          when 1 => return x"10";
          when 2 => return x"08";
          when 3 => return x"08";
          when 4 => return x"08";
          when 5 => return x"10";
          when 6 => return x"20";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 42 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"28";
          when 2 => return x"10";
          when 3 => return x"7C";
          when 4 => return x"10";
          when 5 => return x"28";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 43 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"10";
          when 2 => return x"10";
          when 3 => return x"7C";
          when 4 => return x"10";
          when 5 => return x"10";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 44 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"00";
          when 3 => return x"00";
          when 4 => return x"10";
          when 5 => return x"10";
          when 6 => return x"20";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 45 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"00";
          when 3 => return x"7C";
          when 4 => return x"00";
          when 5 => return x"00";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 46 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"00";
          when 3 => return x"00";
          when 4 => return x"00";
          when 5 => return x"18";
          when 6 => return x"18";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 47 =>
        case row8 is
          when 0 => return x"08";
          when 1 => return x"08";
          when 2 => return x"10";
          when 3 => return x"10";
          when 4 => return x"20";
          when 5 => return x"20";
          when 6 => return x"40";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 48 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"4C";
          when 3 => return x"54";
          when 4 => return x"64";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 49 =>
        case row8 is
          when 0 => return x"10";
          when 1 => return x"30";
          when 2 => return x"10";
          when 3 => return x"10";
          when 4 => return x"10";
          when 5 => return x"10";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 50 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"04";
          when 3 => return x"18";
          when 4 => return x"20";
          when 5 => return x"40";
          when 6 => return x"7C";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 51 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"04";
          when 3 => return x"18";
          when 4 => return x"04";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 52 =>
        case row8 is
          when 0 => return x"08";
          when 1 => return x"18";
          when 2 => return x"28";
          when 3 => return x"48";
          when 4 => return x"7C";
          when 5 => return x"08";
          when 6 => return x"08";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 53 =>
        case row8 is
          when 0 => return x"7C";
          when 1 => return x"40";
          when 2 => return x"78";
          when 3 => return x"04";
          when 4 => return x"04";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 54 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"40";
          when 2 => return x"40";
          when 3 => return x"78";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 55 =>
        case row8 is
          when 0 => return x"7C";
          when 1 => return x"04";
          when 2 => return x"08";
          when 3 => return x"10";
          when 4 => return x"20";
          when 5 => return x"20";
          when 6 => return x"20";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 56 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"38";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 57 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"3C";
          when 4 => return x"04";
          when 5 => return x"04";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 58 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"10";
          when 2 => return x"00";
          when 3 => return x"00";
          when 4 => return x"10";
          when 5 => return x"00";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 59 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"10";
          when 2 => return x"00";
          when 3 => return x"00";
          when 4 => return x"10";
          when 5 => return x"10";
          when 6 => return x"20";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 60 =>
        case row8 is
          when 0 => return x"08";
          when 1 => return x"10";
          when 2 => return x"20";
          when 3 => return x"40";
          when 4 => return x"20";
          when 5 => return x"10";
          when 6 => return x"08";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 61 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"7C";
          when 3 => return x"00";
          when 4 => return x"7C";
          when 5 => return x"00";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 62 =>
        case row8 is
          when 0 => return x"20";
          when 1 => return x"10";
          when 2 => return x"08";
          when 3 => return x"04";
          when 4 => return x"08";
          when 5 => return x"10";
          when 6 => return x"20";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 63 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"04";
          when 3 => return x"18";
          when 4 => return x"10";
          when 5 => return x"00";
          when 6 => return x"10";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 64 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"5C";
          when 3 => return x"54";
          when 4 => return x"58";
          when 5 => return x"40";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 65 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"7C";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"44";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 66 =>
        case row8 is
          when 0 => return x"78";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"78";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"78";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 67 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"40";
          when 3 => return x"40";
          when 4 => return x"40";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 68 =>
        case row8 is
          when 0 => return x"78";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"44";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"78";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 69 =>
        case row8 is
          when 0 => return x"7C";
          when 1 => return x"40";
          when 2 => return x"40";
          when 3 => return x"78";
          when 4 => return x"40";
          when 5 => return x"40";
          when 6 => return x"7C";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 70 =>
        case row8 is
          when 0 => return x"7C";
          when 1 => return x"40";
          when 2 => return x"40";
          when 3 => return x"78";
          when 4 => return x"40";
          when 5 => return x"40";
          when 6 => return x"40";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 71 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"40";
          when 3 => return x"5C";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 72 =>
        case row8 is
          when 0 => return x"44";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"7C";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"44";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 73 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"10";
          when 2 => return x"10";
          when 3 => return x"10";
          when 4 => return x"10";
          when 5 => return x"10";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 74 =>
        case row8 is
          when 0 => return x"1C";
          when 1 => return x"08";
          when 2 => return x"08";
          when 3 => return x"08";
          when 4 => return x"48";
          when 5 => return x"48";
          when 6 => return x"30";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 75 =>
        case row8 is
          when 0 => return x"44";
          when 1 => return x"48";
          when 2 => return x"50";
          when 3 => return x"60";
          when 4 => return x"50";
          when 5 => return x"48";
          when 6 => return x"44";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 76 =>
        case row8 is
          when 0 => return x"40";
          when 1 => return x"40";
          when 2 => return x"40";
          when 3 => return x"40";
          when 4 => return x"40";
          when 5 => return x"40";
          when 6 => return x"7C";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 77 =>
        case row8 is
          when 0 => return x"82";
          when 1 => return x"C6";
          when 2 => return x"AA";
          when 3 => return x"92";
          when 4 => return x"82";
          when 5 => return x"82";
          when 6 => return x"82";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 78 =>
        case row8 is
          when 0 => return x"44";
          when 1 => return x"64";
          when 2 => return x"54";
          when 3 => return x"4C";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"44";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 79 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"44";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 80 =>
        case row8 is
          when 0 => return x"78";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"78";
          when 4 => return x"40";
          when 5 => return x"40";
          when 6 => return x"40";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 81 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"44";
          when 4 => return x"54";
          when 5 => return x"48";
          when 6 => return x"34";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 82 =>
        case row8 is
          when 0 => return x"78";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"78";
          when 4 => return x"50";
          when 5 => return x"48";
          when 6 => return x"44";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 83 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"44";
          when 2 => return x"40";
          when 3 => return x"38";
          when 4 => return x"04";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 84 =>
        case row8 is
          when 0 => return x"7C";
          when 1 => return x"10";
          when 2 => return x"10";
          when 3 => return x"10";
          when 4 => return x"10";
          when 5 => return x"10";
          when 6 => return x"10";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 85 =>
        case row8 is
          when 0 => return x"44";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"44";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 86 =>
        case row8 is
          when 0 => return x"44";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"44";
          when 4 => return x"28";
          when 5 => return x"28";
          when 6 => return x"10";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 87 =>
        case row8 is
          when 0 => return x"82";
          when 1 => return x"82";
          when 2 => return x"82";
          when 3 => return x"92";
          when 4 => return x"AA";
          when 5 => return x"C6";
          when 6 => return x"82";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 88 =>
        case row8 is
          when 0 => return x"44";
          when 1 => return x"44";
          when 2 => return x"28";
          when 3 => return x"10";
          when 4 => return x"28";
          when 5 => return x"44";
          when 6 => return x"44";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 89 =>
        case row8 is
          when 0 => return x"44";
          when 1 => return x"44";
          when 2 => return x"28";
          when 3 => return x"10";
          when 4 => return x"10";
          when 5 => return x"10";
          when 6 => return x"10";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 90 =>
        case row8 is
          when 0 => return x"7C";
          when 1 => return x"04";
          when 2 => return x"08";
          when 3 => return x"10";
          when 4 => return x"20";
          when 5 => return x"40";
          when 6 => return x"7C";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 91 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"20";
          when 2 => return x"20";
          when 3 => return x"20";
          when 4 => return x"20";
          when 5 => return x"20";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 92 =>
        case row8 is
          when 0 => return x"40";
          when 1 => return x"20";
          when 2 => return x"20";
          when 3 => return x"10";
          when 4 => return x"10";
          when 5 => return x"08";
          when 6 => return x"08";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 93 =>
        case row8 is
          when 0 => return x"38";
          when 1 => return x"08";
          when 2 => return x"08";
          when 3 => return x"08";
          when 4 => return x"08";
          when 5 => return x"08";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 94 =>
        case row8 is
          when 0 => return x"10";
          when 1 => return x"28";
          when 2 => return x"44";
          when 3 => return x"00";
          when 4 => return x"00";
          when 5 => return x"00";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 95 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"00";
          when 3 => return x"00";
          when 4 => return x"00";
          when 5 => return x"00";
          when 6 => return x"7C";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 96 =>
        case row8 is
          when 0 => return x"20";
          when 1 => return x"10";
          when 2 => return x"00";
          when 3 => return x"00";
          when 4 => return x"00";
          when 5 => return x"00";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 97 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"38";
          when 3 => return x"04";
          when 4 => return x"3C";
          when 5 => return x"44";
          when 6 => return x"3C";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 98 =>
        case row8 is
          when 0 => return x"40";
          when 1 => return x"40";
          when 2 => return x"78";
          when 3 => return x"44";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"78";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 99 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"38";
          when 3 => return x"40";
          when 4 => return x"40";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 100 =>
        case row8 is
          when 0 => return x"04";
          when 1 => return x"04";
          when 2 => return x"3C";
          when 3 => return x"44";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"3C";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 101 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"38";
          when 3 => return x"44";
          when 4 => return x"7C";
          when 5 => return x"40";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 102 =>
        case row8 is
          when 0 => return x"18";
          when 1 => return x"24";
          when 2 => return x"20";
          when 3 => return x"70";
          when 4 => return x"20";
          when 5 => return x"20";
          when 6 => return x"20";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 103 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"3C";
          when 2 => return x"44";
          when 3 => return x"44";
          when 4 => return x"3C";
          when 5 => return x"04";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 104 =>
        case row8 is
          when 0 => return x"40";
          when 1 => return x"40";
          when 2 => return x"78";
          when 3 => return x"44";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"44";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 105 =>
        case row8 is
          when 0 => return x"10";
          when 1 => return x"00";
          when 2 => return x"10";
          when 3 => return x"10";
          when 4 => return x"10";
          when 5 => return x"10";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 106 =>
        case row8 is
          when 0 => return x"08";
          when 1 => return x"00";
          when 2 => return x"08";
          when 3 => return x"08";
          when 4 => return x"08";
          when 5 => return x"48";
          when 6 => return x"30";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 107 =>
        case row8 is
          when 0 => return x"40";
          when 1 => return x"40";
          when 2 => return x"48";
          when 3 => return x"50";
          when 4 => return x"60";
          when 5 => return x"50";
          when 6 => return x"48";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 108 =>
        case row8 is
          when 0 => return x"20";
          when 1 => return x"20";
          when 2 => return x"20";
          when 3 => return x"20";
          when 4 => return x"20";
          when 5 => return x"24";
          when 6 => return x"18";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 109 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"D4";
          when 3 => return x"AA";
          when 4 => return x"AA";
          when 5 => return x"AA";
          when 6 => return x"82";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 110 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"78";
          when 3 => return x"44";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"44";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 111 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"38";
          when 3 => return x"44";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 112 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"78";
          when 2 => return x"44";
          when 3 => return x"44";
          when 4 => return x"78";
          when 5 => return x"40";
          when 6 => return x"40";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 113 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"3C";
          when 2 => return x"44";
          when 3 => return x"44";
          when 4 => return x"3C";
          when 5 => return x"04";
          when 6 => return x"04";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 114 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"58";
          when 3 => return x"60";
          when 4 => return x"40";
          when 5 => return x"40";
          when 6 => return x"40";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 115 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"3C";
          when 3 => return x"40";
          when 4 => return x"38";
          when 5 => return x"04";
          when 6 => return x"78";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 116 =>
        case row8 is
          when 0 => return x"10";
          when 1 => return x"10";
          when 2 => return x"78";
          when 3 => return x"10";
          when 4 => return x"10";
          when 5 => return x"14";
          when 6 => return x"08";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 117 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"44";
          when 3 => return x"44";
          when 4 => return x"44";
          when 5 => return x"44";
          when 6 => return x"3C";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 118 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"44";
          when 3 => return x"44";
          when 4 => return x"44";
          when 5 => return x"28";
          when 6 => return x"10";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 119 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"82";
          when 3 => return x"82";
          when 4 => return x"92";
          when 5 => return x"AA";
          when 6 => return x"44";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 120 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"44";
          when 3 => return x"28";
          when 4 => return x"10";
          when 5 => return x"28";
          when 6 => return x"44";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 121 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"44";
          when 2 => return x"44";
          when 3 => return x"44";
          when 4 => return x"3C";
          when 5 => return x"04";
          when 6 => return x"38";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 122 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"7C";
          when 3 => return x"08";
          when 4 => return x"10";
          when 5 => return x"20";
          when 6 => return x"7C";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 123 =>
        case row8 is
          when 0 => return x"08";
          when 1 => return x"10";
          when 2 => return x"10";
          when 3 => return x"20";
          when 4 => return x"10";
          when 5 => return x"10";
          when 6 => return x"08";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 124 =>
        case row8 is
          when 0 => return x"10";
          when 1 => return x"10";
          when 2 => return x"10";
          when 3 => return x"10";
          when 4 => return x"10";
          when 5 => return x"10";
          when 6 => return x"10";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 125 =>
        case row8 is
          when 0 => return x"20";
          when 1 => return x"10";
          when 2 => return x"10";
          when 3 => return x"08";
          when 4 => return x"10";
          when 5 => return x"10";
          when 6 => return x"20";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when 126 =>
        case row8 is
          when 0 => return x"00";
          when 1 => return x"00";
          when 2 => return x"34";
          when 3 => return x"48";
          when 4 => return x"00";
          when 5 => return x"00";
          when 6 => return x"00";
          when 7 => return x"00";
          when others => return x"00";
        end case;
      when others =>
        return x"00";
    end case;
  end function f_ascii8;

  function f_double(b : t_byte) return t_word16 is
    variable r : t_word16;
  begin
    for i in 0 to 7 loop
      r(2 * i + 1) := b(i);
      r(2 * i)     := b(i);
    end loop;
    return r;
  end function f_double;

  function f_density(ch : integer; row : integer) return t_word16 is
    variable v    : std_logic;
    variable word : t_word16;
  begin
    word := (others => '0');
    for x in 0 to 15 loop
      v := '0';
      if ch = 16#98# then
        if ((x mod 2) = 0) and ((row mod 2) = 0) then
          v := '1';
        end if;
      elsif ch = 16#99# then
        if ((x + row) mod 2) = 0 then
          v := '1';
        end if;
      elsif ch = 16#9A# then
        if not (((x mod 2) = 1) and ((row mod 2) = 1)) then
          v := '1';
        end if;
      elsif ch = 16#9B# then
        if x >= row then
          v := '1';
        end if;
      elsif row >= x then
        v := '1';
      end if;
      word(15 - x) := v;
    end loop;
    return word;
  end function f_density;

  function f_shape_word(ch : integer; row : integer) return t_word16 is
  begin
    case ch is
      when 16#80# =>
        if (row = 7) or (row = 8) then
          return x"FFFF";
        end if;
        return x"0000";
      when 16#81# =>
        return x"0180";
      when 16#82# =>
        if row < 7 then
          return x"0000";
        elsif row < 9 then
          return x"01FF";
        end if;
        return x"0180";
      when 16#83# =>
        if row < 7 then
          return x"0000";
        elsif row < 9 then
          return x"FF80";
        end if;
        return x"0180";
      when 16#84# =>
        if row < 7 then
          return x"0180";
        elsif row < 9 then
          return x"01FF";
        end if;
        return x"0000";
      when 16#85# =>
        if row < 7 then
          return x"0180";
        elsif row < 9 then
          return x"FF80";
        end if;
        return x"0000";
      when 16#86# =>
        if (row = 7) or (row = 8) then
          return x"FFFF";
        elsif row > 8 then
          return x"0180";
        end if;
        return x"0000";
      when 16#87# =>
        if row < 7 then
          return x"0180";
        elsif row < 9 then
          return x"FFFF";
        end if;
        return x"0000";
      when 16#88# =>
        if (row = 7) or (row = 8) then
          return x"01FF";
        end if;
        return x"0180";
      when 16#89# =>
        if (row = 7) or (row = 8) then
          return x"FF80";
        end if;
        return x"0180";
      when 16#8A# =>
        if (row = 7) or (row = 8) then
          return x"FFFF";
        end if;
        return x"0180";
      when 16#90# =>
        return x"FF00";
      when 16#91# =>
        return x"00FF";
      when 16#92# =>
        if row < 8 then
          return x"FFFF";
        end if;
        return x"0000";
      when 16#93# =>
        if row >= 8 then
          return x"FFFF";
        end if;
        return x"0000";
      when 16#94# =>
        if row < 8 then
          return x"FF00";
        end if;
        return x"0000";
      when 16#95# =>
        if row < 8 then
          return x"00FF";
        end if;
        return x"0000";
      when 16#96# =>
        if row >= 8 then
          return x"FF00";
        end if;
        return x"0000";
      when 16#97# =>
        if row >= 8 then
          return x"00FF";
        end if;
        return x"0000";
      when 16#98# =>
        return f_density(ch, row);
      when 16#99# =>
        return f_density(ch, row);
      when 16#9A# =>
        return f_density(ch, row);
      when 16#9B# =>
        return f_density(ch, row);
      when 16#9C# =>
        return f_density(ch, row);
      when 16#9D# =>
        return x"FFFF";
      when others =>
        return x"0000";
    end case;
  end function f_shape_word;

  function f_font_word(addr : integer) return t_word16 is
    variable ch  : integer;
    variable row : integer;
  begin
    ch  := addr / 16;
    row := addr mod 16;
    if ch >= 128 then
      return f_shape_word(ch, row);
    end if;
    return f_double(f_ascii8(ch, row / 2));
  end function f_font_word;

  function f_font_init return t_ram is
    variable r : t_ram;
  begin
    for i in 0 to 4095 loop
      r(i) := f_font_word(i);
    end loop;
    return r;
  end function f_font_init;

  function f_palette(c : std_logic_vector(3 downto 0)) return t_rgb is
  begin
    case c is
      when "0001" => return x"FFFFFF";
      when "0010" => return x"000000";
      when "0011" => return x"0000FF";
      when "0100" => return x"00FF00";
      when "0101" => return x"FF0000";
      when "0110" => return x"00FFFF";
      when "0111" => return x"FFFF00";
      when "1000" => return x"FF00FF";
      when "1001" => return x"808080";
      when "1010" => return x"404040";
      when "1011" => return x"0080FF";
      when "1100" => return x"004080";
      when "1101" => return x"80FF80";
      when "1110" => return x"FF8080";
      when "1111" => return x"FF80FF";
      when others => return x"000000";
    end case;
  end function f_palette;

end package body char_font_pkg;

