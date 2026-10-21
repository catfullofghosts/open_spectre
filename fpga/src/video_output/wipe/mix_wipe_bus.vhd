library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Mixer / wipe between two video streams that already share a clock and sync.
-- Stream A is the spectron picture before the FX chain. Stream B is the
-- external DVI/HDMI input. Instantiated in the spectron wrapper, before
-- video_effects. Power-up mix position 0 passes A straight through.
--
-- Packing is B(23:16) & G(15:8) & R(7:0), same as video_effects.
-- h_sync / v_sync are idle-low, pulse-high, same as h_sync_n in the wrapper.
-- `active` is high on picture pixels. x is 0 on the first active pixel of a
-- line, y is 0 on the first active line after v_sync. Tie `active` high only
-- if every non-sync pixel should count, including blanking.
--
-- Controls:
--   mode   see wipe_shape (mix, H, V, square, diagonal, diamond, cross,
--          barn doors, blinds)
--   origin see wipe_shape
--   pos    mix: 0 = all A, 4095 = all B. wipes: edge position in pixels
--   soft   soft-edge width in pixels, 0 = hard cut
--   invert swaps A and B
--   frame_w / frame_h  counted raster the shaped wipes use
--
-- Output video and sync are delayed together by 13 clocks.
-- Shape and soft-edge each have a register on their inputs and outputs.

entity mix_wipe_bus is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    h_sync   : in  std_logic;
    v_sync   : in  std_logic;
    active   : in  std_logic;
    video_a  : in  std_logic_vector(23 downto 0);
    video_b  : in  std_logic_vector(23 downto 0);
    mode     : in  std_logic_vector(3 downto 0);
    origin   : in  std_logic_vector(3 downto 0);
    invert   : in  std_logic;
    pos      : in  std_logic_vector(12 downto 0);
    soft     : in  std_logic_vector(11 downto 0);
    frame_w  : in  std_logic_vector(11 downto 0);
    frame_h  : in  std_logic_vector(11 downto 0);
    video_o  : out std_logic_vector(23 downto 0);
    h_sync_o : out std_logic;
    v_sync_o : out std_logic;
    active_o : out std_logic
  );
end entity mix_wipe_bus;

architecture rtl of mix_wipe_bus is

  -- Video is registered with x/y, then held to meet the alpha.
  -- Shape in, shape out, edge in and edge out are each one extra clock
  -- around the 3-cycle soft edge. The last sync tap lines up with the mix
  -- result, 13 clocks after the input pixel is sampled.
  constant C_VID_DLY  : integer := 8;
  constant C_SYNC_DLY : integer := 13;

  signal x_run    : unsigned(11 downto 0) := (others => '0');
  signal y_run    : unsigned(11 downto 0) := (others => '0');
  signal x_d      : std_logic_vector(11 downto 0) := (others => '0');
  signal y_d      : std_logic_vector(11 downto 0) := (others => '0');
  signal active_d : std_logic := '0';

  signal x_s      : std_logic_vector(11 downto 0) := (others => '0');
  signal y_s      : std_logic_vector(11 downto 0) := (others => '0');
  signal fw_s     : std_logic_vector(11 downto 0) := (others => '0');
  signal fh_s     : std_logic_vector(11 downto 0) := (others => '0');
  signal mode_s   : std_logic_vector(3 downto 0) := (others => '0');
  signal origin_s : std_logic_vector(3 downto 0) := (others => '0');

  signal coord     : std_logic_vector(12 downto 0);
  signal mix_mode  : std_logic;
  signal coord_r   : std_logic_vector(12 downto 0) := (others => '0');
  signal mix_r     : std_logic := '0';
  signal coord_e   : std_logic_vector(12 downto 0) := (others => '0');
  signal mix_e     : std_logic := '0';
  signal pos_e     : std_logic_vector(12 downto 0) := (others => '0');
  signal soft_e    : std_logic_vector(11 downto 0) := (others => '0');
  signal inv_e     : std_logic := '0';
  signal alpha     : std_logic_vector(11 downto 0);
  signal alpha_r   : std_logic_vector(11 downto 0) := (others => '0');
  signal a_at_mix  : std_logic_vector(23 downto 0);
  signal b_at_mix  : std_logic_vector(23 downto 0);

  type t_vid_pipe is array (0 to C_VID_DLY - 1) of std_logic_vector(23 downto 0);
  signal a_pipe : t_vid_pipe := (others => (others => '0'));
  signal b_pipe : t_vid_pipe := (others => (others => '0'));

  signal hs_pipe : std_logic_vector(C_SYNC_DLY - 1 downto 0) := (others => '0');
  signal vs_pipe : std_logic_vector(C_SYNC_DLY - 1 downto 0) := (others => '0');
  signal ac_pipe : std_logic_vector(C_SYNC_DLY - 1 downto 0) := (others => '0');

begin

  p_raster : process (clk) is
    variable xv : unsigned(11 downto 0);
    variable yv : unsigned(11 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        x_run    <= (others => '0');
        y_run    <= (others => '0');
        x_d      <= (others => '0');
        y_d      <= (others => '0');
        active_d <= '0';
        a_pipe   <= (others => (others => '0'));
        b_pipe   <= (others => (others => '0'));
        hs_pipe  <= (others => '0');
        vs_pipe  <= (others => '0');
        ac_pipe  <= (others => '0');
      else
        xv := x_run;
        yv := y_run;

        if v_sync = '1' then
          x_run    <= (others => '0');
          y_run    <= (others => '0');
          xv       := (others => '0');
          yv       := (others => '0');
          active_d <= '0';
        elsif (active = '1') and (h_sync = '0') then
          if active_d = '0' then
            xv    := (others => '0');
            x_run <= to_unsigned(1, x_run'length);
          else
            x_run <= x_run + 1;
          end if;
          active_d <= '1';
        else
          if active_d = '1' then
            y_run <= y_run + 1;
          end if;
          x_run    <= (others => '0');
          xv       := (others => '0');
          active_d <= '0';
        end if;

        x_d <= std_logic_vector(xv);
        y_d <= std_logic_vector(yv);

        a_pipe(0) <= video_a;
        b_pipe(0) <= video_b;
        for i in 1 to C_VID_DLY - 1 loop
          a_pipe(i) <= a_pipe(i - 1);
          b_pipe(i) <= b_pipe(i - 1);
        end loop;

        hs_pipe <= hs_pipe(C_SYNC_DLY - 2 downto 0) & h_sync;
        vs_pipe <= vs_pipe(C_SYNC_DLY - 2 downto 0) & v_sync;
        ac_pipe <= ac_pipe(C_SYNC_DLY - 2 downto 0) & active;
      end if;
    end if;
  end process p_raster;

  -- Box the shape and the edge so each combinational cloud starts and
  -- ends on a register. Shape out and edge in are two flops, not one.
  p_io : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        x_s      <= (others => '0');
        y_s      <= (others => '0');
        fw_s     <= (others => '0');
        fh_s     <= (others => '0');
        mode_s   <= (others => '0');
        origin_s <= (others => '0');
        coord_r  <= (others => '0');
        mix_r    <= '0';
        coord_e  <= (others => '0');
        mix_e    <= '0';
        pos_e    <= (others => '0');
        soft_e   <= (others => '0');
        inv_e    <= '0';
        alpha_r  <= (others => '0');
      else
        x_s      <= x_d;
        y_s      <= y_d;
        fw_s     <= frame_w;
        fh_s     <= frame_h;
        mode_s   <= mode;
        origin_s <= origin;

        coord_r <= coord;
        mix_r   <= mix_mode;

        coord_e <= coord_r;
        mix_e   <= mix_r;
        pos_e   <= pos;
        soft_e  <= soft;
        inv_e   <= invert;

        alpha_r <= alpha;
      end if;
    end if;
  end process p_io;

  shape : entity work.wipe_shape
    port map (
      x        => x_s,
      y        => y_s,
      frame_w  => fw_s,
      frame_h  => fh_s,
      mode     => mode_s,
      origin   => origin_s,
      coord    => coord,
      mix_mode => mix_mode
    );

  edge : entity work.wipe_soft_edge
    port map (
      clk      => clk,
      rst      => rst,
      coord    => coord_e,
      pos      => pos_e,
      soft     => soft_e,
      mix_mode => mix_e,
      invert   => inv_e,
      alpha    => alpha
    );

  a_at_mix <= a_pipe(C_VID_DLY - 1);
  b_at_mix <= b_pipe(C_VID_DLY - 1);

  mix : entity work.video_ab_mix
    port map (
      clk     => clk,
      video_a => a_at_mix,
      video_b => b_at_mix,
      alpha   => alpha_r,
      video_o => video_o
    );

  h_sync_o <= hs_pipe(C_SYNC_DLY - 1);
  v_sync_o <= vs_pipe(C_SYNC_DLY - 1);
  active_o <= ac_pipe(C_SYNC_DLY - 1);

end architecture rtl;
