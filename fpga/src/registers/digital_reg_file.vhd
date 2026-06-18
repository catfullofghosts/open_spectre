
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: 
-- created by   :   RD Jordan
-- Created: Early 2023
-- Description: 
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE-
-- OPEN SPECTRE REGISTER FILE
-- Sources: https://www.dte.us.es/docencia/master/micr/dapa/modulos-de-laboratorio/ficheros-modulo-1e/lab4mod1ev1-1_e.pdf
-- https://www.edaboard.com/threads/vhdl-cpu-register-file-help.304421/
-- https://forum.digilent.com/topic/8777-feedback-on-a-register-file-design/page/3/
-- current method is too manual can i use somthing , like this and loops to avoid writing each reg all the time? https://github.com/ChristianPalmiero/Windowed-Register-File/blob/master/Simple%20register%20file/Design/register_file.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.vcomponents.all;

use work.overlay_sprite_pkg.all;

entity digital_reg_file is
  generic (
    reg_version_id : std_logic_vector(7 downto 0) := x"00";
--    fpga_rev_id    : std_logic_vector(7 downto 0) := x"00";

    
    
    data_width     : integer                      := 32
  );
  port (
    -- CPU interface
    regs_clk     : in std_logic;
    regs_rst     : in std_logic;
    regs_en      : in std_logic;
    regs_wen     : in std_logic_vector(3 downto 0);
    regs_addr    : in std_logic_vector(12 downto 0);
    regs_wr_data : in std_logic_vector(data_width - 1 downto 0);
    regs_rd_data : out std_logic_vector(data_width - 1 downto 0);
    -- Hardware Interface
    --- Rotery encoder input registers
    Rotery_addr_mux : out std_logic_vector(3 downto 0); -- this address tells the rotery encoders which part of the register to write to, think of it like pages on a midi controller. (no processor state memory requiered)
    Rotery_enc_0    : in std_logic_vector(31 downto 0);
    Rotery_enc_1    : in std_logic_vector(31 downto 0);
    Rotery_enc_2    : in std_logic_vector(31 downto 0);
    Rotery_enc_3    : in std_logic_vector(31 downto 0);
    Rotery_enc_4    : in std_logic_vector(31 downto 0);
    -- Rotery encoder preset registers (used to set envoder values from the CPU)
    Rotery_enc_preset_w : out std_logic; -- write values to rotery encoder regs.
    Rotery_enc_0_preset : out std_logic_vector(31 downto 0);
    Rotery_enc_1_preset : out std_logic_vector(31 downto 0);
    Rotery_enc_2_preset : out std_logic_vector(31 downto 0);
    Rotery_enc_3_preset : out std_logic_vector(31 downto 0);
    Rotery_enc_4_preset : out std_logic_vector(31 downto 0);
    button_matrix       : in std_logic_vector(31 downto 0);
    -- Leds out
    led_output     : out std_logic_vector(31 downto 0); -- leds shifted out via shift reg to front pannel leds, so no pwm per led.
    led_global_pwm : out std_logic_vector(31 downto 0); -- global pwm mosfet for led brighness?
    lcd_backligh   : out std_logic; -- change to temp input, no longer an LCD or if thewre is it will always be on

    -- Fan Interface
    fan_pwm : out std_logic_vector(31 downto 0); --reference for FAN controller https://github.com/VLSI-EDA/PoC/blob/master/src/io/io_FanControl.vhdl
    fan_rpm : in std_logic_vector(31 downto 0);

    -- Pinmatrix
    matrix_out_addr : out std_logic_vector(5 downto 0);
    matrix_mask_out : out std_logic_vector(63 downto 0); -- the pin settings for a single oputput
    matrix_load     : out std_logic;
    invert_matrix   : out std_logic_vector(63 downto 0); -- inverts matrix inputs before they go into the 'patch pannel'
    -- Comparitor
    vid_span : out std_logic_vector(7 downto 0);
    --Analoge Matrix
    out_addr       : out std_logic_vector(7 downto 0);
    ch_addr        : out std_logic_vector(7 downto 0);
    gain_in        : out std_logic_vector(15 downto 0);
    anna_matrix_wr : out std_logic;
    --Shape Gen 1 & 2
    --GEN 1
    pos_h_1   : out std_logic_vector(11 downto 0);
    pos_v_1   : out std_logic_vector(11 downto 0);
    zoom_h_1  : out std_logic_vector(11 downto 0);
    zoom_v_1  : out std_logic_vector(11 downto 0);
    circle_1  : out std_logic_vector(11 downto 0);
    gear_1    : out std_logic_vector(11 downto 0);
    lantern_1 : out std_logic_vector(11 downto 0);
    fizz_1    : out std_logic_vector(11 downto 0);
    --GEN 2
    pos_h_2   : out std_logic_vector(11 downto 0);
    pos_v_2   : out std_logic_vector(11 downto 0);
    zoom_h_2  : out std_logic_vector(11 downto 0);
    zoom_v_2  : out std_logic_vector(11 downto 0);
    circle_2  : out std_logic_vector(11 downto 0);
    gear_2    : out std_logic_vector(11 downto 0);
    lantern_2 : out std_logic_vector(11 downto 0);
    fizz_2    : out std_logic_vector(11 downto 0);
    --Random Voltage generator
    noise_freq    : out std_logic_vector(13 downto 0);
    slew_in       : out std_logic_vector(2 downto 0);
    cycle_recycle : out std_logic;
    noise_rst     : out std_logic;
    slowdown_sel : out std_logic_vector(1 downto 0);
    --Oscilators 1 and 2 
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
    --YCbCr output levels
    col_en_bypass        : out std_logic;
    y_level        : out std_logic_vector(11 downto 0);
    cr_level       : out std_logic_vector(11 downto 0);
    cb_level       : out std_logic_vector(11 downto 0);
    video_active_O : out std_logic;
    -- Pixel clock and video input control
    pix_clk_div_sel     : out std_logic; -- 0 = /2, 1 = /4 for pix_clk_en
    ext_vid_in_mux_sel  : out std_logic; -- 0 = luma calc, 1 = y_out
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
    -- Final video output effects (register 0xE4)
    video_fx_ctrl     : out std_logic_vector(31 downto 0);
    video_fx_bitplane : out std_logic_vector(31 downto 0);
    video_fx_dither   : out std_logic_vector(31 downto 0);
    video_fx_mirror   : out std_logic_vector(31 downto 0);
    video_fx_chromatic : out std_logic_vector(31 downto 0);
    video_fx_sharpness : out std_logic_vector(31 downto 0);
    -- Overlay sprites (shared BRAM atlas, up to C_NUM_SPRITES slots)
    overlay_global_en : out std_logic;
    overlay_sprites   : out t_sprite_array;

    -- debug
    debug            : out std_logic_vector(127 downto 0);
    exception_addr_o : out std_logic

  );
end entity digital_reg_file;

architecture RTL of digital_reg_file is

  type regs32 is array (natural range <>) of std_logic_vector(31 downto 0);
  signal regs : regs32(127 downto 0)
  := (others => (others => '0'));

  -- Function for converting byte adresses to an index
  -- into the 32 bit register array.
  -- Conversion from std_vect to nateral/int https://nandland.com/common-vhdl-conversions/#Arith-Std_Logic_Vector-To-Integer
  function ra (
    byte_addr : std_logic_vector(12 downto 0) -- take full 12 bit address
  ) return natural is
    variable ret : natural;
  begin
    ret := to_integer(unsigned(byte_addr(12 downto 2))); -- drop the last 2 bits so that the address is correctly allighend , then get an index from it
    return ret;
  end ra;

  --cpu interface
  signal addr_reg  : std_logic_vector(12 downto 0);
  signal read_reg  : std_logic_vector(31 downto 0); -- fix this
  signal write_reg : std_logic_vector(31 downto 0);
  signal write_en  : std_logic;
  --sniffer interface
  signal digital_matrix_data : std_logic_vector(63 downto 0);
  --Hardware interface
  signal Rotery_addr_mux_i : std_logic_vector(3 downto 0); -- this address tells the rotery encoders which part of the register to write to, think of it like pages on a midi controller. (no processor state memory requiered)
  -- Rotery encoder preset registers (used to set envoder values from the CPU)
  signal Rotery_enc_preset_w_i : std_logic; -- write values to rotery encoder regs.
  signal Rotery_enc_0_preset_i : std_logic_vector(31 downto 0);
  signal Rotery_enc_1_preset_i : std_logic_vector(31 downto 0);
  signal Rotery_enc_2_preset_i : std_logic_vector(31 downto 0);
  signal Rotery_enc_3_preset_i : std_logic_vector(31 downto 0);
  signal Rotery_enc_4_preset_i : std_logic_vector(31 downto 0);

  -- Leds
  signal led_output_i     : std_logic_vector(31 downto 0); -- leds shifted via shift reg to front pannel leds, so no pwm per led.
  signal led_global_pwm_i : std_logic_vector(31 downto 0); -- global pwm mosfet for led brighness?
  signal lcd_backligh_i   : std_logic;

  -- Fan Interface
  signal fan_pwm_i : std_logic_vector(31 downto 0);
  --digital side
  signal matrix_out_addr_int : std_logic_vector(5 downto 0);
  signal matrix_load_int     : std_logic;
  signal mask_lower          : std_logic_vector(31 downto 0);
  signal mask_upper          : std_logic_vector(31 downto 0);
  signal inv_lower           : std_logic_vector(31 downto 0);
  signal inv_upper           : std_logic_vector(31 downto 0);
  signal vid_span_int        : std_logic_vector(7 downto 0) := x"FF"; -- Max value (255 decimal)
  -- analoge side
  signal out_addr_int       : std_logic_vector(7 downto 0);
  signal ch_addr_int        : std_logic_vector(7 downto 0);
  signal gain_in_int        : std_logic_vector(15 downto 0);
  signal anna_matrix_wr_int : std_logic;

  --Shape gen 1 & 2 (default to 100 decimal = 0x064)
  signal pos_h_i_1   : std_logic_vector(11 downto 0) := x"064";
  signal pos_v_i_1   : std_logic_vector(11 downto 0) := x"064";
  signal zoom_h_i_1  : std_logic_vector(11 downto 0) := x"064";
  signal zoom_v_i_1  : std_logic_vector(11 downto 0) := x"064";
  signal circle_i_1  : std_logic_vector(11 downto 0) := x"064";
  signal gear_i_1    : std_logic_vector(11 downto 0) := x"064";
  signal lantern_i_1 : std_logic_vector(11 downto 0) := x"064";
  signal fizz_i_1    : std_logic_vector(11 downto 0) := x"064";
  signal pos_h_i_2   : std_logic_vector(11 downto 0) := x"064";
  signal pos_v_i_2   : std_logic_vector(11 downto 0) := x"064";
  signal zoom_h_i_2  : std_logic_vector(11 downto 0) := x"064";
  signal zoom_v_i_2  : std_logic_vector(11 downto 0) := x"064";
  signal circle_i_2  : std_logic_vector(11 downto 0) := x"064";
  signal gear_i_2    : std_logic_vector(11 downto 0) := x"064";
  signal lantern_i_2 : std_logic_vector(11 downto 0) := x"064";
  signal fizz_i_2    : std_logic_vector(11 downto 0) := x"064";
  -- noise gen
  signal noise_freq_i    : std_logic_vector(13 downto 0);
  signal slew_in_i       : std_logic_vector(2 downto 0);
  signal cycle_recycle_i : std_logic;
  signal noise_rst_i     : std_logic;
  signal slowdown_sel_i  : std_logic_vector(1 downto 0);
  
  --osc 
  signal sync_sel_osc1_i : std_logic_vector(1 downto 0);
  signal osc_1_freq_i    : std_logic_vector(13 downto 0);
  signal osc_1_derv_i    : std_logic_vector(7 downto 0);
  signal osc_1_pwm_duty_i : std_logic_vector(8 downto 0);
  signal osc_1_wave_sel_i : std_logic_vector(1 downto 0);
  signal sync_sel_osc2_i : std_logic_vector(1 downto 0);
  signal osc_2_freq_i    : std_logic_vector(13 downto 0);
  signal osc_2_derv_i    : std_logic_vector(7 downto 0);
  signal osc_2_pwm_duty_i : std_logic_vector(8 downto 0);
  signal osc_2_wave_sel_i : std_logic_vector(1 downto 0);
  signal speed1_i       : std_logic;
  signal speed2_i       : std_logic;

  -- color output levels
  signal col_en_bypass_i   : std_logic;
  signal y_level_i      : std_logic_vector(11 downto 0);
  signal cr_level_i     : std_logic_vector(11 downto 0);
  signal cb_level_i     : std_logic_vector(11 downto 0);
  signal video_active   : std_logic;
  -- Pixel clock and video input control
  signal pix_clk_div_sel_i    : std_logic;
  signal ext_vid_in_mux_sel_i : std_logic;
  -- Luma key control
  signal luma_key_enable_i     : std_logic;
  signal luma_key_direction_i  : std_logic;
  signal luma_key_thresh_low_i : std_logic_vector(7 downto 0);
  signal luma_key_thresh_high_i: std_logic_vector(7 downto 0);
  -- Alpha controls for analog side
  signal osc1_alpha_i     : std_logic_vector(11 downto 0);
  signal osc2_alpha_i     : std_logic_vector(11 downto 0);
  signal dsm_hi_alpha_i   : std_logic_vector(11 downto 0);
  signal dsm_lo_alpha_i   : std_logic_vector(11 downto 0);
  signal noise_alpha_i    : std_logic_vector(11 downto 0);
  -- Shape select controls
  signal shape1_a_sel_i   : std_logic_vector(3 downto 0);
  signal shape1_b_sel_i   : std_logic_vector(3 downto 0);
  signal shape2_a_sel_i   : std_logic_vector(3 downto 0);
  signal shape2_b_sel_i   : std_logic_vector(3 downto 0);
  signal video_fx_ctrl_i     : std_logic_vector(31 downto 0);
  signal video_fx_bitplane_i : std_logic_vector(31 downto 0) := x"00000FFF"; -- all channels bypass
  signal video_fx_dither_i   : std_logic_vector(31 downto 0) := (others => '0'); -- dither bypass
  signal video_fx_mirror_i   : std_logic_vector(31 downto 0) := x"000002D0"; -- half=360px, disabled
  signal video_fx_chromatic_i : std_logic_vector(31 downto 0) := (others => '0');
  signal video_fx_sharpness_i : std_logic_vector(31 downto 0) := (others => '0');
  signal overlay_global_en_i : std_logic := '0';
  signal overlay_sprites_i   : t_sprite_array := (others => (
    enable => '0',
    x      => (others => '0'),
    y      => (others => '0'),
    width  => (others => '0'),
    height => (others => '0'),
    base   => (others => '0')
  ));
  signal exception_addr : std_logic; -- toggles on address out of range error for reg file -- need better solution with reset + exception for sniffer

begin

   ---------------------------------------------------------------------------
  -- READ: Pass external signals into the read reg array
  ---------------------------------------------------------------------------
    process(regs_clk)
  begin
    if rising_edge(regs_clk) then
      if regs_en = '0' then
        read_reg <= x"00000000";
      else
        read_reg <= regs(ra(regs_addr));
      end if;
    end if;
  end process;

  regs_rd_data <= read_reg;
  -- outgoing, so inputs to this block from the outside
--  regs(ra(x"00")) <= x"000000" & fpga_rev_id; -- read only reg with the FPGA build number

  -- digital side
  regs(ra(x"04")) <= x"000000" & "00" & matrix_out_addr_int; -- this is the matrix output
  regs(ra(x"08")) <= x"000000" & "0000000" & matrix_load_int; -- load flag
  regs(ra(x"10")) <= mask_lower;
  regs(ra(x"14")) <= mask_upper;
  -- regs(ra(x"18")) <= xxxxxxxxxxxx; saved for future matrix expantion
  regs(ra(x"1C")) <= inv_lower; -- inverts the matrix inputs, lower 32
  regs(ra(x"20")) <= inv_upper; -- inverts the matrix inputs, upper 32
  regs(ra(x"24")) <= x"000000" & vid_span_int;

  -- analoge side matrix
  regs(ra(x"28")) <= x"000000" & out_addr_int;
  regs(ra(x"2C")) <= x"000000" & ch_addr_int;
  regs(ra(x"30")) <= x"0000" & gain_in_int;
  regs(ra(x"34")) <= x"000000" & "0000000" & anna_matrix_wr_int;

  -- shape gen 1 & 2
  regs(ra(x"38")) <= x"0" & pos_h_i_2 & x"0" & pos_h_i_1;
  regs(ra(x"3C")) <= x"0" & pos_v_i_2 & x"0" & pos_v_i_1;
  regs(ra(x"40")) <= x"0" & zoom_h_i_2 & x"0" & zoom_h_i_1;
  regs(ra(x"44")) <= x"0" & zoom_v_i_2 & x"0" & zoom_v_i_1;
  regs(ra(x"48")) <= x"0" & circle_i_2 & x"0" & circle_i_1;
  regs(ra(x"4C")) <= x"0" & gear_i_2 & x"0" & gear_i_1;
  regs(ra(x"50")) <= x"0" & lantern_i_2 & x"0" & lantern_i_1;
  regs(ra(x"54")) <= x"0" & fizz_i_2 & x"0" & fizz_i_1;

  -- random gen
  regs(ra(x"60")) <= "00" & slowdown_sel_i & x"00" & slew_in_i & "000" & noise_freq_i;
  regs(ra(x"64")) <= x"000000" & "000000" & noise_rst_i & cycle_recycle_i; -- put this back into the register above at some point

  -- OSC 1&2
  regs(ra(x"68")) <= sync_sel_osc1_i & "00" & speed1_i & "000" & osc_1_derv_i & "00" & osc_1_freq_i;
  regs(ra(x"6C")) <= sync_sel_osc2_i & "00" & speed2_i & "000" & osc_2_derv_i & "00" & osc_2_freq_i;
  -- OSC 1&2 PWM duty and wave select
  regs(ra(x"70")) <= x"00000" & osc_1_wave_sel_i & "0" & osc_1_pwm_duty_i;
  regs(ra(x"74")) <= x"00000" & osc_2_wave_sel_i & "0" & osc_2_pwm_duty_i;

  -- output y,cr,cb levels (moved to make room for osc registers)
  regs(ra(x"58")) <= x"0" & cr_level_i & x"0" & y_level_i;
  regs(ra(x"5C")) <= x"00000" & cb_level_i;
  regs(ra(x"78")) <= x"000000" & "0000" & ext_vid_in_mux_sel_i & pix_clk_div_sel_i & col_en_bypass_i & video_active;
  -- Luma key control
  regs(ra(x"C8")) <= luma_key_enable_i & luma_key_direction_i & "00000000000000" & luma_key_thresh_high_i & luma_key_thresh_low_i;
  -- Alpha controls for analog side
  regs(ra(x"CC")) <= x"00000" & osc1_alpha_i;
  regs(ra(x"D0")) <= x"00000" & osc2_alpha_i;
  regs(ra(x"D4")) <= x"00000" & dsm_hi_alpha_i;
  regs(ra(x"D8")) <= x"00000" & dsm_lo_alpha_i;
  regs(ra(x"DC")) <= x"00000" & noise_alpha_i;
  -- Shape select controls
  regs(ra(x"E0")) <= x"0000" & shape2_b_sel_i & shape2_a_sel_i & shape1_b_sel_i & shape1_a_sel_i;
  -- Video output effects: [0]=inv R, [1]=inv G, [2]=inv B, [4:3]=swap, [7:5]=bit rev,
  --   [8]=scan en, [10:9]=scan delay, [12:11]=logic w/ prev pixel (01=OR 10=AND 11=XOR)
  regs(ra(x"E4")) <= video_fx_ctrl_i;
  -- Bit plane slice: R[3:0] G[7:4] B[11:8]; bit3 per channel = bypass
  regs(ra(x"E8")) <= video_fx_bitplane_i;
  -- Horizontal ordered dither: [0]=en, [2:1]=depth (6/5/4/3-bit)
  regs(ra(x"EC")) <= video_fx_dither_i;
  -- Horizontal mirror: [0]=en, [11:1]=half line width (pixels)
  regs(ra(x"F0")) <= video_fx_mirror_i;
  -- Chromatic aberration: [0]=en, [3:1]=G delay, [6:4]=B delay (0-5 px)
  regs(ra(x"F4")) <= video_fx_chromatic_i;
  -- Sharpness/blur: [0]=en, [1]=mode (0=blur 1=sharp), [15:8]=strength
  regs(ra(x"F8")) <= video_fx_sharpness_i;
  -- Overlay master enable
  regs(ra(x"FC")) <= "0000000000000000000000000000000" & overlay_global_en_i;

  g_sprite_read : for i in 0 to C_NUM_SPRITES - 1 generate
    constant c_base : unsigned(12 downto 0) :=
      unsigned(C_SPRITE_REG_LO) + to_unsigned(i * C_SPRITE_STRIDE, 13);
  begin
    regs(ra(std_logic_vector(c_base + 0))) <= "000000000" & overlay_sprites_i(i).y & overlay_sprites_i(i).x & overlay_sprites_i(i).enable;
    regs(ra(std_logic_vector(c_base + 4))) <= "000000000" & overlay_sprites_i(i).height & '0' & overlay_sprites_i(i).width;
    regs(ra(std_logic_vector(c_base + 8))) <= "000000000000000000000" & overlay_sprites_i(i).base;
  end generate g_sprite_read;

  -- hardware interface
--  regs(ra(x"7C")) <= 0x"0000000" & Rotery_addr_mux_i;
  regs(ra(x"80")) <= Rotery_enc_0; -- read only
  regs(ra(x"84")) <= Rotery_enc_1; -- read only
  regs(ra(x"88")) <= Rotery_enc_2; -- read only
  regs(ra(x"8C")) <= Rotery_enc_3; -- read only
  regs(ra(x"90")) <= Rotery_enc_4; -- read only
--  regs(ra(x"94")) <= 0x"0000000" & "000" & Rotery_enc_preset_w_i;
  regs(ra(x"98")) <= Rotery_enc_0_preset_i;
  regs(ra(x"9C")) <= Rotery_enc_1_preset_i;
  regs(ra(x"A0")) <= Rotery_enc_2_preset_i;
  regs(ra(x"A4")) <= Rotery_enc_3_preset_i;
  regs(ra(x"A8")) <= Rotery_enc_4_preset_i;
  regs(ra(x"AC")) <= led_output_i;
  regs(ra(x"B0")) <= led_global_pwm_i;
--  regs(ra(x"B4")) <= 0x"0000000" & "000" & lcd_backligh_i;
  regs(ra(x"B8")) <= fan_pwm_i;
  regs(ra(x"BC")) <= fan_rpm; -- read only
  regs(ra(x"C0")) <= button_matrix; -- read only

  -- other
  regs(ra(x"C4")) <= x"DEADBEEF"; --test reg 1

  ---------------------------------------------------------------------------
  -- Register writes
  ---------------------------------------------------------------------------
  process (regs_clk)
  begin
    if rising_edge(regs_clk) then
      addr_reg  <= regs_addr;
      write_reg <= regs_wr_data;
      write_en  <= '0';
      if (regs_en = '1' and regs_wen(0) = '1') then
        write_en <= '1';
      end if;
    end if;
  end process;
  -- ---------------------------------------------------------------------------
  -- WRITE: Get the data from the incoming write port and pass it to the internal signal for each reg
  ---------------------------------------------------------------------------
  process (regs_clk)
    variable v_sprite_idx : integer range 0 to C_NUM_SPRITES - 1;
    variable v_sprite_off : unsigned(3 downto 0);
  begin
    if rising_edge(regs_clk) then
      if (write_en = '1') then
        if addr_reg = x"FC" then
          overlay_global_en_i <= write_reg(0);
        elsif unsigned(addr_reg) >= unsigned(C_SPRITE_REG_LO)
              and unsigned(addr_reg) < unsigned(C_SPRITE_REG_LO) + C_NUM_SPRITES * C_SPRITE_STRIDE then
          v_sprite_idx := to_integer(
            (unsigned(addr_reg) - unsigned(C_SPRITE_REG_LO)) / C_SPRITE_STRIDE
          );
          v_sprite_off := unsigned(addr_reg(3 downto 0));
          if v_sprite_idx >= 0 and v_sprite_idx < C_NUM_SPRITES then
            case v_sprite_off is
              when x"0" =>
                overlay_sprites_i(v_sprite_idx).enable <= write_reg(0);
                overlay_sprites_i(v_sprite_idx).x      <= write_reg(11 downto 1);
                overlay_sprites_i(v_sprite_idx).y      <= write_reg(22 downto 12);
              when x"4" =>
                overlay_sprites_i(v_sprite_idx).width  <= write_reg(10 downto 0);
                overlay_sprites_i(v_sprite_idx).height <= write_reg(21 downto 11);
              when x"8" =>
                overlay_sprites_i(v_sprite_idx).base   <= write_reg(10 downto 0);
              when others =>
                null;
            end case;
          end if;
        else
        case addr_reg(7 downto 0) is
          when x"04" =>
            matrix_out_addr_int <= write_reg(5 downto 0);
          when x"08" =>
            matrix_load_int <= write_reg(0);
          when x"10" =>
            mask_lower <= write_reg;
          when x"14" =>
            mask_upper <= write_reg;
          when x"1C" =>
            inv_lower <= write_reg;
          when x"20" =>
            inv_upper <= write_reg;
          when x"24" =>
            vid_span_int <= write_reg(7 downto 0);
          when x"28" =>
            out_addr_int <= write_reg(7 downto 0);
          when x"2C" =>
            ch_addr_int <= write_reg(7 downto 0);
          when x"30" =>
            gain_in_int <= write_reg(15 downto 0);
          when x"34" =>
            anna_matrix_wr_int <= write_reg(0);
          when x"38" =>
            pos_h_i_1 <= write_reg(11 downto 0);
            pos_h_i_2 <= write_reg(27 downto 16);
          when x"3C" =>
            pos_v_i_1 <= write_reg(11 downto 0);
            pos_v_i_2 <= write_reg(27 downto 16);
          when x"40" =>
            zoom_h_i_1 <= write_reg(11 downto 0);
            zoom_h_i_2 <= write_reg(27 downto 16);
          when x"44" =>
            zoom_v_i_1 <= write_reg(11 downto 0);
            zoom_v_i_2 <= write_reg(27 downto 16);
          when x"48" =>
            circle_i_1 <= write_reg(11 downto 0);
            circle_i_2 <= write_reg(27 downto 16);
          when x"4C" =>
            gear_i_1 <= write_reg(11 downto 0);
            gear_i_2 <= write_reg(27 downto 16);
          when x"50" =>
            lantern_i_1 <= write_reg(11 downto 0);
            lantern_i_2 <= write_reg(27 downto 16);
          when x"54" =>
            fizz_i_1 <= write_reg(11 downto 0);
            fizz_i_2 <= write_reg(27 downto 16);
          when x"60" =>
            noise_freq_i <= write_reg(13 downto 0);
            slew_in_i    <= write_reg(19 downto 17);
            slowdown_sel_i <= write_reg(29 downto 28);
            --            cycle_recycle_i <= write_reg(13);
          when x"64" =>
            cycle_recycle_i <= write_reg(0);
            noise_rst_i     <= write_reg(1);
          when x"68" =>
            osc_1_freq_i    <= write_reg(13 downto 0);
            osc_1_derv_i    <= write_reg(23 downto 16);
            sync_sel_osc1_i <= write_reg(31 downto 30);
            speed1_i <= write_reg(28);
          when x"6C" =>
            osc_2_freq_i    <= write_reg(13 downto 0);
            osc_2_derv_i    <= write_reg(23 downto 16);
            sync_sel_osc2_i <= write_reg(31 downto 30);
            speed2_i <= write_reg(28);
          when x"70" =>
            osc_1_pwm_duty_i <= write_reg(8 downto 0);
            osc_1_wave_sel_i <= write_reg(11 downto 10);
          when x"74" =>
            osc_2_pwm_duty_i <= write_reg(8 downto 0);
            osc_2_wave_sel_i <= write_reg(11 downto 10);

          when x"58" =>
            y_level_i  <= write_reg(11 downto 0);
            cr_level_i <= write_reg(27 downto 16);
          when x"5C" =>
            cb_level_i <= write_reg(11 downto 0);
          when x"78" =>
            video_active <= write_reg(0);
            col_en_bypass_i <= write_reg(1);
            pix_clk_div_sel_i <= write_reg(2);
            ext_vid_in_mux_sel_i <= write_reg(3);
          when x"C8" =>
            luma_key_enable_i <= write_reg(31);
            luma_key_direction_i <= write_reg(30);
            luma_key_thresh_high_i <= write_reg(15 downto 8);
            luma_key_thresh_low_i <= write_reg(7 downto 0);
          when x"CC" =>
            osc1_alpha_i <= write_reg(11 downto 0);
          when x"D0" =>
            osc2_alpha_i <= write_reg(11 downto 0);
          when x"D4" =>
            dsm_hi_alpha_i <= write_reg(11 downto 0);
          when x"D8" =>
            dsm_lo_alpha_i <= write_reg(11 downto 0);
          when x"DC" =>
            noise_alpha_i <= write_reg(11 downto 0);
          when x"E0" =>
            shape1_a_sel_i <= write_reg(3 downto 0);
            shape1_b_sel_i <= write_reg(7 downto 4);
            shape2_a_sel_i <= write_reg(11 downto 8);
            shape2_b_sel_i <= write_reg(15 downto 12);
          when x"E4" =>
            video_fx_ctrl_i <= write_reg;
          when x"E8" =>
            video_fx_bitplane_i <= write_reg;
          when x"EC" =>
            video_fx_dither_i <= write_reg;
          when x"F0" =>
            video_fx_mirror_i <= write_reg;
          when x"F4" =>
            video_fx_chromatic_i <= write_reg;
          when x"F8" =>
            video_fx_sharpness_i <= write_reg;
          when x"7C" =>
            Rotery_addr_mux_i <= write_reg(3 downto 0);
            -- Note the Gap in addresses for the read only Rot encoders?
          when x"94" =>
            Rotery_enc_preset_w_i <= write_reg(0);
          when x"98" =>
            Rotery_enc_0_preset_i <= write_reg;
          when x"9C" =>
            Rotery_enc_1_preset_i <= write_reg;
          when x"A0" =>
            Rotery_enc_2_preset_i <= write_reg;
          when x"A4" =>
            Rotery_enc_3_preset_i <= write_reg;
          when x"A8" =>
            Rotery_enc_4_preset_i <= write_reg;
          when x"AC" =>
            led_output_i <= write_reg;
          when x"B0" =>
            led_global_pwm_i <= write_reg;
          when x"B4" =>
            lcd_backligh_i <= write_reg(0);
          when x"B8" =>
            fan_pwm_i <= write_reg;

          when others =>
            exception_addr <= not exception_addr;

            -- do nothing
        end case;
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Output: pass registers with outputs to the out port
  ---------------------------------------------------------------------------
  matrix_out_addr <= matrix_out_addr_int;
  matrix_load     <= matrix_load_int;
  matrix_mask_out <= mask_upper & mask_lower;
  invert_matrix   <= inv_upper & inv_lower;
  vid_span        <= vid_span_int;
  out_addr        <= out_addr_int;
  ch_addr         <= ch_addr_int;
  gain_in         <= gain_in_int;

  anna_matrix_wr <= anna_matrix_wr_int;

  pos_h_1   <= pos_h_i_1;
  pos_v_1   <= pos_v_i_1;
  zoom_h_1  <= zoom_h_i_1;
  zoom_v_1  <= zoom_v_i_1;
  circle_1  <= circle_i_1;
  gear_1    <= gear_i_1;
  lantern_1 <= lantern_i_1;
  fizz_1    <= fizz_i_1;

  pos_h_2   <= pos_h_i_2;
  pos_v_2   <= pos_v_i_2;
  zoom_h_2  <= zoom_h_i_2;
  zoom_v_2  <= zoom_v_i_2;
  circle_2  <= circle_i_2;
  gear_2    <= gear_i_2;
  lantern_2 <= lantern_i_2;
  fizz_2    <= fizz_i_2;

  noise_freq    <= noise_freq_i;
  slew_in       <= slew_in_i;
  cycle_recycle <= cycle_recycle_i;
  noise_rst     <= noise_rst_i;
  slowdown_sel <= slowdown_sel_i;

  sync_sel_osc1 <= sync_sel_osc1_i;
  osc_1_freq    <= osc_1_freq_i;
  osc_1_derv    <= osc_1_derv_i;
  osc_1_pwm_duty <= osc_1_pwm_duty_i;
  osc_1_wave_sel <= osc_1_wave_sel_i;
  sync_sel_osc2 <= sync_sel_osc2_i;
  osc_2_freq    <= osc_2_freq_i;
  osc_2_derv    <= osc_2_derv_i;
  osc_2_pwm_duty <= osc_2_pwm_duty_i;
  osc_2_wave_sel <= osc_2_wave_sel_i;
  speed1 <= speed1_i;
  speed2 <= speed2_i;
  
  
  col_en_bypass <= col_en_bypass_i;
  y_level  <= y_level_i;
  cr_level <= cr_level_i;
  cb_level <= cb_level_i;

  video_active_O <= video_active;
  pix_clk_div_sel <= pix_clk_div_sel_i;
  ext_vid_in_mux_sel <= ext_vid_in_mux_sel_i;
  
  luma_key_enable <= luma_key_enable_i;
  luma_key_direction <= luma_key_direction_i;
  luma_key_thresh_low <= luma_key_thresh_low_i;
  luma_key_thresh_high <= luma_key_thresh_high_i;

  osc1_alpha <= osc1_alpha_i;
  osc2_alpha <= osc2_alpha_i;
  dsm_hi_alpha <= dsm_hi_alpha_i;
  dsm_lo_alpha <= dsm_lo_alpha_i;
  noise_alpha <= noise_alpha_i;

  shape1_a_sel <= shape1_a_sel_i;
  shape1_b_sel <= shape1_b_sel_i;
  shape2_a_sel <= shape2_a_sel_i;
  shape2_b_sel <= shape2_b_sel_i;

  video_fx_ctrl     <= video_fx_ctrl_i;
  video_fx_bitplane <= video_fx_bitplane_i;
  video_fx_dither   <= video_fx_dither_i;
  video_fx_mirror   <= video_fx_mirror_i;
  video_fx_chromatic <= video_fx_chromatic_i;
  video_fx_sharpness <= video_fx_sharpness_i;

  overlay_global_en <= overlay_global_en_i;
  overlay_sprites   <= overlay_sprites_i;

  Rotery_addr_mux     <= Rotery_addr_mux_i;
  Rotery_enc_preset_w <= Rotery_enc_preset_w_i;
  Rotery_enc_0_preset <= Rotery_enc_0_preset_i;
  Rotery_enc_1_preset <= Rotery_enc_1_preset_i;
  Rotery_enc_2_preset <= Rotery_enc_2_preset_i;
  Rotery_enc_3_preset <= Rotery_enc_3_preset_i;
  Rotery_enc_4_preset <= Rotery_enc_4_preset_i;
  led_output          <= led_output_i;
  led_global_pwm      <= led_global_pwm_i;
  lcd_backligh        <= lcd_backligh_i;
  fan_pwm             <= fan_pwm_i;

end RTL;
