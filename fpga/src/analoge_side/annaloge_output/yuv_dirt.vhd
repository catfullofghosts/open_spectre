library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- XOR "dirt" from a per-pixel LFSR into 8-bit Y/U/V bits [4:2].
-- Depth N XORs bits [2] .. [2+N-1] (0=off, 1=bit2, 2=bits[3:2], 3=bits[4:2]).
-- Permuted LFSR picks (first N used): Y=0,1,4  U=4,2,0  V=1,5,2
--
-- rand_num is 6-bit (enough for the 5 unique map indices 0..5).

entity yuv_dirt is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic; -- active-high, seeds the LFSR
    dirt_ctrl : in  std_logic_vector(4 downto 0); -- [1:0]=depth, [2]=Y, [3]=U, [4]=V
    y_in      : in  std_logic_vector(7 downto 0);
    u_in      : in  std_logic_vector(7 downto 0);
    v_in      : in  std_logic_vector(7 downto 0);
    y_out     : out std_logic_vector(7 downto 0);
    u_out     : out std_logic_vector(7 downto 0);
    v_out     : out std_logic_vector(7 downto 0)
  );
end entity yuv_dirt;

architecture rtl of yuv_dirt is

  constant C_DIRT_LSB : natural := 2; -- act on bits [4:2], not [2:0]

  type dirt_map_t is array (0 to 2) of natural;

  constant C_Y_MAP : dirt_map_t := (0, 1, 4);
  constant C_U_MAP : dirt_map_t := (4, 2, 0);
  constant C_V_MAP : dirt_map_t := (1, 5, 2);

  signal lfsr_q : std_logic_vector(5 downto 0);

  function f_pick (
    noise_vec : std_logic_vector(5 downto 0);
    idx       : natural
  ) return std_logic is
  begin
    return noise_vec(idx);
  end function f_pick;

  function f_dirt_bits (
    noise_vec : std_logic_vector(5 downto 0);
    perm_lut  : dirt_map_t;
    depth     : natural
  ) return std_logic_vector is
    variable r : std_logic_vector(2 downto 0) := (others => '0');
  begin
    for i in 0 to 2 loop
      if i < depth then
        r(i) := f_pick(noise_vec, perm_lut(i));
      end if;
    end loop;
    return r;
  end function f_dirt_bits;

  function f_apply_dirt (
    value : std_logic_vector(7 downto 0);
    dirt  : std_logic_vector(2 downto 0);
    depth : natural;
    en    : std_logic
  ) return std_logic_vector is
    variable r : std_logic_vector(7 downto 0) := value;
  begin
    if en = '1' and depth > 0 then
      for i in 0 to 2 loop
        if i < depth then
          r(C_DIRT_LSB + i) := r(C_DIRT_LSB + i) xor dirt(i);
        end if;
      end loop;
    end if;
    return r;
  end function f_apply_dirt;

  signal depth_n   : natural;
  signal y_dirt_s  : std_logic_vector(2 downto 0);
  signal u_dirt_s  : std_logic_vector(2 downto 0);
  signal v_dirt_s  : std_logic_vector(2 downto 0);

begin

  dirt_lfsr : entity work.rand_num
    port map (
      clk   => clk,
      en    => '1',
      reset => rst,
      q     => lfsr_q
    );

  depth_n <= to_integer(unsigned(dirt_ctrl(1 downto 0)));

  y_dirt_s <= f_dirt_bits(lfsr_q, C_Y_MAP, depth_n);
  u_dirt_s <= f_dirt_bits(lfsr_q, C_U_MAP, depth_n);
  v_dirt_s <= f_dirt_bits(lfsr_q, C_V_MAP, depth_n);

  p_dirt : process (clk) is
  begin
    if rising_edge(clk) then
      y_out <= f_apply_dirt(y_in, y_dirt_s, depth_n, dirt_ctrl(2));
      u_out <= f_apply_dirt(u_in, u_dirt_s, depth_n, dirt_ctrl(3));
      v_out <= f_apply_dirt(v_in, v_dirt_s, depth_n, dirt_ctrl(4));
    end if;
  end process p_dirt;

end architecture rtl;
