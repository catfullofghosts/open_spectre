library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_mix_wipe_bus is
end entity tb_mix_wipe_bus;

architecture sim of tb_mix_wipe_bus is

  constant C_LAT   : integer := 9;
  constant C_FRAME : integer := 100;

  -- Repeating raster. Sync idles low and pulses high, same as the wrapper.
  -- Blanking is longer than the mix latency so a line can flush before the
  -- next active pixel.
  constant C_H_FP   : integer := 4;
  constant C_H_SYNC : integer := 8;
  constant C_H_BP   : integer := 8;
  constant C_H_TOT  : integer := C_FRAME + C_H_FP + C_H_SYNC + C_H_BP;
  constant C_V_FP   : integer := 2;
  constant C_V_SYNC : integer := 2;
  constant C_V_BP   : integer := 2;
  constant C_V_TOT  : integer := C_FRAME + C_V_FP + C_V_SYNC + C_V_BP;

  signal clk      : std_logic := '0';
  signal rst      : std_logic := '1';
  signal h_sync   : std_logic := '0';
  signal v_sync   : std_logic := '0';
  signal active   : std_logic := '0';
  signal video_a  : std_logic_vector(23 downto 0) := (others => '0');
  signal video_b  : std_logic_vector(23 downto 0) := (others => '0');
  signal mode     : std_logic_vector(3 downto 0) := "0000";
  signal origin   : std_logic_vector(3 downto 0) := "0000";
  signal invert   : std_logic := '0';
  signal pos      : std_logic_vector(12 downto 0) := (others => '0');
  signal soft     : std_logic_vector(11 downto 0) := (others => '0');
  signal frame_w  : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(C_FRAME, 12));
  signal frame_h  : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(C_FRAME, 12));
  signal video_o  : std_logic_vector(23 downto 0);
  signal h_sync_o : std_logic;
  signal v_sync_o : std_logic;
  signal active_o : std_logic;

  -- Pixel the next rising edge will sample. The sync process keeps this
  -- moving for the whole simulation.
  signal ras_x   : integer := 0;
  signal ras_y   : integer := 0;
  signal ras_pic : std_logic := '0';

begin

  clk <= not clk after 5 ns;

  -- h_sync and v_sync free-run until the simulator stops.
  p_sync : process is
    variable hx : integer := 0;
    variable vy : integer := 0;
  begin
    loop
      if (hx >= C_FRAME + C_H_FP) and (hx < C_FRAME + C_H_FP + C_H_SYNC) then
        h_sync <= '1';
      else
        h_sync <= '0';
      end if;
      if (vy >= C_FRAME + C_V_FP) and (vy < C_FRAME + C_V_FP + C_V_SYNC) then
        v_sync <= '1';
      else
        v_sync <= '0';
      end if;
      ras_x <= hx;
      ras_y <= vy;
      if (hx < C_FRAME) and (vy < C_FRAME) then
        ras_pic <= '1';
      else
        ras_pic <= '0';
      end if;

      wait until rising_edge(clk);

      if hx = C_H_TOT - 1 then
        hx := 0;
        if vy = C_V_TOT - 1 then
          vy := 0;
        else
          vy := vy + 1;
        end if;
      else
        hx := hx + 1;
      end if;
    end loop;
  end process p_sync;

  dut : entity work.mix_wipe_bus
    port map (
      clk      => clk,
      rst      => rst,
      h_sync   => h_sync,
      v_sync   => v_sync,
      active   => active,
      video_a  => video_a,
      video_b  => video_b,
      mode     => mode,
      origin   => origin,
      invert   => invert,
      pos      => pos,
      soft     => soft,
      frame_w  => frame_w,
      frame_h  => frame_h,
      video_o  => video_o,
      h_sync_o => h_sync_o,
      v_sync_o => v_sync_o,
      active_o => active_o
    );

  p_stim : process is
    variable seen : integer;
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

    type t_line is array (0 to C_FRAME - 1) of std_logic_vector(23 downto 0);
    variable got : t_line;

    -- The mix result is C_LAT clocks behind the pixel that produced it, so
    -- on a line longer than that the first pixels are already coming out
    -- while the rest of the line is still going in. n is the active width.
    -- Called on a falling edge, ras_* is the pixel the next rising edge samples.
    procedure grab (n : integer) is
      variable k : integer := 0;
    begin
      active <= '0';
      loop
        wait until falling_edge(clk);
        exit when (ras_pic = '1') and (ras_x = 0);
      end loop;
      active <= '1';
      for i in 0 to n - 1 loop
        wait until rising_edge(clk);
        if i >= C_LAT then
          got(k) := video_o;
          k := k + 1;
        end if;
        if i = n - 1 then
          active <= '0';
        end if;
      end loop;
      for i in 0 to C_LAT - 1 loop
        wait until rising_edge(clk);
        got(k) := video_o;
        k := k + 1;
      end loop;
    end procedure grab;

    -- Sit out the rest of this frame. The next grab is line 0.
    procedure frame_reset is
    begin
      active <= '0';
      loop
        wait until falling_edge(clk);
        exit when v_sync = '1';
      end loop;
      loop
        wait until falling_edge(clk);
        exit when v_sync = '0';
      end loop;
    end procedure frame_reset;
  begin
    active  <= '0';
    video_a <= (others => '0');
    video_b <= (others => '0');
    mode    <= "0000";
    origin  <= "0000";
    invert  <= '0';
    pos     <= (others => '0');
    soft    <= (others => '0');
    clocks(2);
    rst <= '0';
    clocks(2);

    -- One red A pixel, mix at 0. Output should be that pixel 8 clocks later.
    active  <= '1';
    video_a <= x"0000FF";
    video_b <= x"00FF00";
    pos     <= std_logic_vector(to_unsigned(0, 13));
    wait until rising_edge(clk);
    video_a <= (others => '0');
    seen := -1;
    for i in 1 to 16 loop
      wait until rising_edge(clk);
      if video_o = x"0000FF" then
        seen := i;
        exit;
      end if;
    end loop;
    check(seen = C_LAT, "mix latency " & integer'image(seen));

    video_a <= x"0000FF";
    video_b <= x"00FF00";
    pos     <= std_logic_vector(to_unsigned(4095, 13));
    clocks(10);
    check(video_o = x"00FF00", "full B mix");

    invert <= '1';
    clocks(10);
    check(video_o = x"0000FF", "invert swaps full B back to A");
    invert <= '0';

    video_a <= x"000000";
    video_b <= x"FFFFFF";
    pos     <= std_logic_vector(to_unsigned(2048, 13));
    clocks(10);
    check(video_o = x"7F7F7F", "half mix got " & integer'image(to_integer(unsigned(video_o))));

    loop
      wait until falling_edge(clk);
      exit when h_sync = '1';
    end loop;
    wait until rising_edge(clk);
    seen := -1;
    for i in 1 to 16 loop
      wait until rising_edge(clk);
      if h_sync_o = '1' then
        seen := i;
        exit;
      end if;
    end loop;
    check(seen = C_LAT, "sync latency " & integer'image(seen));

    -- Hard horizontal wipe on the 100-wide frame, edge at x = 40.
    mode    <= "0001";
    origin  <= "0000";
    pos     <= std_logic_vector(to_unsigned(40, 13));
    soft    <= (others => '0');
    video_a <= x"000000";
    video_b <= x"FFFFFF";
    frame_reset;
    grab(C_FRAME);
    for x in 0 to C_FRAME - 1 loop
      if x < 40 then
        check(got(x) = x"FFFFFF", "hard wipe B at x=" & integer'image(x));
      else
        check(got(x) = x"000000", "hard wipe A at x=" & integer'image(x));
      end if;
    end loop;

    -- From the right: coord = 99-x, so x > 59 is B.
    origin <= "0001";
    frame_reset;
    grab(C_FRAME);
    for x in 0 to C_FRAME - 1 loop
      if x > 59 then
        check(got(x) = x"FFFFFF", "right wipe B at x=" & integer'image(x));
      else
        check(got(x) = x"000000", "right wipe A at x=" & integer'image(x));
      end if;
    end loop;

    -- Vertical, edge at y = 30. Every line of the frame is sent.
    mode   <= "0010";
    origin <= "0000";
    pos    <= std_logic_vector(to_unsigned(30, 13));
    frame_reset;
    for line in 0 to C_FRAME - 1 loop
      grab(C_FRAME);
      for x in 0 to C_FRAME - 1 loop
        if line < 30 then
          check(got(x) = x"FFFFFF", "vertical B y=" & integer'image(line));
        else
          check(got(x) = x"000000", "vertical A y=" & integer'image(line));
        end if;
      end loop;
    end loop;

    -- Soft edge, 20 pixels wide, centred on x = 50.
    -- span = 50 + 10 - x. Full B at x <= 40, then 3/4, 1/2, 1/4, full A.
    mode   <= "0001";
    origin <= "0000";
    pos    <= std_logic_vector(to_unsigned(50, 13));
    soft   <= std_logic_vector(to_unsigned(20, 12));
    clocks(40);
    frame_reset;
    grab(C_FRAME);
    check(got(0) = x"FFFFFF", "soft full B at x=0");
    check(got(40) = x"FFFFFF", "soft full B at x=40");
    check(got(45) = x"BFBFBF", "soft 3/4 at x=45");
    check(got(50) = x"7F7F7F", "soft half at x=50");
    check(got(55) = x"3F3F3F", "soft 1/4 at x=55");
    check(got(60) = x"000000", "soft full A at x=60");
    check(got(99) = x"000000", "soft full A at x=99");

    -- Square from the NW corner, hard edge at distance 30.
    mode   <= "0011";
    origin <= x"8";
    pos    <= std_logic_vector(to_unsigned(30, 13));
    soft   <= (others => '0');
    frame_reset;
    for line in 0 to 30 loop
      grab(C_FRAME);
      for x in 0 to C_FRAME - 1 loop
        if (x < 30) and (line < 30) then
          check(got(x) = x"FFFFFF", "corner square B");
        else
          check(got(x) = x"000000", "corner square A");
        end if;
      end loop;
    end loop;

    -- Square from the centre. Centre pixel is 50, radius 10.
    origin <= x"0";
    pos    <= std_logic_vector(to_unsigned(10, 13));
    frame_reset;
    for line in 0 to 50 loop
      grab(C_FRAME);
      if line = 40 then
        for x in 0 to C_FRAME - 1 loop
          check(got(x) = x"000000", "centre square outside");
        end loop;
      elsif line = 50 then
        for x in 0 to C_FRAME - 1 loop
          if (x >= 41) and (x <= 59) then
            check(got(x) = x"FFFFFF", "centre square B at x=" & integer'image(x));
          else
            check(got(x) = x"000000", "centre square A at x=" & integer'image(x));
          end if;
        end loop;
      end if;
    end loop;

    -- Diagonal from the top left. coord = x + y, edge at 20.
    mode   <= "0100";
    origin <= "0000";
    pos    <= std_logic_vector(to_unsigned(20, 13));
    frame_reset;
    for line in 0 to 20 loop
      grab(C_FRAME);
      for x in 0 to C_FRAME - 1 loop
        if (x + line) < 20 then
          check(got(x) = x"FFFFFF", "diagonal B");
        else
          check(got(x) = x"000000", "diagonal A");
        end if;
      end loop;
    end loop;

    -- Diamond from the NW corner. Distance is x + y, edge at 30.
    mode   <= "0101";
    origin <= x"8";
    pos    <= std_logic_vector(to_unsigned(30, 13));
    soft   <= (others => '0');
    frame_reset;
    for line in 0 to 30 loop
      grab(C_FRAME);
      for x in 0 to C_FRAME - 1 loop
        if (x + line) < 30 then
          check(got(x) = x"FFFFFF", "diamond B");
        else
          check(got(x) = x"000000", "diamond A");
        end if;
      end loop;
    end loop;

    -- Cross from the centre. B when close to x = 50 or y = 50. Radius 10.
    mode   <= "0110";
    origin <= x"0";
    pos    <= std_logic_vector(to_unsigned(10, 13));
    frame_reset;
    for line in 0 to 50 loop
      grab(C_FRAME);
      if line = 0 then
        for x in 0 to C_FRAME - 1 loop
          if (x >= 41) and (x <= 59) then
            check(got(x) = x"FFFFFF", "cross arm B");
          else
            check(got(x) = x"000000", "cross arm A");
          end if;
        end loop;
      elsif line = 50 then
        for x in 0 to C_FRAME - 1 loop
          check(got(x) = x"FFFFFF", "cross bar B");
        end loop;
      end if;
    end loop;

    -- Barn doors opening left and right from x = 50, half-width 10.
    mode   <= "0111";
    origin <= "0000";
    frame_reset;
    grab(C_FRAME);
    for x in 0 to C_FRAME - 1 loop
      if (x >= 41) and (x <= 59) then
        check(got(x) = x"FFFFFF", "barn vertical B");
      else
        check(got(x) = x"000000", "barn vertical A");
      end if;
    end loop;

    -- Barn doors opening up and down from y = 50.
    origin <= "0001";
    frame_reset;
    for line in 0 to 60 loop
      grab(C_FRAME);
      for x in 0 to C_FRAME - 1 loop
        if (line >= 41) and (line <= 59) then
          check(got(x) = x"FFFFFF", "barn horizontal B");
        else
          check(got(x) = x"000000", "barn horizontal A");
        end if;
      end loop;
    end loop;

    -- Vertical blinds, 16-pixel bands, first half of each band is B.
    mode   <= "1000";
    origin <= "1000";
    pos    <= std_logic_vector(to_unsigned(8, 13));
    frame_reset;
    grab(C_FRAME);
    for x in 0 to C_FRAME - 1 loop
      if (x mod 16) < 8 then
        check(got(x) = x"FFFFFF", "blinds column B");
      else
        check(got(x) = x"000000", "blinds column A");
      end if;
    end loop;

    -- Diagonal blinds, (x + y) mod 16. Check the second line.
    origin <= "1010";
    frame_reset;
    for line in 0 to 1 loop
      grab(C_FRAME);
      if line = 1 then
        for x in 0 to C_FRAME - 1 loop
          if ((x + 1) mod 16) < 8 then
            check(got(x) = x"FFFFFF", "blinds diagonal B");
          else
            check(got(x) = x"000000", "blinds diagonal A");
          end if;
        end loop;
      end if;
    end loop;

    if errs = 0 then
      report "mix_wipe_bus tb passed" severity note;
    else
      report "mix_wipe_bus tb failed, errors=" & integer'image(errs) severity failure;
    end if;
    wait;
  end process p_stim;

end architecture sim;
