library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.overlay_sprite_pkg.all;

-- Text plane and sprite / pattern overlay.
-- Sits on the mixed picture, before the video effects.
-- Text is painted first. A sprite pixel with its opaque bit set covers the text.
-- A tiled sprite (tile width and height set) is the pattern overlay.
--
-- Video and sync are delayed together by 9 clocks. h_sync / v_sync are
-- idle-low, pulse-high. active is high on picture pixels, same as the mixer.

entity vdp is
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    h_sync     : in  std_logic;
    v_sync     : in  std_logic;
    active     : in  std_logic;
    video_in   : in  std_logic_vector(23 downto 0);
    video_o    : out std_logic_vector(23 downto 0);
    h_sync_o   : out std_logic;
    v_sync_o   : out std_logic;

    cpu_clk    : in  std_logic;
    cpu_en     : in  std_logic;
    cpu_we     : in  std_logic_vector(3 downto 0);
    cpu_addr   : in  std_logic_vector(10 downto 0);
    cpu_wdata  : in  std_logic_vector(31 downto 0);
    cpu_rdata  : out std_logic_vector(31 downto 0);

    global_enable : in  std_logic;
    block_div     : in  std_logic_vector(2 downto 0);
    sprites       : in  t_sprite_array;

    cpu_cell_we   : in  std_logic;
    cpu_cell_addr : in  std_logic_vector(11 downto 0);
    cpu_cell_din  : in  std_logic_vector(15 downto 0);
    cpu_cell_dout : out std_logic_vector(15 downto 0);
    cpu_font_we   : in  std_logic;
    cpu_font_addr : in  std_logic_vector(11 downto 0);
    cpu_font_din  : in  std_logic_vector(15 downto 0);
    cpu_font_dout : out std_logic_vector(15 downto 0)
  );
end entity vdp;

architecture rtl of vdp is

  -- char_gen assigns its pixel on the 3rd edge after the sample. The sprite
  -- pipeline assigns its pixel on the 7th. Four registers line the text up
  -- with that sprite pixel, and the output register makes the bus latency 9.
  -- Sync is one tap longer than the sprite pipeline so it leaves with the video.
  constant C_TEXT_DLY : integer := 4;
  constant C_SYNC_DLY : integer := 8;

  signal text_v   : std_logic_vector(23 downto 0);
  type t_text_pipe is array (0 to C_TEXT_DLY - 1) of std_logic_vector(23 downto 0);
  signal text_pipe : t_text_pipe := (others => (others => '0'));

  signal sprite_key : std_logic;
  signal sprite_rgb : std_logic_vector(23 downto 0);

  signal hs_pipe : std_logic_vector(C_SYNC_DLY - 1 downto 0) := (others => '0');
  signal vs_pipe : std_logic_vector(C_SYNC_DLY - 1 downto 0) := (others => '0');

begin

  text : entity work.char_gen
    port map (
      clk           => clk,
      rst           => rst,
      h_sync        => h_sync,
      v_sync        => v_sync,
      active        => active,
      video_in      => video_in,
      cpu_clk       => cpu_clk,
      cpu_cell_we   => cpu_cell_we,
      cpu_cell_addr => cpu_cell_addr,
      cpu_cell_din  => cpu_cell_din,
      cpu_cell_dout => cpu_cell_dout,
      cpu_font_we   => cpu_font_we,
      cpu_font_addr => cpu_font_addr,
      cpu_font_din  => cpu_font_din,
      cpu_font_dout => cpu_font_dout,
      video_out     => text_v
    );

  -- Lookahead 0: this block delays the text to the sprite pipeline,
  -- instead of asking the sprites to run ahead of an older video path.
  sprites_ov : entity work.overlay_framebuffer
    generic map (
      G_DEPTH      => 2048,
      G_ADDR_WIDTH => 11,
      G_VIDEO_LAT  => 0
    )
    port map (
      cpu_clk       => cpu_clk,
      cpu_en        => cpu_en,
      cpu_we        => cpu_we,
      cpu_addr      => cpu_addr,
      cpu_wdata     => cpu_wdata,
      cpu_rdata     => cpu_rdata,
      pix_clk       => clk,
      pix_rst       => rst,
      h_sync        => h_sync,
      v_sync        => v_sync,
      global_enable => global_enable,
      block_div     => block_div,
      sprites       => sprites,
      overlay_key   => sprite_key,
      overlay_rgb   => sprite_rgb
    );

  p_align : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        text_pipe <= (others => (others => '0'));
        hs_pipe   <= (others => '0');
        vs_pipe   <= (others => '0');
        video_o   <= (others => '0');
        h_sync_o  <= '0';
        v_sync_o  <= '0';
      else
        text_pipe(0) <= text_v;
        for i in 1 to C_TEXT_DLY - 1 loop
          text_pipe(i) <= text_pipe(i - 1);
        end loop;

        hs_pipe <= hs_pipe(C_SYNC_DLY - 2 downto 0) & h_sync;
        vs_pipe <= vs_pipe(C_SYNC_DLY - 2 downto 0) & v_sync;

        if sprite_key = '1' then
          video_o <= sprite_rgb;
        else
          video_o <= text_pipe(C_TEXT_DLY - 1);
        end if;
        h_sync_o <= hs_pipe(C_SYNC_DLY - 1);
        v_sync_o <= vs_pipe(C_SYNC_DLY - 1);
      end if;
    end if;
  end process p_align;

end architecture rtl;
