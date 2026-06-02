library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Replace with actual package if needed
library work;
use work.array_pck.all;

entity analog_side_tb is
end entity;

architecture testbench of analog_side_tb is

  -- Clock period
  constant clk_period : time := 10 ns;

  -- DUT signals
  signal clk      : std_logic := '0';
  signal rst      : std_logic := '1';
  signal wr       : std_logic := '0';
  signal vsync    : std_logic := '0';
  signal hsync    : std_logic := '0';
  signal out_addr : std_logic_vector(7 downto 0) := (others => '0');
  signal gain_out : std_logic_vector(15 downto 0);
  signal gain_in  : std_logic_vector(15 downto 0) := x"1234";

  -- Analog control signals
  signal pos_h_1, pos_v_1, zoom_h_1, zoom_v_1, circle_1, gear_1, lantern_1, fizz_1 : std_logic_vector(11 downto 0) := (others => '0');
  signal pos_h_2, pos_v_2, zoom_h_2, zoom_v_2, circle_2, gear_2, lantern_2, fizz_2 : std_logic_vector(11 downto 0) := (others => '0');

  signal noise_freq    : std_logic_vector(9 downto 0) := (others => '0');
  signal slew_in       : std_logic_vector(2 downto 0) := (others => '0');
  signal cycle_recycle : std_logic := '0';

  signal YUV_in  : std_logic_vector(23 downto 0) := x"123456";
  signal y_alpha, u_alpha, v_alpha : std_logic_vector(11 downto 0) := (others => '0'); -- alpha of 0 = full colour passthrough

  signal audio_in_t, audio_in_b, audio_in_sig : std_logic_vector(9 downto 0) := (others => '0');

  signal sync_sel_osc1, sync_sel_osc2 : std_logic_vector(1 downto 0) := "00";
  signal osc_1_freq, osc_2_freq       : std_logic_vector(9 downto 0) := (others => '0');
  signal osc_1_derv, osc_2_derv       : std_logic_vector(7 downto 0) := (others => '0');

  signal dsm_hi_i, dsm_lo_i : std_logic_vector(9 downto 0) := (others => '0');

  signal vid_span        : std_logic_vector(7 downto 0);
  signal osc_1_sqr_o     : std_logic;
  signal osc_2_sqr_o     : std_logic;
  signal noise_1_o       : std_logic;
  signal noise_2_o       : std_logic;

  signal matrix_pos_h_1, matrix_pos_v_1, matrix_zoom_h_1, matrix_zoom_v_1 : std_logic_vector(11 downto 0);
  signal matrix_circle_1, matrix_gear_1, matrix_lantern_1, matrix_fizz_1 : std_logic_vector(11 downto 0);
  signal matrix_pos_h_2, matrix_pos_v_2, matrix_zoom_h_2, matrix_zoom_v_2 : std_logic_vector(11 downto 0);
  signal matrix_circle_2, matrix_gear_2, matrix_lantern_2, matrix_fizz_2 : std_logic_vector(11 downto 0);

  signal y_out, u_out, v_out : std_logic_vector(7 downto 0);
  
  signal dsm_lo_alpha, dsm_hi_alpha, osc1_alpha, osc2_alpha, noise1_alpha, noise2_alpha  : std_logic_vector(11 downto 0) := (others => '0');

begin

  -- Instantiate the DUT
  uut: entity work.analog_side
    port map (
      clk => clk,
      rst => rst,
      wr  => wr,
      vsync => vsync,
      hsync => hsync,
      out_addr => out_addr,
      gain_out => gain_out,
      gain_in => gain_in,

      pos_h_1 => pos_h_1, pos_v_1 => pos_v_1, zoom_h_1 => zoom_h_1, zoom_v_1 => zoom_v_1,
      circle_1 => circle_1, gear_1 => gear_1, lantern_1 => lantern_1, fizz_1 => fizz_1,
      pos_h_2 => pos_h_2, pos_v_2 => pos_v_2, zoom_h_2 => zoom_h_2, zoom_v_2 => zoom_v_2,
      circle_2 => circle_2, gear_2 => gear_2, lantern_2 => lantern_2, fizz_2 => fizz_2,

      noise_freq => noise_freq, slew_in => slew_in, cycle_recycle => cycle_recycle,

      YUV_in => YUV_in, y_alpha => y_alpha, u_alpha => u_alpha, v_alpha => v_alpha,

      audio_in_t => audio_in_t, audio_in_b => audio_in_b, audio_in_sig => audio_in_sig,

      sync_sel_osc1 => sync_sel_osc1, osc_1_freq => osc_1_freq, osc_1_derv => osc_1_derv,
      sync_sel_osc2 => sync_sel_osc2, osc_2_freq => osc_2_freq, osc_2_derv => osc_2_derv,

      dsm_hi_i => dsm_hi_i, dsm_lo_i => dsm_lo_i,

      vid_span => vid_span, osc_1_sqr_o => osc_1_sqr_o, osc_2_sqr_o => osc_2_sqr_o,
      noise_1_o => noise_1_o, noise_2_o => noise_2_o,

      matrix_pos_h_1 => matrix_pos_h_1, matrix_pos_v_1 => matrix_pos_v_1,
      matrix_zoom_h_1 => matrix_zoom_h_1, matrix_zoom_v_1 => matrix_zoom_v_1,
      matrix_circle_1 => matrix_circle_1, matrix_gear_1 => matrix_gear_1,
      matrix_lantern_1 => matrix_lantern_1, matrix_fizz_1 => matrix_fizz_1,
      matrix_pos_h_2 => matrix_pos_h_2, matrix_pos_v_2 => matrix_pos_v_2,
      matrix_zoom_h_2 => matrix_zoom_h_2, matrix_zoom_v_2 => matrix_zoom_v_2,
      matrix_circle_2 => matrix_circle_2, matrix_gear_2 => matrix_gear_2,
      matrix_lantern_2 => matrix_lantern_2, matrix_fizz_2 => matrix_fizz_2,
    
      dsm_lo_alpha => dsm_lo_alpha , dsm_hi_alpha => dsm_hi_alpha, 
      osc1_alpha => osc1_alpha, osc2_alpha => osc2_alpha,
      noise_alpha => noise1_alpha,
    
      y_out => y_out, u_out => u_out, v_out => v_out
    );

  -- Clock generation
  clk_process : process
  begin
    while true loop
      clk <= '0';
      wait for clk_period / 2;
      clk <= '1';
      wait for clk_period / 2;
    end loop;
  end process;

  -- Stimulus
  stim_proc : process
  begin
    -- Initial reset
    noise_freq <= std_logic_vector(to_unsigned(30, 10));
    osc_1_freq <= std_logic_vector(to_unsigned(40, 10));
    osc_2_freq <= std_logic_vector(to_unsigned(44, 10));
    
    wait for 20 ns;
    rst <= '0';
    
    

    -- Drive some inputs
--    wr <= '1';
--    vsync <= '1';
--    hsync <= '1';
--    pos_h_1 <= to_unsigned(100, 12);
--    pos_v_1 <= to_unsigned(200, 12);
--    zoom_h_1 <= to_unsigned(10, 12);
--    zoom_v_1 <= to_unsigned(10, 12);
--    circle_1 <= to_unsigned(5, 12);
--    YUV_in <= x"FF00FF";
--    out_addr <= x"0A";

    wait for 100 ns;

    -- More stimulus
    vsync <= '0';
    hsync <= '0';

    wait for 200 ns;

    -- End simulation
  end process;

end architecture;
