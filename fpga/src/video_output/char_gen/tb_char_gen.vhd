library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.char_font_pkg.all;

-- Checks a known glyph, a transparent hole, colour 0, a second cell,
-- and a CPU rewrite of one font row. Pixel result is C_CHAR_LAT clocks
-- after the edge that samples the pixel.

entity tb_char_gen is
end entity tb_char_gen;

architecture sim of tb_char_gen is

  constant C_BG : std_logic_vector(23 downto 0) := x"0000AA";

  signal clk           : std_logic := '0';
  signal rst           : std_logic := '1';
  signal h_sync        : std_logic := '0';
  signal v_sync        : std_logic := '0';
  signal active        : std_logic := '0';
  signal video_in      : std_logic_vector(23 downto 0) := (others => '0');
  signal cpu_cell_we   : std_logic := '0';
  signal cpu_cell_addr : std_logic_vector(11 downto 0) := (others => '0');
  signal cpu_cell_din  : std_logic_vector(15 downto 0) := (others => '0');
  signal cpu_cell_dout : std_logic_vector(15 downto 0);
  signal cpu_font_we   : std_logic := '0';
  signal cpu_font_addr : std_logic_vector(11 downto 0) := (others => '0');
  signal cpu_font_din  : std_logic_vector(15 downto 0) := (others => '0');
  signal cpu_font_dout : std_logic_vector(15 downto 0);
  signal video_out     : std_logic_vector(23 downto 0);

begin

  clk <= not clk after 5 ns;

  dut : entity work.char_gen
    port map (
      clk           => clk,
      rst           => rst,
      h_sync        => h_sync,
      v_sync        => v_sync,
      active        => active,
      video_in      => video_in,
      cpu_clk       => clk,
      cpu_cell_we   => cpu_cell_we,
      cpu_cell_addr => cpu_cell_addr,
      cpu_cell_din  => cpu_cell_din,
      cpu_cell_dout => cpu_cell_dout,
      cpu_font_we   => cpu_font_we,
      cpu_font_addr => cpu_font_addr,
      cpu_font_din  => cpu_font_din,
      cpu_font_dout => cpu_font_dout,
      video_out     => video_out
    );

  p_stim : process is
    variable errs : integer := 0;

    procedure check (cond : boolean; msg : string) is
    begin
      if not cond then
        report msg severity error;
        errs := errs + 1;
      end if;
    end procedure check;

    procedure clocks (n : integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure clocks;

    procedure cell_write (addr : integer; data : std_logic_vector(15 downto 0)) is
    begin
      cpu_cell_addr <= std_logic_vector(to_unsigned(addr, 12));
      cpu_cell_din  <= data;
      cpu_cell_we   <= '1';
      wait until rising_edge(clk);
      cpu_cell_we   <= '0';
    end procedure cell_write;

    procedure font_write (addr : integer; data : std_logic_vector(15 downto 0)) is
    begin
      cpu_font_addr <= std_logic_vector(to_unsigned(addr, 12));
      cpu_font_din  <= data;
      cpu_font_we   <= '1';
      wait until rising_edge(clk);
      cpu_font_we   <= '0';
    end procedure font_write;

    -- Expect the ROM glyph unless row_override is that row, in which case
    -- every pixel of the row is ink.
    procedure grab_line (
      y            : integer;
      n            : integer;
      cell0        : std_logic_vector(15 downto 0);
      cell1        : std_logic_vector(15 downto 0);
      row_override : integer
    ) is
      variable cell  : std_logic_vector(15 downto 0);
      variable ch    : integer;
      variable col   : integer;
      variable word  : t_word16;
      variable ink   : std_logic;
      variable expect : std_logic_vector(23 downto 0);
      variable pix_x : integer;
    begin
      for x in 0 to n - 1 loop
        active   <= '1';
        h_sync   <= '0';
        video_in <= C_BG;
        wait until rising_edge(clk);
        if x >= C_CHAR_LAT then
          pix_x := x - C_CHAR_LAT;
          if pix_x < 16 then
            cell := cell0;
            col  := pix_x;
          else
            cell := cell1;
            col  := pix_x - 16;
          end if;
          ch := to_integer(unsigned(cell(7 downto 0)));
          if y = row_override then
            word := x"FFFF";
          else
            word := f_font_word(ch * 16 + y);
          end if;
          ink := word(15 - col);
          if (cell(11 downto 8) /= "0000") and (ink = '1') then
            expect := f_palette(cell(11 downto 8));
          else
            expect := C_BG;
          end if;
          check(video_out = expect,
                "pixel x=" & integer'image(pix_x) & " y=" & integer'image(y));
        end if;
      end loop;
      active <= '0';
      for i in 0 to C_CHAR_LAT - 1 loop
        wait until rising_edge(clk);
        pix_x := n - C_CHAR_LAT + i;
        if pix_x < 16 then
          cell := cell0;
          col  := pix_x;
        else
          cell := cell1;
          col  := pix_x - 16;
        end if;
        ch := to_integer(unsigned(cell(7 downto 0)));
        if y = row_override then
          word := x"FFFF";
        else
          word := f_font_word(ch * 16 + y);
        end if;
        ink := word(15 - col);
        if (cell(11 downto 8) /= "0000") and (ink = '1') then
          expect := f_palette(cell(11 downto 8));
        else
          expect := C_BG;
        end if;
        check(video_out = expect,
              "flush x=" & integer'image(pix_x) & " y=" & integer'image(y));
      end loop;
      h_sync <= '1';
      clocks(2);
      h_sync <= '0';
      clocks(2);
    end procedure grab_line;

    procedure frame_sync is
    begin
      active <= '0';
      h_sync <= '0';
      v_sync <= '1';
      clocks(4);
      v_sync <= '0';
      clocks(2);
    end procedure frame_sync;

    variable cell_a : std_logic_vector(15 downto 0);
    variable cell_b : std_logic_vector(15 downto 0);
    variable saw_ink : boolean;
    variable saw_hole : boolean;
  begin
    active        <= '0';
    video_in      <= C_BG;
    cpu_cell_we   <= '0';
    cpu_font_we   <= '0';
    cpu_cell_addr <= (others => '0');
    cpu_font_addr <= (others => '0');
    clocks(2);
    rst <= '0';
    clocks(2);

    -- 'A' in white, full block in red.
    cell_a := x"0141";
    cell_b := x"039D";
    cell_write(0, cell_a);
    cell_write(1, cell_b);
    cpu_cell_addr <= (others => '0');
    clocks(2);
    check(cpu_cell_dout = cell_a, "cell 0 readback");
    cpu_cell_addr <= std_logic_vector(to_unsigned(1, 12));
    clocks(2);
    check(cpu_cell_dout = cell_b, "cell 1 readback");

    cpu_font_addr <= std_logic_vector(to_unsigned(16#41# * 16, 12));
    clocks(2);
    check(cpu_font_dout = f_font_word(16#41# * 16), "font row readback");

    frame_sync;
    saw_ink  := false;
    saw_hole := false;
    for y in 0 to 15 loop
      grab_line(y, 32, cell_a, cell_b, -1);
      for x in 0 to 15 loop
        if f_font_word(16#41# * 16 + y)(15 - x) = '1' then
          saw_ink := true;
        else
          saw_hole := true;
        end if;
      end loop;
    end loop;
    check(saw_ink, "glyph A has ink");
    check(saw_hole, "glyph A has a transparent hole");

    -- Colour 0: the glyph is still there, but the cell does not paint.
    cell_a := x"0041";
    cell_write(0, cell_a);
    frame_sync;
    grab_line(0, 16, cell_a, cell_b, -1);
    grab_line(1, 16, cell_a, cell_b, -1);

    -- Rewrite the top row of 'A' to solid ink and paint it white again.
    cell_a := x"0141";
    cell_write(0, cell_a);
    font_write(16#41# * 16, x"FFFF");
    cpu_font_addr <= std_logic_vector(to_unsigned(16#41# * 16, 12));
    clocks(2);
    check(cpu_font_dout = x"FFFF", "rewritten font row");
    frame_sync;
    grab_line(0, 16, cell_a, cell_b, 0);
    grab_line(1, 16, cell_a, cell_b, 0);

    if errs = 0 then
      report "char_gen tb passed" severity note;
    else
      report "char_gen tb failed, errors=" & integer'image(errs) severity failure;
    end if;
    wait;
  end process p_stim;

end architecture sim;
