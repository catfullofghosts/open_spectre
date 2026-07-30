library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- XOR low-bit "dirt" from the analog-side noise generator into Y/U/V before
-- 12-to-8-bit export (y_result(11:4)).  Depth N XORs export LSBs y_result(4)
-- through y_result(4+N-1).  Bits 3:0 stay untouched.  Permuted noise picks:
-- Y=0,1,4  U=4,2,0,1  V=1,4,2,3 (first N entries used).

entity yuv_dirt is
  port (
    clk       : in  std_logic;
    noise     : in  std_logic_vector(4 downto 0);
    dirt_ctrl : in  std_logic_vector(4 downto 0);
    y_in      : in  std_logic_vector(11 downto 0);
    u_in      : in  std_logic_vector(11 downto 0);
    v_in      : in  std_logic_vector(11 downto 0);
    y_out     : out std_logic_vector(11 downto 0);
    u_out     : out std_logic_vector(11 downto 0);
    v_out     : out std_logic_vector(11 downto 0)
  );
end entity yuv_dirt;

architecture rtl of yuv_dirt is

  type dirt_map_t is array (0 to 3) of natural;

  constant C_Y_MAP : dirt_map_t := (0, 1, 4, 3);
  constant C_U_MAP : dirt_map_t := (4, 2, 0, 1);
  constant C_V_MAP : dirt_map_t := (1, 4, 2, 3);

  function f_pick (
    noise_vec : std_logic_vector(4 downto 0);
    idx       : natural
  ) return std_logic is
  begin
    return noise_vec(idx);
  end function f_pick;

  function f_dirt_bits (
    noise_vec : std_logic_vector(4 downto 0);
    map       : dirt_map_t;
    depth     : natural
  ) return std_logic_vector is
    variable r : std_logic_vector(2 downto 0) := (others => '0');
  begin
    for i in 0 to 2 loop
      if i < depth then
        r(i) := f_pick(noise_vec, map(i));
      end if;
    end loop;
    return r;
  end function f_dirt_bits;

  function f_apply_dirt (
    value : std_logic_vector(11 downto 0);
    dirt  : std_logic_vector(2 downto 0);
    depth : natural;
    en    : std_logic
  ) return std_logic_vector is
    variable r : std_logic_vector(11 downto 0) := value;
  begin
    if en = '1' and depth > 0 then
      for i in 0 to 2 loop
        if i < depth then
          r(4 + i) := r(4 + i) xor dirt(i);
        end if;
      end loop;
    end if;
    return r;
  end function f_apply_dirt;

  signal depth_s   : unsigned(1 downto 0);
  signal depth_n   : natural;
  signal y_dirt_s  : std_logic_vector(2 downto 0);
  signal u_dirt_s  : std_logic_vector(2 downto 0);
  signal v_dirt_s  : std_logic_vector(2 downto 0);

begin

  depth_s <= unsigned(dirt_ctrl(1 downto 0));
  depth_n <= to_integer(depth_s);

  y_dirt_s <= f_dirt_bits(noise, C_Y_MAP, depth_n);
  u_dirt_s <= f_dirt_bits(noise, C_U_MAP, depth_n);
  v_dirt_s <= f_dirt_bits(noise, C_V_MAP, depth_n);

  p_dirt : process (clk) is
  begin
    if rising_edge(clk) then
      y_out <= f_apply_dirt(y_in, y_dirt_s, depth_n, dirt_ctrl(2));
      u_out <= f_apply_dirt(u_in, u_dirt_s, depth_n, dirt_ctrl(3));
      v_out <= f_apply_dirt(v_in, v_dirt_s, depth_n, dirt_ctrl(4));
    end if;
  end process p_dirt;

end architecture rtl;
