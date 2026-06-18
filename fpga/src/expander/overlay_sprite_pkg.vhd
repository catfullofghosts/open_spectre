library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package overlay_sprite_pkg is

  constant C_NUM_SPRITES    : positive := 8;
  constant C_SPRITE_STRIDE  : positive := 16; -- bytes between sprite descriptors in reg map
  constant C_SPRITE_REG_LO  : std_logic_vector(12 downto 0) := std_logic_vector(to_unsigned(16#100#, 13));

  subtype t_coord is std_logic_vector(10 downto 0);

  type t_sprite_slot is record
    enable : std_logic;
    x      : t_coord;
    y      : t_coord;
    width  : t_coord;
    height : t_coord;
    base   : t_coord; -- word offset into shared overlay BRAM
  end record t_sprite_slot;

  type t_sprite_array is array (0 to C_NUM_SPRITES - 1) of t_sprite_slot;

end package overlay_sprite_pkg;
