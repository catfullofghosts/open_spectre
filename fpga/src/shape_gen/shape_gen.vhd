
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: shape_gen by RD Jordan
-- Created: Early 2023-25
-- Description: EMS Spectron Shape gen clone
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

entity shape_gen is
  port (
    clk                   : in std_logic;
    rst                   : in std_logic;
    h_sync                : in std_logic;
    v_sync                : in std_logic;
    start_of_frame        : in std_logic;
    start_of_active_video : in std_logic;
    video_on              : in std_logic;

    pos_h     : in std_logic_vector(11 downto 0); -- centre positon for distence calculator
    pos_v     : in std_logic_vector(11 downto 0); -- centre positon for distence calculator
    zoom_h    : in std_logic_vector(11 downto 0); -- effects the rate of the reset ramp
    zoom_v    : in std_logic_vector(11 downto 0); -- effects the rate of the reset ramp
    circle_i  : in std_logic_vector(11 downto 0);
    gear_i    : in std_logic_vector(11 downto 0);
    lantern_i : in std_logic_vector(11 downto 0);
    fizz_i    : in std_logic_vector(11 downto 0); -- frizz size input

    shape_a_sel : in std_logic_vector(3 downto 0) := "0111";
    shape_b_sel : in std_logic_vector(3 downto 0) := "0000";

    -- Shape specific aditinal inputs, works on stuff like lantern
    x_in : in std_logic_vector(8 downto 0) := (others => '0');
    y_in : in std_logic_vector(8 downto 0) := (others => '0');

    shape_a : out std_logic;
    shape_b : out std_logic
  );
end shape_gen;

architecture Behavioral of shape_gen is

  signal rst_n    : std_logic;

  signal reset_ramp_x        : std_logic_vector(15 downto 0);
  signal reset_ramp_x_length : unsigned(8 downto 0);
  signal reset_ramp_y        : std_logic_vector(15 downto 0);
  signal reset_ramp_y_length : unsigned(8 downto 0);
  signal noise_x             : std_logic_vector(8 downto 0);
  signal noise_y             : std_logic_vector(8 downto 0);

  signal fizz         : std_logic_vector(15 downto 0); -- the output of the noise gen scaled to the range of the distance ramp
  signal noise        : std_logic_vector(5 downto 0); -- 
  signal gear_x5      : std_logic_vector(15 downto 0); -- input x5 scaled up to the range of the distance ramp
  signal gear_x5_slew : std_logic_vector(15 downto 0); -- input x5 scaled up to the range of the distance ramp

  signal lantern_mix           : unsigned(15 downto 0);
  signal x6_mix                : std_logic_vector(6 downto 0);
  signal x7_mix                : std_logic_vector(6 downto 0);
  signal y6_mix                : std_logic_vector(6 downto 0);
  signal y7_mix                : std_logic_vector(6 downto 0);
  signal moonlignt             : std_logic;
  signal criscross_inverted    : std_logic;
  signal lantern_behind_cutout : std_logic;
  signal ring                  : std_logic;
  signal amazon                : std_logic;
  signal cutout                : std_logic;
  signal criss_cross           : std_logic;
  signal gear_circle           : std_logic;
  signal hoz_seg               : std_logic;
  signal vert_seg              : std_logic;
  signal palm_leaves           : std_logic;
  signal triangles             : std_logic;
  signal frizz                 : std_logic;
  signal lantern               : std_logic;
  signal gear                  : std_logic;
  signal circle                : std_logic;

  signal shape_bus : std_logic_vector(15 downto 0);
  --    signal shape_a_sel        : std_logic_vector(2 downto 0) := "110";
  --    signal shape_b_sel        : std_logic_vector(2 downto 0) := "000";

  signal cx_pixel : std_logic_vector(15 downto 0) := (others => '0');
  signal cy_pixel : std_logic_vector(15 downto 0) := (others => '0');

  signal distance : std_logic_vector(15 downto 0);
  signal h_sync_n : std_logic;
  signal h_sync_d : std_logic;
  signal v_sync_n : std_logic;
  signal vramp_en : std_logic;
  
  signal  x_in_d :  std_logic_vector(8 downto 0) := (others => '0');
  signal  y_in_d :  std_logic_vector(8 downto 0) := (others => '0');

  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of circle : signal is "TRUE";
  attribute MARK_DEBUG of vert_seg : signal is "TRUE";
  attribute MARK_DEBUG of cutout : signal is "TRUE";

  --mux function (shape_bus is 16 bits: indices 0..15)
  function multi321 (A, B : in std_logic_vector) return std_logic is
    variable idx : natural;
  begin
    idx := to_integer(unsigned(B));
    if idx >= A'length then
      return '0';
    else
      return A(idx);
    end if;
  end multi321;

begin

  cx_pixel <= "0000" & pos_h;
  cy_pixel <= "0000" & pos_v;
  h_sync_n <= not h_sync;
  v_sync_n <= not v_sync;
  rst_n <= rst; -- incoming reset is already inverted so just change its name

  process (clk)
  begin
    if rising_edge(clk) then
      h_sync_d <= h_sync;
      if h_sync = '1' and h_sync_d = '0' then
        vramp_en <= '1';

      else
        vramp_en <= '0';
      end if;

    end if;

  end process;

  mixed_parab : entity work.distance_calc_wrapper
    port map
    (
      px_clk => clk,
      reset  => rst_n,
      -- center coordinate inputs
      cx_level => cx_pixel,
      cy_level => cy_pixel,
      -- VGA signals to outside if needed
      h_sync                => h_sync_n,
      v_sync                => v_sync_n,
      start_of_frame        => v_sync_n,--start_of_frame,
      start_of_active_video => start_of_active_video,
      -- distance output
      distance => distance
    );

  random_ramp_x : entity work.nco_dual_wrapper -- RESET BY COMPARITOR INPUT 0?
    port map
    (
      i_clk        => clk,
      i_rstb       => rst_n,
      i_sync_reset => h_sync, -- is one when video is active 0 other wise that means that the ramp restarts at each line
      i_enable     => '1',
      i_repeat     => '1',
      i_fcw        => zoom_h(8 downto 0),
      o_nco        => reset_ramp_x
    );

  random_ramp_y : entity work.nco_dual_wrapper -- RESET BY COMPARITOR INPUT 2?
    port map
    (
      i_clk        => clk,
      i_rstb       => rst_n,
      i_sync_reset => v_sync, -- is one when video is active 0 other wise that means that the ramp restarts at frame 
      i_enable     => vramp_en,
      i_repeat     => '1',
      i_fcw        => zoom_v(8 downto 0),
      o_nco        => reset_ramp_y
    );

  fizz_gen : entity work.rand_num
    port map
    (
      clk   => clk,
      en    => '1',
      reset => rst_n,
      q     => noise
    );

  fizz    <= "000000" & noise(5 downto 0) & noise(2 downto 1) & noise(5) & noise(0); -- was "0000000000" & noise(5 downto 0), but the fizz was too small
  gear_x5 <= "000000000" & x_in(4) & "000000";

  -- lantern inputs scaled and mixed
  x6_mix <= x_in(5) & x_in(5) & x_in(5) & x_in(5) & x_in(5) & x_in(5) & '0';
  x7_mix <= x_in(6) & x_in(6) & x_in(6) & x_in(6) & x_in(6) & x_in(6) & '0';
  y6_mix <= y_in(5) & y_in(5) & y_in(5) & y_in(5) & y_in(5) & y_in(5) & '0';
  y7_mix <= y_in(6) & y_in(6) & y_in(6) & y_in(6) & y_in(6) & y_in(6) & '0';
  slew_med : entity work.moving_average
    generic map(
      G_NBIT      => 16,
      G_MAX_DELTA => 1 -- fine turne with actual x5, was a 2 but that might kill the shape too much
    )
    port map
    (
      i_clk        => clk,
      i_rstb       => rst_n,
      i_sync_reset => rst_n,
      i_data_ena   => '1',
      i_data       => gear_x5,
      o_data_valid => open,
      o_data       => gear_x5_slew
    );
  shape_logic : process (clk)
  begin
    if rising_edge(clk) then
      -- moonlignt
      moonlignt <= circle nand cutout;
      -- lantern behind cutout
      lantern_behind_cutout <= lantern nand cutout;
      --ring 
      ring <= circle nand (circle nand gear);
      --amazon
      amazon <= cutout xor palm_leaves;
      --cutout
      cutout <= criss_cross xor triangles;
      -- criss_cross
      criss_cross <= vert_seg xor hoz_seg;
      -- gear+circle
      gear_circle <= gear xor circle;
      -- palm leaves ???? check this logic, it seems wrong
      if ((triangles = '1') and (vert_seg = '0')) then
        palm_leaves <= '1';
      else
        palm_leaves <= '0';
      end if;
      -- vert_seg
      if (unsigned(reset_ramp_x) > unsigned(distance)) then
        vert_seg <= '1';
      else
        vert_seg <= '0';
      end if;
      -- hoz_seg
      if (unsigned(reset_ramp_y) > unsigned(distance)) then
        hoz_seg <= '1';
      else
        hoz_seg <= '0';
      end if;
      -- triangles
      if (unsigned(reset_ramp_y) > unsigned(reset_ramp_x)) then
        triangles <= '1';
      else
        triangles <= '0';
      end if;

      -- lantern
      lantern_mix <= resize(unsigned(x6_mix), 16) + resize(unsigned(x7_mix), 16) + resize(unsigned(y6_mix), 16) + resize(unsigned(y7_mix), 16);
      if ((lantern_mix + unsigned(lantern_i)) > unsigned(distance)) then
        lantern <= '1';
      else
        lantern <= '0';
      end if;
      -- gear
      if ((unsigned(gear_x5_slew) + unsigned(gear_i)) > unsigned(distance)) then -- the tips need to be rounded on the smoothing?
        gear <= '1';
      else
        gear <= '0';
      end if;

      --fizz
      if (unsigned(circle_i) + unsigned(fizz) + unsigned(fizz_i)) > unsigned(distance) then -- here fizz_i increases the circle size not the fizz size!
        frizz <= '1';
      else
        frizz <= '0';
      end if;

      -- circle
      if (unsigned(circle_i) > unsigned(distance)) then
        circle <= '1';
      else
        circle <= '0';
      end if;
    end if;
  end process;

  shape_bus <= lantern_behind_cutout & moonlignt & amazon & cutout & palm_leaves & triangles & not criss_cross & criss_cross & hoz_seg & vert_seg & gear_circle & gear & lantern & frizz & ring & circle;
  shape_a   <= multi321(shape_bus, shape_a_sel);
  shape_b   <= multi321(shape_bus, shape_b_sel);
end Behavioral;
