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
--   sprite N pixel (lx, ly) -> BRAM[ base_N + ly * width_N + lx ]

entity overlay_framebuffer is
  generic (
    G_DEPTH       : positive := 2048;
    G_ADDR_WIDTH  : positive := 11
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
    sprites       : in  t_sprite_array;

    overlay_key : out std_logic;
    overlay_rgb : out std_logic_vector(23 downto 0)
  );
end entity overlay_framebuffer;

architecture rtl of overlay_framebuffer is

  type t_ram is array (0 to G_DEPTH - 1) of std_logic_vector(31 downto 0);

  signal ram         : t_ram;
  signal cpu_rdata_i : std_logic_vector(31 downto 0);

  signal h_sync_d    : std_logic;
  signal v_sync_d    : std_logic;
  signal x_pos       : unsigned(10 downto 0) := (others => '0');
  signal y_pos       : unsigned(10 downto 0) := (others => '0');

  signal in_window   : std_logic;
  signal vid_addr    : unsigned(G_ADDR_WIDTH - 1 downto 0);
  signal win_r       : std_logic;
  signal addr_r      : unsigned(G_ADDR_WIDTH - 1 downto 0);
  signal pix_r       : std_logic_vector(31 downto 0);

  attribute ram_style : string;
  attribute ram_style of ram : signal is "block";

  attribute MARK_DEBUG                 : string;
  attribute MARK_DEBUG of h_sync_d : signal is "TRUE";
  attribute MARK_DEBUG of h_sync_d : signal is "TRUE";
  attribute MARK_DEBUG of x_pos : signal is "TRUE";
  attribute MARK_DEBUG of y_pos : signal is "TRUE";
  attribute MARK_DEBUG of in_window : signal is "TRUE";
  attribute MARK_DEBUG of vid_addr : signal is "TRUE";
  attribute MARK_DEBUG of overlay_key : signal is "TRUE";
  attribute MARK_DEBUG of overlay_rgb : signal is "TRUE";
  attribute MARK_DEBUG of pick_bus : signal is "TRUE";
  attribute MARK_DEBUG of in_window : signal is "TRUE";
  attribute MARK_DEBUG of cpu_rdata_i : signal is "TRUE";



  function f_pick_sprite (
    global_en : std_logic;
    h_act     : std_logic;
    v_act     : std_logic;
    x_screen  : unsigned(10 downto 0);
    y_screen  : unsigned(10 downto 0);
    slots     : t_sprite_array
  ) return std_logic_vector is
    variable v_hit       : std_logic;
    variable v_addr      : unsigned(G_ADDR_WIDTH - 1 downto 0);
    variable v_addr_calc : unsigned(G_ADDR_WIDTH + 10 downto 0);
    variable lx          : unsigned(10 downto 0);
    variable ly          : unsigned(10 downto 0);
    variable w           : unsigned(10 downto 0);
    variable h           : unsigned(10 downto 0);
  begin
    v_hit  := '0';
    v_addr := (others => '0');

    if global_en = '1' and h_act = '1' and v_act = '1' then
      for i in 0 to C_NUM_SPRITES - 1 loop
        if slots(i).enable = '1' then
          w := unsigned(slots(i).width);
          h := unsigned(slots(i).height);
          if w /= 0 and h /= 0
             and x_screen >= unsigned(slots(i).x)
             and y_screen >= unsigned(slots(i).y) then
            lx := x_screen - unsigned(slots(i).x);
            ly := y_screen - unsigned(slots(i).y);
            if lx < w and ly < h then
              v_addr_calc := resize(unsigned(slots(i).base), v_addr_calc'length)
                             + ly * w + lx;
              if v_addr_calc < G_DEPTH then
                v_hit  := '1';
                v_addr := resize(v_addr_calc, G_ADDR_WIDTH);
              end if;
            end if;
          end if;
        end if;
      end loop;
    end if;

    return std_logic_vector(v_addr) & v_hit;
  end function f_pick_sprite;

  signal pick_bus : std_logic_vector(G_ADDR_WIDTH downto 0);

begin

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
        -- Reset Y at frame boundary on either v_sync edge so this still runs
        -- if timing polarity changes between modes.
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

  pick_bus <= f_pick_sprite(
    global_enable,
    '1' when h_sync = '0' else '0',
    '1' when v_sync = '0' else '0',
    x_pos,
    y_pos,
    sprites
  );

  vid_addr  <= unsigned(pick_bus(G_ADDR_WIDTH - 1 downto 0));
  in_window <= pick_bus(G_ADDR_WIDTH);

  p_video : process (pix_clk) is
    variable v_addr : integer range 0 to G_DEPTH - 1;
  begin
    if rising_edge(pix_clk) then
      if pix_rst = '1' then
        win_r       <= '0';
        addr_r      <= (others => '0');
        pix_r       <= (others => '0');
        overlay_key <= '0';
        overlay_rgb <= (others => '0');
      else
        win_r  <= in_window;
        addr_r <= vid_addr;
        v_addr := to_integer(addr_r);
        if v_addr >= 0 and v_addr < G_DEPTH then
          pix_r <= ram(v_addr);
        else
          pix_r <= (others => '0');
        end if;

        if win_r = '1' and pix_r(31) = '1' then
          overlay_key <= '1';
          overlay_rgb <= pix_r(23 downto 0);
        else
          overlay_key <= '0';
          overlay_rgb <= (others => '0');
        end if;
      end if;
    end if;
  end process p_video;

end architecture rtl;
