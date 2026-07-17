library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.overlay_sprite_pkg.all;

-- Dual-port overlay and sprites
--
-- CPU port: writes pixel data anywhere in the shared BRAM (AXI @ byte 0x400+).
-- Video port: each enabled sprite slot has its own screen position and base;
--             at most one BRAM read per pixel — highest slot index wins on overlap.
--
-- Pixel word format:
--   [31]    1 = opaque overlay pixel, 0 = transparent
--   [23:16] blue, [15:8] green, [7:0] red
--
-- Atlas layout: pack each sprite contiguously starting at its base word address.
--   sprite N pixel (lx, ly) -> BRAM[ base_N + (ly mod tile_h) * tile_w + (lx mod tile_w) ]
--   tile_w/tile_h in reg+8 select the repeating pattern size; screen coverage uses width/height.
--   Tiled mode expects power-of-2 tile_w/tile_h (software default); hardware uses bit-mask wrap.

entity overlay_framebuffer is
  generic (
    G_DEPTH       : positive := 2048;
    G_ADDR_WIDTH  : positive := 11;
    G_VIDEO_LAT   : positive := 6 -- horizontal lookahead (matches video pipeline depth)
  );
  port (
    cpu_clk   : in  std_logic;
    cpu_en    : in  std_logic;
    cpu_we    : in  std_logic_vector(3 downto 0);
    cpu_addr  : in  std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
    cpu_wdata : in  std_logic_vector(31 downto 0);
    cpu_rdata : out std_logic_vector(31 downto 0);

    pix_clk   : in  std_logic;
    pix_rst   : in  std_logic;
    h_sync    : in  std_logic;
    v_sync    : in  std_logic;

    global_enable : in  std_logic;
    block_div     : in  std_logic_vector(2 downto 0); -- 0=/1 1=/2 2=/4 3=/8 4=/16
    sprites       : in  t_sprite_array;

    overlay_key : out std_logic;
    overlay_rgb : out std_logic_vector(23 downto 0)
  );
end entity overlay_framebuffer;

architecture rtl of overlay_framebuffer is

  type t_ram is array (0 to G_DEPTH - 1) of std_logic_vector(31 downto 0);
  type t_hit_vec is array (0 to C_NUM_SPRITES - 1) of std_logic;
  type t_coord_vec is array (0 to C_NUM_SPRITES - 1) of unsigned(10 downto 0);

  signal ram         : t_ram;
  signal cpu_rdata_i : std_logic_vector(31 downto 0);

  signal h_sync_d    : std_logic;
  signal v_sync_d    : std_logic;
  signal x_pos       : unsigned(10 downto 0) := (others => '0');
  signal y_pos       : unsigned(10 downto 0) := (others => '0');

  signal sprites_r   : t_sprite_array;
  signal block_div_r : std_logic_vector(2 downto 0);
  signal global_en_r : std_logic;
  signal h_act_r     : std_logic;
  signal v_act_r     : std_logic;
  signal x_pick      : unsigned(10 downto 0);
  signal y_pick      : unsigned(10 downto 0);

  signal hit_vec     : t_hit_vec;
  signal lx_vec      : t_coord_vec;
  signal ly_vec      : t_coord_vec;

  signal s1_hit      : std_logic;
  signal s1_sel      : unsigned(2 downto 0);
  signal s1_lx       : unsigned(10 downto 0);
  signal s1_ly       : unsigned(10 downto 0);
  signal s1_base     : unsigned(10 downto 0);
  signal s1_tw       : unsigned(10 downto 0);
  signal s1_th       : unsigned(10 downto 0);
  signal s1_w       : unsigned(10 downto 0);
  signal s1_h        : unsigned(10 downto 0);

  signal s2_hit      : std_logic;
  signal s2_lx_t     : unsigned(10 downto 0);
  signal s2_ly_t     : unsigned(10 downto 0);
  signal s2_base     : unsigned(10 downto 0);
  signal s2_tw       : unsigned(10 downto 0);

  signal s3_hit      : std_logic;
  signal s3_addr     : unsigned(G_ADDR_WIDTH - 1 downto 0);

  signal s4_hit      : std_logic;
  signal s4_addr     : unsigned(G_ADDR_WIDTH - 1 downto 0);
  signal s5_hit      : std_logic;
  signal s5_pix      : std_logic_vector(31 downto 0);

  attribute ram_style : string;
  attribute ram_style of ram : signal is "block";

  function f_is_pow2 (
    v : unsigned(10 downto 0)
  ) return boolean is
    variable u : unsigned(10 downto 0);
  begin
    if v = 0 then
      return false;
    end if;
    u := v - 1;
    return (v and u) = 0;
  end function f_is_pow2;

  function f_wrap_coord (
    coord : unsigned(10 downto 0);
    size  : unsigned(10 downto 0)
  ) return unsigned is
  begin
    if size = 0 then
      return coord;
    elsif f_is_pow2(size) then
      return coord and resize(size - 1, 11);
    else
      -- Non power-of-two tiles fall back to linear atlas (no repeat) for timing.
      return coord;
    end if;
  end function f_wrap_coord;

  function f_shr_div (
    value   : unsigned(10 downto 0);
    div_sel : std_logic_vector(2 downto 0)
  ) return unsigned is
    variable shift_amt : natural;
  begin
    case div_sel is
      when "001" => shift_amt := 1;
      when "010" => shift_amt := 2;
      when "011" => shift_amt := 3;
      when "100" => shift_amt := 4;
      when others => shift_amt := 0;
    end case;
    return shift_right(value, shift_amt);
  end function f_shr_div;

begin

  p_sprite_sync : process (pix_clk) is
  begin
    if rising_edge(pix_clk) then
      sprites_r   <= sprites;
      block_div_r <= block_div;
    end if;
  end process p_sprite_sync;

  p_cpu : process (cpu_clk) is
    variable v_addr : integer range 0 to G_DEPTH - 1;
  begin
    if rising_edge(cpu_clk) then
      if cpu_en = '1' then
        v_addr := to_integer(unsigned(cpu_addr));
        if v_addr >= 0 and v_addr < G_DEPTH then
          if cpu_we /= "0000" then
            for i in 0 to 3 loop
              if cpu_we(i) = '1' then
                ram(v_addr)(8 * (i + 1) - 1 downto 8 * i) <=
                  cpu_wdata(8 * (i + 1) - 1 downto 8 * i);
              end if;
            end loop;
          end if;
          cpu_rdata_i <= ram(v_addr);
        else
          cpu_rdata_i <= (others => '0');
        end if;
      end if;
    end if;
  end process p_cpu;

  cpu_rdata <= cpu_rdata_i;

  p_counters : process (pix_clk) is
  begin
    if rising_edge(pix_clk) then
      h_sync_d <= h_sync;
      v_sync_d <= v_sync;

      if pix_rst = '1' then
        x_pos <= (others => '0');
        y_pos <= (others => '0');
      else
        if v_sync /= v_sync_d then
          y_pos <= (others => '0');
        elsif h_sync = '1' and h_sync_d = '0' then
          y_pos <= y_pos + 1;
        end if;

        if h_sync = '0' then
          if h_sync_d = '1' then
            x_pos <= (others => '0');
          else
            x_pos <= x_pos + 1;
          end if;
        end if;
      end if;
    end if;
  end process p_counters;

  -- Stage 0: register syncs and apply horizontal pipeline lookahead.
  p_stage0 : process (pix_clk) is
  begin
    if rising_edge(pix_clk) then
      global_en_r <= global_enable;
      h_act_r     <= '1' when h_sync = '0' else '0';
      v_act_r     <= '1' when v_sync = '0' else '0';
      x_pick      <= x_pos + G_VIDEO_LAT;
      y_pick      <= y_pos;
    end if;
  end process p_stage0;

  -- Stage 1a: parallel per-sprite hit tests (no shared long priority chain).
  g_hit : for i in 0 to C_NUM_SPRITES - 1 generate
    signal w_u : unsigned(10 downto 0);
    signal h_u : unsigned(10 downto 0);
    signal x_u : unsigned(10 downto 0);
    signal y_u : unsigned(10 downto 0);
    signal lx_u : unsigned(10 downto 0);
    signal ly_u : unsigned(10 downto 0);
  begin
    w_u <= unsigned(sprites_r(i).width);
    h_u <= unsigned(sprites_r(i).height);
    x_u <= unsigned(sprites_r(i).x);
    y_u <= unsigned(sprites_r(i).y);

    lx_u <= x_pick - x_u;
    ly_u <= y_pick - y_u;

    hit_vec(i) <= '1'
      when global_en_r = '1'
       and h_act_r = '1'
       and v_act_r = '1'
       and sprites_r(i).enable = '1'
       and w_u /= 0
       and h_u /= 0
       and x_pick >= x_u
       and y_pick >= y_u
       and lx_u < w_u
       and ly_u < h_u
      else '0';

    lx_vec(i) <= lx_u;
    ly_vec(i) <= ly_u;
  end generate g_hit;

  -- Stage 1b: priority pick (highest sprite index wins) and latch sprite fields.
  p_stage1 : process (pix_clk) is
    variable v_sel : integer range -1 to C_NUM_SPRITES - 1;
  begin
    if rising_edge(pix_clk) then
      v_sel  := -1;
      s1_hit <= '0';

      for i in C_NUM_SPRITES - 1 downto 0 loop
        if hit_vec(i) = '1' then
          v_sel  := i;
          s1_hit <= '1';
          exit;
        end if;
      end loop;

      if v_sel >= 0 then
        s1_sel  <= to_unsigned(v_sel, 3);
        s1_lx   <= lx_vec(v_sel);
        s1_ly   <= ly_vec(v_sel);
        s1_base <= unsigned(sprites_r(v_sel).base);
        s1_tw   <= unsigned(sprites_r(v_sel).tile_w);
        s1_th   <= unsigned(sprites_r(v_sel).tile_h);
        s1_w    <= unsigned(sprites_r(v_sel).width);
        s1_h    <= unsigned(sprites_r(v_sel).height);
      else
        s1_sel  <= (others => '0');
        s1_lx   <= (others => '0');
        s1_ly   <= (others => '0');
        s1_base <= (others => '0');
        s1_tw   <= (others => '0');
        s1_th   <= (others => '0');
        s1_w    <= (others => '0');
        s1_h    <= (others => '0');
      end if;
    end if;
  end process p_stage1;

  -- Stage 2: tile wrap only (no multiply).
  p_stage2 : process (pix_clk) is
    variable tw_v : unsigned(10 downto 0);
    variable th_v : unsigned(10 downto 0);
    variable hit_v : std_logic;
  begin
    if rising_edge(pix_clk) then
      hit_v   := s1_hit;
      s2_lx_t <= (others => '0');
      s2_ly_t    <= (others => '0');
      s2_base    <= (others => '0');
      s2_tw      <= (others => '0');

      if s1_hit = '1' then
        tw_v := s1_tw;
        th_v := s1_th;
        if tw_v = 0 then
          tw_v := s1_w;
        end if;
        if th_v = 0 then
          th_v := s1_h;
        end if;

        s2_base <= s1_base;
        s2_lx_t <= f_shr_div(s1_lx, block_div_r);
        s2_ly_t <= f_shr_div(s1_ly, block_div_r);
        s2_tw   <= tw_v;

        if f_is_pow2(tw_v) and f_is_pow2(th_v) and tw_v /= 0 and th_v /= 0 then
          s2_lx_t <= f_shr_div(f_wrap_coord(s1_lx, tw_v), block_div_r);
          s2_ly_t <= f_shr_div(f_wrap_coord(s1_ly, th_v), block_div_r);
        end if;
      else
        hit_v := '0';
      end if;

      s2_hit <= hit_v;
    end if;
  end process p_stage2;

  -- Stage 3: multiply-add / linear address.
  p_stage3 : process (pix_clk) is
    variable prod_v : unsigned(21 downto 0);
    variable addr_v : unsigned(G_ADDR_WIDTH + 10 downto 0);
    variable hit_v  : std_logic;
  begin
    if rising_edge(pix_clk) then
      hit_v   := s2_hit;
      s3_addr <= (others => '0');

      if s2_hit = '1' then
        prod_v := s2_ly_t * s2_tw;
        addr_v := resize(s2_base, addr_v'length)
                  + resize(prod_v, addr_v'length)
                  + resize(s2_lx_t, addr_v'length);

        if addr_v < G_DEPTH then
          s3_addr <= resize(addr_v, G_ADDR_WIDTH);
        else
          hit_v := '0';
        end if;
      end if;

      s3_hit <= hit_v;
    end if;
  end process p_stage3;

  -- Stage 4: register BRAM read address.
  p_stage4 : process (pix_clk) is
  begin
    if rising_edge(pix_clk) then
      s4_hit  <= s3_hit;
      s4_addr <= s3_addr;
    end if;
  end process p_stage4;

  -- Stage 5: block RAM read (one cycle after address register).
  p_stage5 : process (pix_clk) is
    variable v_addr : integer range 0 to G_DEPTH - 1;
  begin
    if rising_edge(pix_clk) then
      s5_hit <= s4_hit;
      v_addr := to_integer(s4_addr);
      if v_addr >= 0 and v_addr < G_DEPTH then
        s5_pix <= ram(v_addr);
      else
        s5_pix <= (others => '0');
      end if;
    end if;
  end process p_stage5;

  -- Stage 6: overlay output.
  p_stage6 : process (pix_clk) is
  begin
    if rising_edge(pix_clk) then
      if pix_rst = '1' then
        overlay_key <= '0';
        overlay_rgb <= (others => '0');
      elsif s5_hit = '1' and s5_pix(31) = '1' then
        overlay_key <= '1';
        overlay_rgb <= s5_pix(23 downto 0);
      else
        overlay_key <= '0';
        overlay_rgb <= (others => '0');
      end if;
    end if;
  end process p_stage6;

end architecture rtl;
