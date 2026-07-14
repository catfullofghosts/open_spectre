--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: 
-- Created: Early 2023-2025
-- Description: 
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE

-- created by   :   RD Jordan
-- Wrapper for Microblaze registers
-- Auto generated VHDL Wrapper (Parse VHDL)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library unisim;
use unisim.vcomponents.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.overlay_sprite_pkg.all;

entity cpu_reg_wrapper is
  port (
    clk     : in std_logic;
    pix_clk : in std_logic;
    rst     : in std_logic;
    -- Register Interface
    regs_en      : in std_logic;
    regs_wen     : in std_logic_vector(3 downto 0);
    regs_addr    : in std_logic_vector(12 downto 0);
    regs_wr_data : in std_logic_vector(31 downto 0);
    regs_rd_data : out std_logic_vector(31 downto 0);

    -- Digital Matrix Control
    matrix_out_addr : out std_logic_vector(5 downto 0);
    matrix_mask_out : out std_logic_vector(63 downto 0);
    matrix_load     : out std_logic;
    invert_matrix   : out std_logic_vector(63 downto 0);
    -- Video Input Control
    vid_span : out std_logic_vector(7 downto 0);
    -- Analoge Matrix Control
    out_addr       : out std_logic_vector(7 downto 0);
    ch_addr        : out std_logic_vector(7 downto 0);
    gain_in        : out std_logic_vector(15 downto 0);
    anna_matrix_wr : out std_logic;

    -- rotery encoders
    rotery_addr_mux     : out std_logic_vector(3 downto 0);
    rotery_enc_0        : in std_logic_vector(31 downto 0);
    rotery_enc_1        : in std_logic_vector(31 downto 0);
    rotery_enc_2        : in std_logic_vector(31 downto 0);
    rotery_enc_3        : in std_logic_vector(31 downto 0);
    rotery_enc_4        : in std_logic_vector(31 downto 0);
    rotery_enc_preset_w : out std_logic;
    rotery_enc_0_preset : out std_logic_vector(31 downto 0);
    rotery_enc_1_preset : out std_logic_vector(31 downto 0);
    rotery_enc_2_preset : out std_logic_vector(31 downto 0);
    rotery_enc_3_preset : out std_logic_vector(31 downto 0);
    rotery_enc_4_preset : out std_logic_vector(31 downto 0);
    -- buttons
    button_matrix : in std_logic_vector(31 downto 0);
    -- leds
    led_output     : out std_logic_vector(31 downto 0);
    led_global_pwm : out std_logic_vector(31 downto 0);
    lcd_backligh   : out std_logic;
    -- fans
    fan_pwm : out std_logic_vector(31 downto 0);
    fan_rpm : in std_logic_vector(31 downto 0);

    -- Shape gen
    pos_h_1   : out std_logic_vector(11 downto 0);
    pos_v_1   : out std_logic_vector(11 downto 0);
    zoom_h_1  : out std_logic_vector(11 downto 0);
    zoom_v_1  : out std_logic_vector(11 downto 0);
    circle_1  : out std_logic_vector(11 downto 0);
    gear_1    : out std_logic_vector(11 downto 0);
    lantern_1 : out std_logic_vector(11 downto 0);
    fizz_1    : out std_logic_vector(11 downto 0);
    pos_h_2   : out std_logic_vector(11 downto 0);
    pos_v_2   : out std_logic_vector(11 downto 0);
    zoom_h_2  : out std_logic_vector(11 downto 0);
    zoom_v_2  : out std_logic_vector(11 downto 0);
    circle_2  : out std_logic_vector(11 downto 0);
    gear_2    : out std_logic_vector(11 downto 0);
    lantern_2 : out std_logic_vector(11 downto 0);
    fizz_2    : out std_logic_vector(11 downto 0);
    -- noise gen
    noise_freq    : out std_logic_vector(13 downto 0);
    slew_in       : out std_logic_vector(2 downto 0);
    cycle_recycle : out std_logic;
    noise_rst     : out std_logic;
    slowdown_sel : out std_logic_vector(1 downto 0);
    -- osc 1 & 2
    sync_sel_osc1 : out std_logic_vector(1 downto 0);
    osc_1_freq    : out std_logic_vector(13 downto 0);
    osc_1_derv    : out std_logic_vector(7 downto 0);
    osc_1_pwm_duty : out std_logic_vector(8 downto 0);
    osc_1_wave_sel : out std_logic_vector(1 downto 0);
    sync_sel_osc2 : out std_logic_vector(1 downto 0);
    osc_2_freq    : out std_logic_vector(13 downto 0);
    osc_2_derv    : out std_logic_vector(7 downto 0);
    osc_2_pwm_duty : out std_logic_vector(8 downto 0);
    osc_2_wave_sel : out std_logic_vector(1 downto 0);
    speed1        : out std_logic;
    speed2        : out std_logic;
    -- Output Levels & output Active
    col_en_bypass : out std_logic;
    y_level        : out std_logic_vector(11 downto 0);
    cr_level       : out std_logic_vector(11 downto 0);
    cb_level       : out std_logic_vector(11 downto 0);
    video_active_o : out std_logic;
    -- Pixel clock and video input control
    pix_clk_div_sel     : out std_logic; -- 0 = /2, 1 = /4 for X and Y digital counters
    ext_vid_in_mux_sel  : out std_logic; -- 0 = luma calc, 1 = y_out
    edge_width_sel      : out std_logic_vector(1 downto 0);
    ca_cfg              : out std_logic_vector(15 downto 0);
    -- Luma key control
    luma_key_enable     : out std_logic;
    luma_key_direction  : out std_logic; -- 0 = key < threshold, 1 = key > threshold
    luma_key_thresh_low : out std_logic_vector(7 downto 0);
    luma_key_thresh_high: out std_logic_vector(7 downto 0);
    -- Alpha controls for analog side
    osc1_alpha     : out std_logic_vector(11 downto 0);
    osc2_alpha     : out std_logic_vector(11 downto 0);
    dsm_hi_alpha   : out std_logic_vector(11 downto 0);
    dsm_lo_alpha   : out std_logic_vector(11 downto 0);
    noise_alpha    : out std_logic_vector(11 downto 0);
    -- Shape select controls
    shape1_a_sel   : out std_logic_vector(3 downto 0);
    shape1_b_sel   : out std_logic_vector(3 downto 0);
    shape2_a_sel   : out std_logic_vector(3 downto 0);
    shape2_b_sel   : out std_logic_vector(3 downto 0);
    video_fx_ctrl     : out std_logic_vector(31 downto 0);
    video_fx_bitplane : out std_logic_vector(31 downto 0);
    video_fx_dither   : out std_logic_vector(31 downto 0);
    video_fx_mirror   : out std_logic_vector(31 downto 0);
    video_fx_chromatic : out std_logic_vector(31 downto 0);
    video_fx_sharpness : out std_logic_vector(31 downto 0);
    overlay_global_en  : out std_logic;
    overlay_sprites    : out t_sprite_array;

    frame_stats_luma_min : in  std_logic_vector(7 downto 0);
    frame_stats_luma_max : in  std_logic_vector(7 downto 0);
    frame_stats_luma_avg : in  std_logic_vector(7 downto 0);
    frame_stats_r_min    : in  std_logic_vector(7 downto 0);
    frame_stats_r_max    : in  std_logic_vector(7 downto 0);
    frame_stats_r_avg    : in  std_logic_vector(7 downto 0);
    frame_stats_g_min    : in  std_logic_vector(7 downto 0);
    frame_stats_g_max    : in  std_logic_vector(7 downto 0);
    frame_stats_g_avg    : in  std_logic_vector(7 downto 0);
    frame_stats_b_min    : in  std_logic_vector(7 downto 0);
    frame_stats_b_max    : in  std_logic_vector(7 downto 0);
    frame_stats_b_avg    : in  std_logic_vector(7 downto 0);
    frame_stats_frame_id : in  std_logic_vector(7 downto 0);
    frame_stats_hash      : in  std_logic_vector(31 downto 0);
    frame_stats_pix_count : in  std_logic_vector(31 downto 0)

  );
end cpu_reg_wrapper;

architecture rtl of cpu_reg_wrapper is

  signal debug            : std_logic_vector(127 downto 0);
  signal exception_addr_o : std_logic;

   signal i_matrix_out_addr : std_logic_vector(5 downto 0);
   signal i_matrix_mask_out : std_logic_vector(63 downto 0);
   signal i_matrix_load     : std_logic;
   signal i_invert_matrix   : std_logic_vector(63 downto 0);
    -- Video Input Control
   signal i_vid_span : std_logic_vector(7 downto 0);
    -- Analoge Matrix Control
  signal  i_out_addr       : std_logic_vector(7 downto 0);
  signal  i_ch_addr        : std_logic_vector(7 downto 0);
  signal  i_gain_in        : std_logic_vector(15 downto 0);
  signal  i_anna_matrix_wr : std_logic;
     -- Shape gen
  signal  i_pos_h_1   : std_logic_vector(11 downto 0);
  signal  i_pos_v_1   : std_logic_vector(11 downto 0);
  signal  i_zoom_h_1  : std_logic_vector(11 downto 0);
  signal  i_zoom_v_1  : std_logic_vector(11 downto 0);
  signal  i_circle_1  : std_logic_vector(11 downto 0);
  signal  i_gear_1    : std_logic_vector(11 downto 0);
  signal  i_lantern_1 : std_logic_vector(11 downto 0);
  signal  i_fizz_1    : std_logic_vector(11 downto 0);
  signal  i_pos_h_2   : std_logic_vector(11 downto 0);
  signal  i_pos_v_2   : std_logic_vector(11 downto 0);
  signal  i_zoom_h_2  : std_logic_vector(11 downto 0);
  signal  i_zoom_v_2  : std_logic_vector(11 downto 0);
  signal  i_circle_2  : std_logic_vector(11 downto 0);
  signal  i_gear_2    : std_logic_vector(11 downto 0);
  signal  i_lantern_2 : std_logic_vector(11 downto 0);
  signal  i_fizz_2    : std_logic_vector(11 downto 0);
    -- noise gen
  signal  i_noise_freq    : std_logic_vector(13 downto 0);
  signal  i_slew_in       : std_logic_vector(2 downto 0);
  signal  i_cycle_recycle : std_logic;
    -- osc 1 & 2
  signal  i_sync_sel_osc1 : std_logic_vector(1 downto 0);
  signal  i_osc_1_freq    : std_logic_vector(13 downto 0);
  signal  i_osc_1_derv    : std_logic_vector(7 downto 0);
  signal  i_osc_1_pwm_duty : std_logic_vector(8 downto 0);
  signal  i_osc_1_wave_sel : std_logic_vector(1 downto 0);
  signal  i_sync_sel_osc2 : std_logic_vector(1 downto 0);
  signal  i_osc_2_freq    : std_logic_vector(13 downto 0);
  signal  i_osc_2_derv    : std_logic_vector(7 downto 0);
  signal  i_osc_2_pwm_duty : std_logic_vector(8 downto 0);
  signal  i_osc_2_wave_sel : std_logic_vector(1 downto 0);
    -- Output Levels & output Active
  signal  i_col_en_bypass : std_logic;
    
  signal  i_y_level        : std_logic_vector(11 downto 0);
  signal  i_cr_level       : std_logic_vector(11 downto 0);
  signal  i_cb_level       : std_logic_vector(11 downto 0);
  signal  i_video_active_o : std_logic;
  -- Pixel clock and video input control
  signal  i_pix_clk_div_sel    : std_logic;
  signal  i_ext_vid_in_mux_sel  : std_logic;
  signal  i_edge_width_sel      : std_logic_vector(1 downto 0);
  signal  i_ca_cfg             : std_logic_vector(15 downto 0);
  -- Luma key control
  signal  i_luma_key_enable     : std_logic;
  signal  i_luma_key_direction  : std_logic;
  signal  i_luma_key_thresh_low : std_logic_vector(7 downto 0);
  signal  i_luma_key_thresh_high: std_logic_vector(7 downto 0);
  -- Alpha controls for analog side
  signal  i_osc1_alpha     : std_logic_vector(11 downto 0);
  signal  i_osc2_alpha     : std_logic_vector(11 downto 0);
  signal  i_dsm_hi_alpha   : std_logic_vector(11 downto 0);
  signal  i_dsm_lo_alpha   : std_logic_vector(11 downto 0);
  signal  i_noise_alpha    : std_logic_vector(11 downto 0);
  -- Shape select controls
  signal  i_shape1_a_sel   : std_logic_vector(3 downto 0);
  signal  i_shape1_b_sel   : std_logic_vector(3 downto 0);
  signal  i_shape2_a_sel   : std_logic_vector(3 downto 0);
  signal  i_shape2_b_sel   : std_logic_vector(3 downto 0);
  signal  i_video_fx_ctrl     : std_logic_vector(31 downto 0);
  signal  i_video_fx_bitplane : std_logic_vector(31 downto 0);
  signal  i_video_fx_dither   : std_logic_vector(31 downto 0);
  signal  i_video_fx_mirror   : std_logic_vector(31 downto 0);
  signal  i_video_fx_chromatic : std_logic_vector(31 downto 0);
  signal  i_video_fx_sharpness : std_logic_vector(31 downto 0);
  signal  i_overlay_global_en  : std_logic;
  signal  i_overlay_sprites     : t_sprite_array;

  
begin

  digital_reg_file_i : entity work.digital_reg_file
    generic map(
      reg_version_id => 0x"00"
    )
    port map
    (
      regs_clk            => clk,
      regs_rst            => rst,
      regs_en             => regs_en,
      regs_wen            => regs_wen,
      regs_addr           => regs_addr,
      regs_wr_data        => regs_wr_data,
      regs_rd_data        => regs_rd_data,
      rotery_addr_mux     => rotery_addr_mux,
      rotery_enc_0        => rotery_enc_0,
      rotery_enc_1        => rotery_enc_1,
      rotery_enc_2        => rotery_enc_2,
      rotery_enc_3        => rotery_enc_3,
      rotery_enc_4        => rotery_enc_4,
      rotery_enc_preset_w => rotery_enc_preset_w,
      rotery_enc_0_preset => rotery_enc_0_preset,
      rotery_enc_1_preset => rotery_enc_1_preset,
      rotery_enc_2_preset => rotery_enc_2_preset,
      rotery_enc_3_preset => rotery_enc_3_preset,
      rotery_enc_4_preset => rotery_enc_4_preset,
      button_matrix       => button_matrix,
      led_output          => led_output,
      led_global_pwm      => led_global_pwm,
      lcd_backligh        => lcd_backligh,
      fan_pwm             => fan_pwm,
      fan_rpm             => fan_rpm,
      matrix_out_addr     => i_matrix_out_addr,
      matrix_mask_out     => i_matrix_mask_out,
      matrix_load         => i_matrix_load,
      invert_matrix       => i_invert_matrix,
      vid_span            => i_vid_span,
      out_addr            => i_out_addr,
      ch_addr             => i_ch_addr,
      gain_in             => i_gain_in,
      anna_matrix_wr      => i_anna_matrix_wr,
      pos_h_1             => i_pos_h_1,
      pos_v_1             => i_pos_v_1,
      zoom_h_1            => i_zoom_h_1,
      zoom_v_1            => i_zoom_v_1,
      circle_1            => i_circle_1,
      gear_1              => i_gear_1,
      lantern_1           => i_lantern_1,
      fizz_1              => i_fizz_1,
      pos_h_2             => i_pos_h_2,
      pos_v_2             => i_pos_v_2,
      zoom_h_2            => i_zoom_h_2,
      zoom_v_2            => i_zoom_v_2,
      circle_2            => i_circle_2,
      gear_2              => i_gear_2,
      lantern_2           => i_lantern_2,
      fizz_2              => i_fizz_2,
      noise_freq          => i_noise_freq,
      slew_in             => i_slew_in,
      cycle_recycle       => i_cycle_recycle,
      noise_rst           => noise_rst,
      slowdown_sel        => slowdown_sel,
      sync_sel_osc1       => i_sync_sel_osc1,
      osc_1_freq          => i_osc_1_freq,
      osc_1_derv          => i_osc_1_derv,
      osc_1_pwm_duty      => i_osc_1_pwm_duty,
      osc_1_wave_sel      => i_osc_1_wave_sel,
      sync_sel_osc2       => i_sync_sel_osc2,
      osc_2_freq          => i_osc_2_freq,
      osc_2_derv          => i_osc_2_derv,
      osc_2_pwm_duty      => i_osc_2_pwm_duty,
      osc_2_wave_sel      => i_osc_2_wave_sel,
      speed1                => speed1,
      speed2                => speed2,
      col_en_bypass         => i_col_en_bypass,
      y_level             => i_y_level,
      cr_level            => i_cr_level,
      cb_level            => i_cb_level,
      video_active_o      => i_video_active_o,
      pix_clk_div_sel     => i_pix_clk_div_sel,
      ext_vid_in_mux_sel  => i_ext_vid_in_mux_sel,
      edge_width_sel      => i_edge_width_sel,
      ca_cfg              => i_ca_cfg,
      luma_key_enable     => i_luma_key_enable,
      luma_key_direction  => i_luma_key_direction,
      luma_key_thresh_low => i_luma_key_thresh_low,
      luma_key_thresh_high=> i_luma_key_thresh_high,
      osc1_alpha          => i_osc1_alpha,
      osc2_alpha          => i_osc2_alpha,
      dsm_hi_alpha        => i_dsm_hi_alpha,
      dsm_lo_alpha        => i_dsm_lo_alpha,
      noise_alpha         => i_noise_alpha,
      shape1_a_sel        => i_shape1_a_sel,
      shape1_b_sel        => i_shape1_b_sel,
      shape2_a_sel        => i_shape2_a_sel,
      shape2_b_sel        => i_shape2_b_sel,
      video_fx_ctrl     => i_video_fx_ctrl,
      video_fx_bitplane => i_video_fx_bitplane,
      video_fx_dither   => i_video_fx_dither,
      video_fx_mirror   => i_video_fx_mirror,
      video_fx_chromatic => i_video_fx_chromatic,
      video_fx_sharpness => i_video_fx_sharpness,
      overlay_global_en  => i_overlay_global_en,
      overlay_sprites    => i_overlay_sprites,
      frame_stats_luma_min => frame_stats_luma_min,
      frame_stats_luma_max => frame_stats_luma_max,
      frame_stats_luma_avg => frame_stats_luma_avg,
      frame_stats_r_min    => frame_stats_r_min,
      frame_stats_r_max    => frame_stats_r_max,
      frame_stats_r_avg    => frame_stats_r_avg,
      frame_stats_g_min    => frame_stats_g_min,
      frame_stats_g_max    => frame_stats_g_max,
      frame_stats_g_avg    => frame_stats_g_avg,
      frame_stats_b_min    => frame_stats_b_min,
      frame_stats_b_max    => frame_stats_b_max,
      frame_stats_b_avg    => frame_stats_b_avg,
      frame_stats_frame_id => frame_stats_frame_id,
      frame_stats_hash      => frame_stats_hash,
      frame_stats_pix_count => frame_stats_pix_count
--      debug               => i_debug,
--      exception_addr_o    => i_exception_addr_o
    );

    process (pix_clk) -- shift registers into the pixel clock domain
    begin
      if rising_edge(pix_clk) then
      matrix_out_addr   <= i_matrix_out_addr;
      matrix_mask_out     <= i_matrix_mask_out;
      matrix_load         <= i_matrix_load;
      invert_matrix       <= i_invert_matrix;
      vid_span            <= i_vid_span;
      out_addr            <= i_out_addr;
      ch_addr             <= i_ch_addr;
      gain_in             <= i_gain_in;
      anna_matrix_wr      <= i_anna_matrix_wr;
      pos_h_1             <= i_pos_h_1;
      pos_v_1             <= i_pos_v_1;
      zoom_h_1            <= i_zoom_h_1;
      zoom_v_1            <= i_zoom_v_1;
      circle_1            <= i_circle_1;
      gear_1              <= i_gear_1;
      lantern_1           <= i_lantern_1;
      fizz_1              <= i_fizz_1;
      pos_h_2             <= i_pos_h_2;
      pos_v_2             <= i_pos_v_2;
      zoom_h_2            <= i_zoom_h_2;
      zoom_v_2            <= i_zoom_v_2;
      circle_2            <= i_circle_2;
      gear_2              <= i_gear_2;
      lantern_2           <= i_lantern_2;
      fizz_2              <= i_fizz_2;
      noise_freq          <= i_noise_freq;
      slew_in             <= i_slew_in;
      cycle_recycle       <= i_cycle_recycle;
      sync_sel_osc1       <= i_sync_sel_osc1;
      osc_1_freq          <= i_osc_1_freq;
      osc_1_derv          <= i_osc_1_derv;
      osc_1_pwm_duty      <= i_osc_1_pwm_duty;
      osc_1_wave_sel      <= i_osc_1_wave_sel;
      sync_sel_osc2       <= i_sync_sel_osc2;
      osc_2_freq          <= i_osc_2_freq;
      osc_2_derv          <= i_osc_2_derv;
      osc_2_pwm_duty      <= i_osc_2_pwm_duty;
      osc_2_wave_sel      <= i_osc_2_wave_sel;
      col_en_bypass         <= i_col_en_bypass;
      y_level             <= i_y_level;
      cr_level            <= i_cr_level;
      cb_level            <= i_cb_level;
      video_active_o      <= i_video_active_o;
      pix_clk_div_sel     <= i_pix_clk_div_sel;
      ext_vid_in_mux_sel  <= i_ext_vid_in_mux_sel;
      edge_width_sel      <= i_edge_width_sel;
      ca_cfg              <= i_ca_cfg;
      luma_key_enable     <= i_luma_key_enable;
      luma_key_direction  <= i_luma_key_direction;
      luma_key_thresh_low <= i_luma_key_thresh_low;
      luma_key_thresh_high<= i_luma_key_thresh_high;
      osc1_alpha          <= i_osc1_alpha;
      osc2_alpha          <= i_osc2_alpha;
      dsm_hi_alpha        <= i_dsm_hi_alpha;
      dsm_lo_alpha        <= i_dsm_lo_alpha;
      noise_alpha         <= i_noise_alpha;
      shape1_a_sel        <= i_shape1_a_sel;
      shape1_b_sel        <= i_shape1_b_sel;
      shape2_a_sel        <= i_shape2_a_sel;
      shape2_b_sel        <= i_shape2_b_sel;
      video_fx_ctrl       <= i_video_fx_ctrl;
      video_fx_bitplane   <= i_video_fx_bitplane;
      video_fx_dither     <= i_video_fx_dither;
      video_fx_mirror     <= i_video_fx_mirror;
      video_fx_chromatic  <= i_video_fx_chromatic;
      video_fx_sharpness  <= i_video_fx_sharpness;
      overlay_global_en   <= i_overlay_global_en;
      overlay_sprites     <= i_overlay_sprites;
      end if;
    end process;


end rtl;
