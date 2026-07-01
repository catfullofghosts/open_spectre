--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: spector_wrapper_zynq by RD Jordan
-- Created: 2025
-- Description: EMS Spectron Global Wrapper
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.vcomponents.all;

use work.overlay_sprite_pkg.all;

entity spector_wrapper_zynq is
  port (
    pix_clk : in std_logic;
    reset       : in std_logic; -- using pixel clock lock (which is active HIGH)

    h_sync         : in std_logic; -- horizontal sync 
    v_sync         : in std_logic; -- vertical sync 
    start_of_frame : in std_logic; -- this si start of line or some shit, not start of frame
    ext_video      : in std_logic_vector(23 downto 0); --external video data for the 
    vid_in_mux      : in std_logic; -- bypass the ems and route the input to the output

    h_sync_o         : out std_logic; -- horizontal sync 
    v_sync_o         : out std_logic; -- vertical sync 
    start_of_frame_o : out std_logic; -- 

    regs_clk     : in std_logic;
    regs_en      : in std_logic;
    regs_wen     : in std_logic_vector(3 downto 0);
    regs_addr    : in std_logic_vector(12 downto 0);
    regs_wr_data : in std_logic_vector(31 downto 0);
    regs_rd_data : out std_logic_vector(31 downto 0);
    video_out    : out std_logic_vector(23 downto 0)
  );
end entity spector_wrapper_zynq;

architecture rtl of spector_wrapper_zynq is
  -----------------------------------------------------------------
  -- Clocks
--  signal pix_clk    : std_logic;
  signal pix_clk_en : std_logic := '0'; -- enable signal (half rate of clk_148_5)

  ---------------------------------------------------------------
  -- Video Timing generator
   signal h_sync_n : std_logic; -- horizontal sync output inverted
   signal v_sync_n : std_logic; -- vertical sync output inverted
   signal reset_n : std_logic; -- inverted reset
  -- signal video_on                   : std_logic; -- video on/off output
  -- signal start_of_frame : std_logic; -- start of frame output
  -- signal start_of_active_video : std_logic; -- start of active video output
  signal frame_counter : std_logic_vector(3 downto 0); -- 4-bit frame counter
  signal start_of_frame_n : std_logic;
--   signal h_sync_n                : std_logic; -- horizontal sync output
  -- signal h_sync_d              : std_logic; -- horizontal sync output delayed
  -- signal h_sync_re             : std_logic; -- horizontal sync output rising edge
  ------------------------------------------------------------
  -- Registers
  -- signal regs_clk     : std_logic;
  -- signal regs_en      : std_logic;
  -- signal regs_wen     : std_logic_vector(3 downto 0);
  -- signal regs_addr    : std_logic_vector(12 downto 0);
  -- signal regs_wr_data : std_logic_vector(31 downto 0);
  -- signal regs_rd_data : std_logic_vector(31 downto 0);

  -- Digital Matrix Control
  signal matrix_out_addr : std_logic_vector(5 downto 0);
  signal matrix_mask_out : std_logic_vector(63 downto 0);
  signal matrix_load     : std_logic;
  signal invert_matrix   : std_logic_vector(63 downto 0);
  -- Video Input Control
  signal vid_span : std_logic_vector(7 downto 0);
  -- Analoge Matrix Control
  signal out_addr       : std_logic_vector(7 downto 0);
  signal ch_addr        : std_logic_vector(7 downto 0);
  signal gain_in        : std_logic_vector(15 downto 0);
  signal anna_matrix_wr : std_logic;

  -- rotery encoders
  signal rotery_addr_mux     : std_logic_vector(3 downto 0);
  signal rotery_enc_0        : std_logic_vector(31 downto 0);
  signal rotery_enc_1        : std_logic_vector(31 downto 0);
  signal rotery_enc_2        : std_logic_vector(31 downto 0);
  signal rotery_enc_3        : std_logic_vector(31 downto 0);
  signal rotery_enc_4        : std_logic_vector(31 downto 0);
  signal rotery_enc_preset_w : std_logic;
  signal rotery_enc_0_preset : std_logic_vector(31 downto 0);
  signal rotery_enc_1_preset : std_logic_vector(31 downto 0);
  signal rotery_enc_2_preset : std_logic_vector(31 downto 0);
  signal rotery_enc_3_preset : std_logic_vector(31 downto 0);
  signal rotery_enc_4_preset : std_logic_vector(31 downto 0);
  -- buttons
  signal button_matrix : std_logic_vector(31 downto 0);
  -- leds
  signal led_output     : std_logic_vector(31 downto 0);
  signal led_global_pwm : std_logic_vector(31 downto 0);
  signal lcd_backligh   : std_logic;
  -- fans
  signal fan_pwm : std_logic_vector(31 downto 0);
  signal fan_rpm : std_logic_vector(31 downto 0);

  -- Shape gen
  signal pos_h_1   : std_logic_vector(11 downto 0);
  signal pos_v_1   : std_logic_vector(11 downto 0);
  signal zoom_h_1  : std_logic_vector(11 downto 0);
  signal zoom_v_1  : std_logic_vector(11 downto 0);
  signal circle_1  : std_logic_vector(11 downto 0);
  signal gear_1    : std_logic_vector(11 downto 0);
  signal lantern_1 : std_logic_vector(11 downto 0);
  signal fizz_1    : std_logic_vector(11 downto 0);
  signal pos_h_2   : std_logic_vector(11 downto 0);
  signal pos_v_2   : std_logic_vector(11 downto 0);
  signal zoom_h_2  : std_logic_vector(11 downto 0);
  signal zoom_v_2  : std_logic_vector(11 downto 0);
  signal circle_2  : std_logic_vector(11 downto 0);
  signal gear_2    : std_logic_vector(11 downto 0);
  signal lantern_2 : std_logic_vector(11 downto 0);
  signal fizz_2    : std_logic_vector(11 downto 0);

  -- noise gen
  signal noise_freq    : std_logic_vector(13 downto 0);
  signal slew_in       : std_logic_vector(2 downto 0);
  signal cycle_recycle : std_logic;
  -- osc 1 & 2
  signal sync_sel_osc1 : std_logic_vector(1 downto 0);
  signal osc_1_freq    : std_logic_vector(13 downto 0);
  signal osc_1_derv    : std_logic_vector(7 downto 0);
  signal osc_1_pwm_duty : std_logic_vector(8 downto 0);
  signal osc_1_wave_sel : std_logic_vector(1 downto 0);
  signal sync_sel_osc2 : std_logic_vector(1 downto 0);
  signal osc_2_freq    : std_logic_vector(13 downto 0);
  signal osc_2_derv    : std_logic_vector(7 downto 0);
  signal osc_2_pwm_duty : std_logic_vector(8 downto 0);
  signal osc_2_wave_sel : std_logic_vector(1 downto 0);
  signal speed1 : std_logic;
  signal speed2 : std_logic;
  -- Output Levels & output Active
  signal y_level        : std_logic_vector(11 downto 0);
  signal cr_level       : std_logic_vector(11 downto 0);
  signal cb_level       : std_logic_vector(11 downto 0);
  signal video_active_o : std_logic;

  signal shape1_a      : std_logic;
  signal shape1_b      : std_logic;
  signal c148_shape1_a : std_logic;
  signal c148_shape1_b : std_logic;

  signal shape2_a      : std_logic;
  signal shape2_b      : std_logic;
  signal c148_shape2_a : std_logic;
  signal c148_shape2_b : std_logic;

  -- X/Y counter pixel/line from digital side
  signal x_in   : std_logic_vector(8 downto 0) := (others => '0');
  signal y_in   : std_logic_vector(8 downto 0) := (others => '0');
  signal x_in74 : std_logic_vector(8 downto 0) := (others => '0');
  signal y_in74 : std_logic_vector(8 downto 0) := (others => '0');

  ------------------------------------------------------
  -- Digital side
  signal YCRCB : std_logic_vector (23 downto 0);
  -- Controls
  signal matrix_in_addr : std_logic_vector(5 downto 0);
  --  signal matrix_load    : std_logic;
  signal matrix_mask_in : std_logic_vector(63 downto 0); --controls which inputs are routed to a selected output
  -- signal invert_matrix  : std_logic_vector(63 downto 0); --inverts a matrix input globaly
  signal ext_vid_in : std_logic_vector(7 downto 0);
  --signal vid_span       : std_logic_vector(7 downto 0);
  -- inputs form analoge side
  signal osc1_sqr : std_logic := '0';
  signal osc2_sqr : std_logic := '0';
  signal random1  : std_logic := '0';
  signal random2  : std_logic := '0';
  signal audio_T  : std_logic := '0';
  signal audio_B  : std_logic := '0';
  signal extinput : std_logic := '0';
  -- outputs to analoge side
  signal shape_a_analog : std_logic_vector(7 downto 0);
  signal shape_b_analog : std_logic_vector(7 downto 0);
  signal acm_out1_o     : std_logic;
  signal acm_out2_o     : std_logic;

  ----------------------------------------------------------------
  --Analog Side
  signal wr_ann : std_logic;
  --  signal out_addr :  std_logic_vector(7 downto 0);
  signal gain_out : std_logic_vector(15 downto 0);
  --  signal gain_in  :  std_logic_vector(15 downto 0);
  --analoge controls from reg file -- these should be added ot the matrix outputs so that you always have cxontroll of these things, these ins act as an offset
  --  signal pos_h_1   : std_logic_vector(11 downto 0);
  --  signal pos_v_1   : std_logic_vector(11 downto 0);
  --  signal zoom_h_1  : std_logic_vector(11 downto 0);
  --  signal zoom_v_1  : std_logic_vector(11 downto 0);
  --  signal circle_1  : std_logic_vector(11 downto 0);
  --  signal gear_1    : std_logic_vector(11 downto 0);
  --  signal lantern_1 : std_logic_vector(11 downto 0);
  --  signal fizz_1    : std_logic_vector(11 downto 0);
  --  signal pos_h_2   : std_logic_vector(11 downto 0);
  --  signal pos_v_2   : std_logic_vector(11 downto 0);
  --  signal zoom_h_2  : std_logic_vector(11 downto 0);
  --  signal zoom_v_2  : std_logic_vector(11 downto 0);
  --  signal circle_2  : std_logic_vector(11 downto 0);
  --  signal gear_2    : std_logic_vector(11 downto 0);
  --  signal lantern_2 : std_logic_vector(11 downto 0);
  --  signal fizz_2    : std_logic_vector(11 downto 0);
  --random
  --  signal noise_freq    : std_logic_vector(9 downto 0);
  --  signal slew_in       : std_logic_vector(2 downto 0);
  --  signal cycle_recycle : std_logic;
  -- Video from the digital side
  signal YUV_in  : std_logic_vector(23 downto 0);
  signal y_alpha : std_logic_vector(11 downto 0); -- 0 is unattenuated, 
  signal u_alpha : std_logic_vector(11 downto 0); -- 0 is unattenuated, 
  signal v_alpha : std_logic_vector(11 downto 0); -- 0 is unattenuated, 

  signal audio_in_t   : std_logic_vector(9 downto 0);
  signal audio_in_b   : std_logic_vector(9 downto 0);
  signal audio_in_sig : std_logic_vector(9 downto 0);

  --osc control
  --  signal sync_sel_osc1 : std_logic_vector(1 downto 0);
  --  signal osc_1_freq    : std_logic_vector(9 downto 0);
  --  signal osc_1_derv    : std_logic_vector(7 downto 0);
  --signals from the digital side
  signal dsm_hi_i      : std_logic_vector(9 downto 0);
  signal dsm_lo_nofilt : std_logic_vector(9 downto 0);
  signal dsm_lo_i      : std_logic_vector(9 downto 0);
  -- signals passed to the digital side (not in original design but i think they are cool)
  --  signal vid_span    : std_logic_vector(7 downto 0);
  signal osc_1_sqr_o : std_logic;
  signal osc_2_sqr_o : std_logic;
  signal noise_1_o   : std_logic;
  signal noise_2_o   : std_logic;
  signal noise_rst   : std_logic;
  signal slowdown_sel : std_logic_vector(1 downto 0);
  
  -- Pipeline registers for noise generator signals (to break combinatorial paths)
  signal noise_freq_reg    : std_logic_vector(13 downto 0);
  signal slew_in_reg       : std_logic_vector(2 downto 0);
  signal cycle_recycle_reg : std_logic;
  signal noise_rst_reg     : std_logic;
  signal slowdown_sel_reg  : std_logic_vector(1 downto 0);
  
  -- Pipeline registers for Y/Cr/Cb level signals (to break combinatorial paths)
  signal y_alpha_reg : std_logic_vector(11 downto 0);
  signal u_alpha_reg : std_logic_vector(11 downto 0);
  signal v_alpha_reg : std_logic_vector(11 downto 0);

  -- Signals sent to the shape generator
  signal matrix_pos_h_1   : std_logic_vector(11 downto 0);
  signal matrix_pos_v_1   : std_logic_vector(11 downto 0);
  signal matrix_zoom_h_1  : std_logic_vector(11 downto 0);
  signal matrix_zoom_v_1  : std_logic_vector(11 downto 0);
  signal matrix_circle_1  : std_logic_vector(11 downto 0);
  signal matrix_gear_1    : std_logic_vector(11 downto 0);
  signal matrix_lantern_1 : std_logic_vector(11 downto 0);
  signal matrix_fizz_1    : std_logic_vector(11 downto 0);
  signal matrix_pos_h_2   : std_logic_vector(11 downto 0);
  signal matrix_pos_v_2   : std_logic_vector(11 downto 0);
  signal matrix_zoom_h_2  : std_logic_vector(11 downto 0);
  signal matrix_zoom_v_2  : std_logic_vector(11 downto 0);
  signal matrix_circle_2  : std_logic_vector(11 downto 0);
  signal matrix_gear_2    : std_logic_vector(11 downto 0);
  signal matrix_lantern_2 : std_logic_vector(11 downto 0);
  signal matrix_fizz_2    : std_logic_vector(11 downto 0);

  signal y_out : std_logic_vector(7 downto 0);
  signal u_out : std_logic_vector(7 downto 0);
  signal v_out : std_logic_vector(7 downto 0);

  -- Pixel clock and video input control from CPU registers
  signal pix_clk_div_sel    : std_logic;
  signal ext_vid_in_mux_sel : std_logic;
  -- Luma key control
  signal luma_key_enable     : std_logic;
  signal luma_key_direction  : std_logic;
  signal luma_key_thresh_low : std_logic_vector(7 downto 0);
  signal luma_key_thresh_high: std_logic_vector(7 downto 0);
  signal ext_video_keyed     : std_logic_vector(23 downto 0);
  signal luma_key_valid      : std_logic := '0'; -- tied low until luma_key is enabled
  -- Alpha controls for analog side (from registers)
  signal osc1_alpha_reg     : std_logic_vector(11 downto 0);
  signal osc2_alpha_reg     : std_logic_vector(11 downto 0);
  signal dsm_hi_alpha_reg   : std_logic_vector(11 downto 0);
  signal dsm_lo_alpha_reg   : std_logic_vector(11 downto 0);
  signal noise_alpha_reg    : std_logic_vector(11 downto 0);
  -- Shape select controls (from registers)
  signal shape1_a_sel_reg   : std_logic_vector(3 downto 0);
  signal shape1_b_sel_reg   : std_logic_vector(3 downto 0);
  signal shape2_a_sel_reg   : std_logic_vector(3 downto 0);
  signal shape2_b_sel_reg   : std_logic_vector(3 downto 0);
  signal video_fx_ctrl      : std_logic_vector(31 downto 0);
  signal video_fx_bitplane  : std_logic_vector(31 downto 0);
  signal video_fx_dither    : std_logic_vector(31 downto 0);
  signal video_fx_mirror    : std_logic_vector(31 downto 0);
  signal video_fx_chromatic : std_logic_vector(31 downto 0);
  signal video_fx_sharpness : std_logic_vector(31 downto 0);
  signal overlay_global_en  : std_logic;
  signal overlay_sprites      : t_sprite_array;
  signal overlay_key        : std_logic;
  signal overlay_rgb        : std_logic_vector(23 downto 0);

  signal reg_en               : std_logic;
  signal reg_we               : std_logic_vector(3 downto 0);
  signal reg_addr             : std_logic_vector(12 downto 0);
  signal reg_wdata            : std_logic_vector(31 downto 0);
  signal reg_rdata            : std_logic_vector(31 downto 0);
  signal overlay_bram_en      : std_logic;
  signal overlay_bram_we      : std_logic_vector(3 downto 0);
  signal overlay_bram_addr    : std_logic_vector(10 downto 0);
  signal overlay_bram_wdata   : std_logic_vector(31 downto 0);
  signal overlay_bram_rdata   : std_logic_vector(31 downto 0);

  -- Background video signals (for compositing)
  signal bg_video            : std_logic_vector(23 downto 0);
  signal bg_video_reg1       : std_logic_vector(23 downto 0);
  signal bg_video_reg2       : std_logic_vector(23 downto 0);

  ----------------------------------------------
  -- Video Out
  signal col_en_bypass   : std_logic;
  signal y_out_padded : std_logic_vector(10 downto 0);
  signal u_out_padded : std_logic_vector(10 downto 0);
  signal v_out_padded : std_logic_vector(10 downto 0);
  signal red          : std_logic_vector(7 downto 0);
  signal green        : std_logic_vector(7 downto 0);
  signal blue         : std_logic_vector(7 downto 0);
  signal video_pre_fx : std_logic_vector(23 downto 0);
  signal video_fx_out : std_logic_vector(23 downto 0);

  signal frame_stats_luma_min : std_logic_vector(7 downto 0);
  signal frame_stats_luma_max : std_logic_vector(7 downto 0);
  signal frame_stats_luma_avg : std_logic_vector(7 downto 0);
  signal frame_stats_r_min    : std_logic_vector(7 downto 0);
  signal frame_stats_r_max    : std_logic_vector(7 downto 0);
  signal frame_stats_r_avg    : std_logic_vector(7 downto 0);
  signal frame_stats_g_min    : std_logic_vector(7 downto 0);
  signal frame_stats_g_max    : std_logic_vector(7 downto 0);
  signal frame_stats_g_avg    : std_logic_vector(7 downto 0);
  signal frame_stats_b_min    : std_logic_vector(7 downto 0);
  signal frame_stats_b_max    : std_logic_vector(7 downto 0);
  signal frame_stats_b_avg    : std_logic_vector(7 downto 0);
  signal frame_stats_frame_id : std_logic_vector(7 downto 0);
  signal frame_stats_hash      : std_logic_vector(31 downto 0);
  signal frame_stats_pix_count : std_logic_vector(31 downto 0);

    attribute DONT_TOUCH                 : string;
  --  attribute MARK_DEBUG of clk_148_5    : signal is "TRUE";
    attribute DONT_TOUCH of luma_key_enable    : signal is "TRUE";
    attribute DONT_TOUCH of luma_key_direction : signal is "TRUE";
    attribute DONT_TOUCH of acm_out1_o        : signal is "TRUE";
    attribute DONT_TOUCH of acm_out2_o        : signal is "TRUE";
  --  attribute MARK_DEBUG of v_out        : signal is "TRUE";
  --  attribute MARK_DEBUG of shape1_a     : signal is "TRUE";
  --  attribute MARK_DEBUG of shape1_b     : signal is "TRUE";
  --  attribute MARK_DEBUG of shape2_a     : signal is "TRUE";
  --  attribute MARK_DEBUG of shape2_b     : signal is "TRUE";
  --  attribute MARK_DEBUG of red          : signal is "TRUE";
  --  attribute MARK_DEBUG of green        : signal is "TRUE";
  --  attribute MARK_DEBUG of blue         : signal is "TRUE";

begin

  
    process (h_sync,v_sync,reset,start_of_frame )
  begin
    h_sync_n <= not h_sync;
    v_sync_n <= not v_sync;
    reset_n <= not reset;
    start_of_frame_n <= not start_of_frame;
    
  end process;
  
  process (pix_clk)
  begin
    if rising_edge(pix_clk) then -- make adjustible by the regs
        h_sync_o         <= h_sync;
        v_sync_o         <= v_sync;
        start_of_frame_o <= start_of_frame;
    end if;
  end process;


  --

  overlay_cpu_mux_inst : entity work.overlay_cpu_mux
    generic map (
      G_BYTE_BASE  => std_logic_vector(to_unsigned(16#400#, 13)),
      G_ADDR_WIDTH => 11
    )
    port map (
      cpu_clk   => regs_clk,
      cpu_en    => regs_en,
      cpu_we    => regs_wen,
      cpu_addr  => regs_addr,
      cpu_wdata => regs_wr_data,
      cpu_rdata => regs_rd_data,
      reg_en      => reg_en,
      reg_we      => reg_we,
      reg_addr    => reg_addr,
      reg_wdata   => reg_wdata,
      reg_rdata   => reg_rdata,
      bram_en     => overlay_bram_en,
      bram_we     => overlay_bram_we,
      bram_addr   => overlay_bram_addr,
      bram_wdata  => overlay_bram_wdata,
      bram_rdata  => overlay_bram_rdata
    );

  cpu_reg_wrapper_inst : entity work.cpu_reg_wrapper
    port map
    (
      clk                 => regs_clk,
      pix_clk             => pix_clk,
      rst                 => reset_n,
      regs_en             => reg_en,
      regs_wen            => reg_we,
      regs_addr           => reg_addr,
      regs_wr_data        => reg_wdata,
      regs_rd_data        => reg_rdata,
      matrix_out_addr     => matrix_in_addr,
      matrix_mask_out     => matrix_mask_in,
      matrix_load         => matrix_load,
      invert_matrix       => invert_matrix,
      vid_span            => vid_span,
      out_addr            => out_addr,
      ch_addr             => ch_addr,
      gain_in             => gain_in,
      anna_matrix_wr      => anna_matrix_wr,
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
      pos_h_1             => pos_h_1,
      pos_v_1             => pos_v_1,
      zoom_h_1            => zoom_h_1,
      zoom_v_1            => zoom_v_1,
      circle_1            => circle_1,
      gear_1              => gear_1,
      lantern_1           => lantern_1,
      fizz_1              => fizz_1,
      pos_h_2             => pos_h_2,
      pos_v_2             => pos_v_2,
      zoom_h_2            => zoom_h_2,
      zoom_v_2            => zoom_v_2,
      circle_2            => circle_2,
      gear_2              => gear_2,
      lantern_2           => lantern_2,
      fizz_2              => fizz_2,
      noise_freq          => noise_freq,
      slew_in             => slew_in,
      cycle_recycle       => cycle_recycle,
      noise_rst           => noise_rst,
      slowdown_sel        => slowdown_sel,
      sync_sel_osc1       => sync_sel_osc1,
      osc_1_freq          => osc_1_freq,
      osc_1_derv          => osc_1_derv,
      osc_1_pwm_duty      => osc_1_pwm_duty,
      osc_1_wave_sel      => osc_1_wave_sel,
      sync_sel_osc2       => sync_sel_osc2,
      osc_2_freq          => osc_2_freq,
      osc_2_derv          => osc_2_derv,
      osc_2_pwm_duty      => osc_2_pwm_duty,
      osc_2_wave_sel      => osc_2_wave_sel,
      speed1                => speed1,
      speed2                => speed2,
      col_en_bypass     => col_en_bypass,
      y_level             => y_alpha,
      cr_level            => u_alpha,
      cb_level            => v_alpha,
      video_active_o      => video_active_o,
      pix_clk_div_sel     => pix_clk_div_sel,
      ext_vid_in_mux_sel  => ext_vid_in_mux_sel,
      luma_key_enable     => luma_key_enable,
      luma_key_direction  => luma_key_direction,
      luma_key_thresh_low => luma_key_thresh_low,
      luma_key_thresh_high=> luma_key_thresh_high,
      osc1_alpha          => osc1_alpha_reg,
      osc2_alpha          => osc2_alpha_reg,
      dsm_hi_alpha        => dsm_hi_alpha_reg,
      dsm_lo_alpha        => dsm_lo_alpha_reg,
      noise_alpha         => noise_alpha_reg,
      shape1_a_sel        => shape1_a_sel_reg,
      shape1_b_sel        => shape1_b_sel_reg,
      shape2_a_sel        => shape2_a_sel_reg,
      shape2_b_sel        => shape2_b_sel_reg,
      video_fx_ctrl       => video_fx_ctrl,
      video_fx_bitplane   => video_fx_bitplane,
      video_fx_dither     => video_fx_dither,
      video_fx_mirror     => video_fx_mirror,
      video_fx_chromatic  => video_fx_chromatic,
      video_fx_sharpness  => video_fx_sharpness,
      overlay_global_en   => overlay_global_en,
      overlay_sprites     => overlay_sprites,
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
    );

  overlay_framebuffer_inst : entity work.overlay_framebuffer
    generic map (
      G_DEPTH      => 2048,
      G_ADDR_WIDTH => 11
    )
    port map (
      cpu_clk    => regs_clk,
      cpu_en     => overlay_bram_en,
      cpu_we     => overlay_bram_we,
      cpu_addr   => overlay_bram_addr,
      cpu_wdata  => overlay_bram_wdata,
      cpu_rdata  => overlay_bram_rdata,
      pix_clk    => pix_clk,
      pix_rst    => reset,
      h_sync     => h_sync,
      v_sync     => v_sync,
      global_enable => overlay_global_en,
      sprites      => overlay_sprites,
      overlay_key => overlay_key,
      overlay_rgb => overlay_rgb
    );

  -------------------------------------------
  -- Digital Side
  -------------------------------------------
  pixel_clk_en_p : process (pix_clk) ---- TEMP FOR NOW NEEDS adjustible so we can pick the aperent resolution of the digital side
    variable clk_div_counter : unsigned(1 downto 0) := "00";
  begin
    if rising_edge (pix_clk) then
      if pix_clk_div_sel = '0' then
        -- /2 division (original behavior) - toggle every clock
        pix_clk_en <= not pix_clk_en;
        clk_div_counter := "00";
      else
        -- /4 division - toggle every 2 clocks (counter 0 and 2)
        clk_div_counter := clk_div_counter + 1;
        if clk_div_counter(0) = '0' then  -- toggle when counter is even (0 or 2)
          pix_clk_en <= not pix_clk_en;
        end if;
        if clk_div_counter = "11" then
          clk_div_counter := "00";
        end if;
      end if;

      -- Mux for ext_vid_in: select between luma calculation or y_out
      if ext_vid_in_mux_sel = '0' then
        ext_vid_in <= std_logic_vector( ( unsigned(ext_video(23 downto 16)) + unsigned(ext_video(15 downto 8)) + unsigned(ext_video(7 downto 0)) ) /3) ;
        -- calculate luma of incoming video
      else
        ext_vid_in <= y_out;
      end if;

    end if;
  end process;

  digital_side_inst : entity work.digital_side
    port map
    (
      sys_clk        => pix_clk,
      h_sync         => h_sync_n, -- needs delya = to shape gen delay
      v_sync         => v_sync_n, -- needs delya = to shape gen delay
      pix_clk        => pix_clk_en, -- pixel clk (is actualy enables on every pixel clock)
      rst            => reset_n,
      YCRCB          => YCRCB,
      matrix_in_addr => matrix_in_addr,
      matrix_load    => matrix_load,
      matrix_mask_in => matrix_mask_in,
      invert_matrix  => invert_matrix,
      ext_vid_in     => ext_vid_in,
      vid_span       => vid_span,
      osc1_sqr       => osc_1_sqr_o,
      osc2_sqr       => osc_2_sqr_o,
      random1        => noise_1_o,
      random2        => noise_2_o,
      audio_T        => audio_T,
      audio_B        => audio_B,
      extinput       => extinput,
      shape1_a       => c148_shape1_a,
      shape1_b       => c148_shape1_b,
      shape2_a       => c148_shape2_a,
      shape2_b       => c148_shape2_b,
      --      shape_a_analog => shape_a_analog,
      --      shape_b_analog => shape_b_analog,
      acm_out1_o => acm_out1_o,
      acm_out2_o => acm_out2_o,
      x_count_o  => x_in,
      y_count_o  => y_in
    );

  -------------------------------------------
  -- Analog Side
  -------------------------------------------
  dsm_hi_i      <= acm_out1_o & acm_out1_o & acm_out1_o & acm_out1_o & acm_out1_o & acm_out1_o & acm_out1_o & acm_out1_o & acm_out1_o & acm_out1_o; -- this signla from digital side has no slew
  dsm_lo_nofilt <= acm_out2_o & acm_out2_o & acm_out2_o & acm_out2_o & acm_out2_o & acm_out2_o & acm_out2_o & acm_out2_o & acm_out2_o & acm_out2_o;

  -- Pipeline registers for noise and Y/Cr/Cb signals to break combinatorial paths
  noise_pipeline_p : process (pix_clk)
  begin
    if rising_edge(pix_clk) then
      noise_freq_reg    <= noise_freq;
      slew_in_reg       <= slew_in;
      cycle_recycle_reg <= cycle_recycle;
      noise_rst_reg     <= noise_rst;
      slowdown_sel_reg  <= slowdown_sel;
    end if;
  end process;

  yuv_pipeline_p : process (pix_clk)
  begin
    if rising_edge(pix_clk) then
      y_alpha_reg <= y_alpha;
      u_alpha_reg <= u_alpha;
      v_alpha_reg <= v_alpha;
    end if;
  end process;

  slew_dsm_low : entity work.moving_average -- dsm_low is a slewed version of dsm hi
    generic map(
      G_NBIT      => 10,
      G_MAX_DELTA => 2 -- fine turne with actual x5
    )
    port map
    (
      i_clk        => pix_clk,
      i_rstb       => reset,
      i_sync_reset => reset,
      i_data_ena   => '1',
      i_data       => dsm_lo_nofilt,
      o_data_valid => open,
      o_data       => dsm_lo_i
    );

  YUV_in <= YCRCB;-- pass the video out from the digital side to the analoge side

  analog_side_inst : entity work.analog_side
    port map
    (
      clk              => pix_clk,
      rst              => reset_n,
      wr               => anna_matrix_wr,
      vsync            => v_sync_n, -- needs delya = to shape gen delay
      hsync            => h_sync_n, -- needs delya = to shape gen delay
      out_addr         => out_addr,
      gain_out         => gain_out,
      gain_in          => gain_in,
      pos_h_1          => pos_h_1,
      pos_v_1          => pos_v_1,
      zoom_h_1         => zoom_h_1,
      zoom_v_1         => zoom_v_1,
      circle_1         => circle_1,
      gear_1           => gear_1,
      lantern_1        => lantern_1,
      fizz_1           => fizz_1,
      pos_h_2          => pos_h_2,
      pos_v_2          => pos_v_2,
      zoom_h_2         => zoom_h_2,
      zoom_v_2         => zoom_v_2,
      circle_2         => circle_2,
      gear_2           => gear_2,
      lantern_2        => lantern_2,
      fizz_2           => fizz_2,
      noise_freq       => noise_freq_reg,
      slew_in          => slew_in_reg,
      cycle_recycle    => cycle_recycle_reg,
      noise_alpha      => noise_alpha_reg,
      slowdown_sel     => slowdown_sel_reg,
      YUV_in           => YUV_in,
      y_alpha          => y_alpha_reg,
      u_alpha          => u_alpha_reg,
      v_alpha          => v_alpha_reg,
      audio_in_t       => audio_in_t,
      audio_in_b       => audio_in_b,
      audio_in_sig     => audio_in_sig,
      sync_sel_osc1    => sync_sel_osc1,
      osc_1_freq       => osc_1_freq,
      osc_1_derv       => osc_1_derv,
      osc_1_pwm_duty   => osc_1_pwm_duty,
      osc_1_wave_sel   => osc_1_wave_sel,
      osc1_alpha       => osc1_alpha_reg,
      sync_sel_osc2    => sync_sel_osc2,
      osc_2_freq       => osc_2_freq,
      osc_2_derv       => osc_2_derv,
      osc_2_pwm_duty   => osc_2_pwm_duty,
      osc_2_wave_sel   => osc_2_wave_sel,
      osc2_alpha       => osc2_alpha_reg,
      speed1           => speed1,
      speed2           => speed2,
      dsm_hi_i         => dsm_hi_i,
      dsm_hi_alpha     => dsm_hi_alpha_reg,
      dsm_lo_i         => dsm_lo_i,
      dsm_lo_alpha     => dsm_lo_alpha_reg,
      vid_span         => open,--vid_span, disabled for the moment while i work out what to do with it
      osc_1_sqr_o      => osc_1_sqr_o,
      osc_2_sqr_o      => osc_2_sqr_o,
      noise_1_o        => noise_1_o,
      noise_2_o        => noise_2_o,
      noise_rst        => noise_rst_reg,
      matrix_pos_h_1   => matrix_pos_h_1,
      matrix_pos_v_1   => matrix_pos_v_1,
      matrix_zoom_h_1  => matrix_zoom_h_1,
      matrix_zoom_v_1  => matrix_zoom_v_1,
      matrix_circle_1  => matrix_circle_1,
      matrix_gear_1    => matrix_gear_1,
      matrix_lantern_1 => matrix_lantern_1,
      matrix_fizz_1    => matrix_fizz_1,
      matrix_pos_h_2   => matrix_pos_h_2,
      matrix_pos_v_2   => matrix_pos_v_2,
      matrix_zoom_h_2  => matrix_zoom_h_2,
      matrix_zoom_v_2  => matrix_zoom_v_2,
      matrix_circle_2  => matrix_circle_2,
      matrix_gear_2    => matrix_gear_2,
      matrix_lantern_2 => matrix_lantern_2,
      matrix_fizz_2    => matrix_fizz_2,
      y_out            => y_out,
      u_out            => u_out,
      v_out            => v_out
    );

  -------------------------------------------
  -- Shape Generator
  -------------------------------------------
  process (pix_clk)
  begin
    if rising_edge (pix_clk) then
      x_in74 <= x_in;
      y_in74 <= y_in;

    end if;
  end process;

  process (pix_clk)
  begin
    if rising_edge (pix_clk) then
      c148_shape1_a <= shape1_a;
      c148_shape1_b <= shape1_b;
      c148_shape2_a <= shape2_a;
      c148_shape2_b <= shape2_b;

    end if;
  end process;

  shape_gen1 : entity work.shape_gen
    port map
    (
      clk                   => pix_clk, --clk_148_5,
      rst                   => reset_n,
      h_sync                => h_sync, --negated inside the module
      v_sync                => v_sync, --negated inside the module
      start_of_frame        => start_of_frame_n,
      start_of_active_video => '0',
      video_on              => '0',
      pos_h                 => matrix_pos_h_1,
      pos_v                 => matrix_pos_v_1,
      zoom_h                => matrix_zoom_h_1,
      zoom_v                => matrix_zoom_v_1,
      circle_i              => matrix_circle_1,
      gear_i                => matrix_gear_1,
      lantern_i             => matrix_lantern_1,
      fizz_i                => matrix_fizz_1,
      shape_a_sel           => shape1_a_sel_reg,
      shape_b_sel           => shape1_b_sel_reg,
      x_in                  => x_in, -- digital side x
      y_in                  => y_in, -- digital side y
      shape_a               => shape1_a,
      shape_b               => shape1_b
    );

  shape_gen2 : entity work.shape_gen
    port map
    (
      clk                   => pix_clk, --clk_148_5,
      rst                   => reset_n,
      h_sync                => h_sync, --negated inside the module
      v_sync                => v_sync, --negated inside the module
      start_of_frame        => start_of_frame_n,
      start_of_active_video => '0',
      video_on              => '0',
      pos_h                 => matrix_pos_h_2,
      pos_v                 => matrix_pos_v_2,
      zoom_h                => matrix_zoom_h_2,
      zoom_v                => matrix_zoom_v_2,
      circle_i              => matrix_circle_2,
      gear_i                => matrix_gear_2,
      lantern_i             => matrix_lantern_2,
      fizz_i                => matrix_fizz_2,
      shape_a_sel           => shape2_a_sel_reg,
      shape_b_sel           => shape2_b_sel_reg,
      x_in                  => x_in, --digital side x
      y_in                  => y_in, --digital side y
      shape_a               => shape2_a,
      shape_b               => shape2_b
    );

  -------------------------------------------
  -- Luma Key
  -------------------------------------------
--  luma_key_inst : entity work.luma_key
--    port map
--    (
--      clk            => pix_clk,
--      rst            => reset,
--      enable         => luma_key_enable,
--      direction      => luma_key_direction,
--      threshold_low  => luma_key_thresh_low,
--      threshold_high => luma_key_thresh_high,
--      video_in       => ext_video,
--      video_out      => ext_video_keyed,
--      key_valid      => luma_key_valid
--    );

  -------------------------------------------
  -- Video Output
  -------------------------------------------
     color_encoder_inst : entity work.color_encoder
        port map (
            clk        => pix_clk,
            y          => y_out,
            c1         => u_out,
            c2         => v_out,
            swap_early => '0',
            red        => red,
            green      => green,
            blue       => blue
        );

  -- Select background video based on col_en_bypass, then overlay BRAM sprite
  process (pix_clk)
    variable encoder_video : std_logic_vector(23 downto 0);
  begin
    if rising_edge (pix_clk) then
      if col_en_bypass = '1' then
        encoder_video := y_out & u_out & v_out;
      else
        encoder_video := blue & green & red;
      end if;

      if overlay_key = '1' then
        bg_video_reg1 <= overlay_rgb;
      else
        bg_video_reg1 <= encoder_video;
      end if;

      bg_video_reg2 <= bg_video_reg1;
      bg_video <= bg_video_reg2;
    end if;
  end process;

  -- Composite source, then final pixel effects before output
  process (pix_clk)
  begin
    if rising_edge (pix_clk) then
      if vid_in_mux = '0' then
        video_pre_fx <= bg_video;
      else
        if luma_key_enable = '1' then
          if luma_key_valid = '1' then
            video_pre_fx <= bg_video;
          else
            video_pre_fx <= ext_video;
          end if;
        else
          video_pre_fx <= ext_video;
        end if;
      end if;
    end if;
  end process;

  video_effects_inst : entity work.video_effects
    port map (
      clk       => pix_clk,
      rst       => reset,
      h_sync    => h_sync,
      v_sync    => v_sync,
      video_in  => video_pre_fx,
      fx_ctrl      => video_fx_ctrl,
      fx_bitplane  => video_fx_bitplane,
      fx_dither    => video_fx_dither,
      fx_mirror    => video_fx_mirror,
      fx_chromatic => video_fx_chromatic,
      fx_sharpness => video_fx_sharpness,
      video_out    => video_fx_out
    );

--  frame_video_stats_inst : entity work.frame_video_stats
--    generic map (
--      G_FILTER_FRAMES => 4
--    )
--    port map (
--      clk       => pix_clk,
--      rst       => reset,
--      h_sync    => h_sync,
--      v_sync    => v_sync,
--      video_in  => video_fx_out,
--      video_out => video_out,
--      stats_luma_min => frame_stats_luma_min,
--      stats_luma_max => frame_stats_luma_max,
--      stats_luma_avg => frame_stats_luma_avg,
--      stats_r_min    => frame_stats_r_min,
--      stats_r_max    => frame_stats_r_max,
--      stats_r_avg    => frame_stats_r_avg,
--      stats_g_min    => frame_stats_g_min,
--      stats_g_max    => frame_stats_g_max,
--      stats_g_avg    => frame_stats_g_avg,
--      stats_b_min    => frame_stats_b_min,
--      stats_b_max    => frame_stats_b_max,
--      stats_b_avg    => frame_stats_b_avg,
--      stats_frame_id => frame_stats_frame_id,
--      stats_frame_hash      => frame_stats_hash,
--      stats_frame_pix_count => frame_stats_pix_count
--    );

end architecture;