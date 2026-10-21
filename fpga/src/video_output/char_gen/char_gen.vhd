library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.char_font_pkg.all;

-- Stationary 720p text plane. 80 x 45 cells of 16 x 16.
-- A font bit of 1 paints the cell colour. A font bit of 0 leaves the
-- video underneath. Colour 0 leaves the whole cell transparent.
--
-- video_out is C_CHAR_LAT clocks after the pixel is sampled, counted the
-- same way as the mixer: the new pixel is what a process sees on the
-- following rising edge. Transparent pixels are the delayed input.
-- h_sync / v_sync are idle-low, pulse-high. active is high on picture pixels.
-- x is 0 on the first active pixel of a line, y is 0 on the first line.
--
-- Cell word: [7:0] character, [11:8] colour, [15:12] spare.
-- CPU reads return the addressed word one clock after the address.
-- Font address is character & row, 4096 words of 16 bits (bit 15 is left).

entity char_gen is
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;
    h_sync        : in  std_logic;
    v_sync        : in  std_logic;
    active        : in  std_logic;
    video_in      : in  std_logic_vector(23 downto 0);
    cpu_clk       : in  std_logic;
    cpu_cell_we   : in  std_logic;
    cpu_cell_addr : in  std_logic_vector(11 downto 0);
    cpu_cell_din  : in  std_logic_vector(15 downto 0);
    cpu_cell_dout : out std_logic_vector(15 downto 0);
    cpu_font_we   : in  std_logic;
    cpu_font_addr : in  std_logic_vector(11 downto 0);
    cpu_font_din  : in  std_logic_vector(15 downto 0);
    cpu_font_dout : out std_logic_vector(15 downto 0);
    video_out     : out std_logic_vector(23 downto 0)
  );
end entity char_gen;

architecture rtl of char_gen is

  shared variable cell_ram : t_ram := (others => (others => '0'));
  shared variable font_ram : t_ram := f_font_init;

  attribute ram_style : string;
  attribute ram_style of cell_ram : variable is "block";
  attribute ram_style of font_ram : variable is "block";

  signal x_run    : unsigned(11 downto 0) := (others => '0');
  signal y_run    : unsigned(11 downto 0) := (others => '0');
  signal active_d : std_logic := '0';

  signal x0        : std_logic_vector(11 downto 0) := (others => '0');
  signal y0        : std_logic_vector(11 downto 0) := (others => '0');
  signal v0        : std_logic_vector(23 downto 0) := (others => '0');
  signal a0        : std_logic := '0';
  signal cell_addr : std_logic_vector(11 downto 0) := (others => '0');

  signal x1     : std_logic_vector(11 downto 0) := (others => '0');
  signal y1     : std_logic_vector(11 downto 0) := (others => '0');
  signal v1     : std_logic_vector(23 downto 0) := (others => '0');
  signal a1     : std_logic := '0';
  signal cell_q : std_logic_vector(15 downto 0) := (others => '0');

  signal x2     : std_logic_vector(11 downto 0) := (others => '0');
  signal v2     : std_logic_vector(23 downto 0) := (others => '0');
  signal a2     : std_logic := '0';
  signal c2     : std_logic_vector(3 downto 0) := (others => '0');
  signal font_q : std_logic_vector(15 downto 0) := (others => '0');

begin

  p_raster : process (clk) is
    variable xv  : unsigned(11 downto 0);
    variable yv  : unsigned(11 downto 0);
    variable row : unsigned(7 downto 0);
    variable col : unsigned(11 downto 0);
    variable idx : unsigned(11 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        x_run     <= (others => '0');
        y_run     <= (others => '0');
        active_d  <= '0';
        x0        <= (others => '0');
        y0        <= (others => '0');
        v0        <= (others => '0');
        a0        <= '0';
        cell_addr <= (others => '0');
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

        x0 <= std_logic_vector(xv);
        y0 <= std_logic_vector(yv);
        v0 <= video_in;

        if (active = '1') and (h_sync = '0')
           and (xv < C_FRAME_W) and (yv < C_FRAME_H) then
          a0  <= '1';
          row := yv(11 downto 4);
          col := resize(xv(11 downto 4), 12);
          idx := resize(row * to_unsigned(80, 8), 12) + col;
          cell_addr <= std_logic_vector(idx);
        else
          a0        <= '0';
          cell_addr <= (others => '0');
        end if;
      end if;
    end if;
  end process p_raster;

  -- Cell word for the pixel registered on the previous clock.
  p_cell : process (clk) is
    variable addr_v : integer range 0 to 4095;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        x1     <= (others => '0');
        y1     <= (others => '0');
        v1     <= (others => '0');
        a1     <= '0';
        cell_q <= (others => '0');
      else
        addr_v := to_integer(unsigned(cell_addr));
        cell_q <= cell_ram(addr_v);
        x1     <= x0;
        y1     <= y0;
        v1     <= v0;
        a1     <= a0;
      end if;
    end if;
  end process p_cell;

  -- Font row. Address is combinational from the cell word so this is one clock.
  p_font : process (clk) is
    variable addr_v : integer range 0 to 4095;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        x2     <= (others => '0');
        v2     <= (others => '0');
        a2     <= '0';
        c2     <= (others => '0');
        font_q <= (others => '0');
      else
        addr_v := to_integer(unsigned(cell_q(7 downto 0)) & unsigned(y1(3 downto 0)));
        font_q <= font_ram(addr_v);
        x2     <= x1;
        v2     <= v1;
        a2     <= a1;
        c2     <= cell_q(11 downto 8);
      end if;
    end if;
  end process p_font;

  p_paint : process (clk) is
    variable bit_i : integer range 0 to 15;
    variable pix   : std_logic_vector(23 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        video_out <= (others => '0');
      else
        bit_i := 15 - to_integer(unsigned(x2(3 downto 0)));
        if (a2 = '1') and (c2 /= "0000") and (font_q(bit_i) = '1') then
          pix := f_palette(c2);
        else
          pix := v2;
        end if;
        video_out <= pix;
      end if;
    end if;
  end process p_paint;

  p_cpu_cell : process (cpu_clk) is
    variable addr_v : integer range 0 to 4095;
  begin
    if rising_edge(cpu_clk) then
      addr_v := to_integer(unsigned(cpu_cell_addr));
      if cpu_cell_we = '1' then
        cell_ram(addr_v) := cpu_cell_din;
      end if;
      cpu_cell_dout <= cell_ram(addr_v);
    end if;
  end process p_cpu_cell;

  p_cpu_font : process (cpu_clk) is
    variable addr_v : integer range 0 to 4095;
  begin
    if rising_edge(cpu_clk) then
      addr_v := to_integer(unsigned(cpu_font_addr));
      if cpu_font_we = '1' then
        font_ram(addr_v) := cpu_font_din;
      end if;
      cpu_font_dout <= font_ram(addr_v);
    end if;
  end process p_cpu_font;

end architecture rtl;
