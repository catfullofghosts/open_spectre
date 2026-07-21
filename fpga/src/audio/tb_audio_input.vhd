library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Self-checking testbench for audio_input.
-- Envelopes bypassed (shift=0) so crossover filter response is visible directly.
-- Drives independent left/right I2S; verifies outputs reflect left channel only.

entity tb_audio_input is
end entity tb_audio_input;

architecture sim of tb_audio_input is

  constant C_CLK_PERIOD : time := 10 ns;

  constant C_SIM_CLK_HZ         : positive := 1_000;
  constant C_SIM_MCLK_HZ        : positive := 100;
  constant C_SIM_BCLK_HZ        : positive := 50;
  constant C_SIM_BITS_PER_CH    : positive := 32;
  constant C_SIM_ENV_SHIFT      : natural  := 0; -- bypass envelope in TB
  constant C_SIM_BAND_ENV_SHIFT : natural  := 0; -- bypass band envelope in TB

  constant C_SAMPLE_LOUD : integer := 16#200000#; -- keep below f_to_out clip
  constant C_ZERO10      : std_logic_vector(9 downto 0) := (others => '0');

  type t_xover_table is array (natural range <>) of std_logic_vector(7 downto 0);

  signal clk            : std_logic := '0';
  signal rst            : std_logic := '1';
  signal crossover      : std_logic_vector(7 downto 0) := x"80";

  signal left_sample    : integer := 0;
  signal right_sample   : integer := 0;

  signal i2s_mclk       : std_logic;
  signal i2s_lrck       : std_logic;
  signal i2s_bclk       : std_logic;
  signal i2s_sdin       : std_logic := '0';
  signal i2s_sdout      : std_logic;

  signal saw_mclk  : boolean := false;
  signal saw_bclk  : boolean := false;
  signal saw_lrck  : boolean := false;

  signal audio_sig      : std_logic_vector(9 downto 0);
  signal audio_t        : std_logic_vector(9 downto 0);
  signal audio_b        : std_logic_vector(9 downto 0);

  impure function f_sample_vector (
    value : integer
  ) return std_logic_vector is
    variable v : signed(23 downto 0);
  begin
    v := to_signed(value, 24);
    return std_logic_vector(v);
  end function f_sample_vector;

  impure function f_u (
    value : std_logic_vector
  ) return natural is
  begin
    return to_integer(unsigned(value));
  end function f_u;

  procedure wait_bclk_falls (
    count : in natural
  ) is
    variable seen   : natural := 0;
    variable bclk_d : std_logic := '0';
  begin
    while seen < count loop
      wait until rising_edge(clk);
      if bclk_d = '1' and i2s_bclk = '0' then
        seen := seen + 1;
      end if;
      bclk_d := i2s_bclk;
    end loop;
  end procedure wait_bclk_falls;

  procedure wait_left_frames (
    count : in natural
  ) is
    variable seen   : natural := 0;
    variable lrck_d : std_logic := '0';
  begin
    while seen < count loop
      wait until rising_edge(clk);
      if lrck_d = '1' and i2s_lrck = '0' then
        seen := seen + 1;
      end if;
      lrck_d := i2s_lrck;
    end loop;
    wait_bclk_falls(24);
  end procedure wait_left_frames;

  procedure set_channels (
    signal left_s  : out integer;
    signal right_s : out integer;
    left_val       : in integer;
    right_val      : in integer
  ) is
  begin
    left_s  <= left_val;
    right_s <= right_val;
  end procedure set_channels;

begin

  dut : entity work.audio_input
    generic map (
      G_OUT_BITS       => 10,
      G_I2S_BITS       => 24,
      G_CLK_HZ         => C_SIM_CLK_HZ,
      G_MCLK_HZ        => C_SIM_MCLK_HZ,
      G_BCLK_HZ        => C_SIM_BCLK_HZ,
      G_BITS_PER_CH    => C_SIM_BITS_PER_CH,
      G_ENV_SHIFT      => C_SIM_ENV_SHIFT,
      G_BAND_ENV_SHIFT => C_SIM_BAND_ENV_SHIFT
    )
    port map (
      clk       => clk,
      rst       => rst,
      crossover => crossover,
      i2s_mclk  => i2s_mclk,
      i2s_lrck  => i2s_lrck,
      i2s_bclk  => i2s_bclk,
      i2s_sdin  => i2s_sdin,
      i2s_sdout => i2s_sdout,
      audio_sig => audio_sig,
      audio_t   => audio_t,
      audio_b   => audio_b
    );

  clk <= not clk after C_CLK_PERIOD / 2;

  p_clk_watch : process (clk) is
    variable mclk_d : std_logic := '0';
    variable bclk_d : std_logic := '0';
    variable lrck_d : std_logic := '0';
  begin
    if rising_edge(clk) then
      if mclk_d /= i2s_mclk then
        saw_mclk <= true;
      end if;
      if bclk_d /= i2s_bclk then
        saw_bclk <= true;
      end if;
      if lrck_d /= i2s_lrck then
        saw_lrck <= true;
      end if;
      mclk_d := i2s_mclk;
      bclk_d := i2s_bclk;
      lrck_d := i2s_lrck;
    end if;
  end process p_clk_watch;

  p_i2s_feed : process is
    variable tx_sample : std_logic_vector(23 downto 0) := (others => '0');
    variable bit_idx   : natural range 0 to 23 := 0;
    variable bclk_prev : std_logic := '0';
    variable lrck_prev : std_logic := '0';
    variable toggle_l  : boolean := false;
    variable toggle_r  : boolean := false;
  begin
    wait until rising_edge(clk);
    loop
      wait until rising_edge(clk);

      if lrck_prev /= i2s_lrck then
        bit_idx := 0;
        if i2s_lrck = '0' then
          if left_sample = -1 then
            if toggle_l then
              tx_sample := f_sample_vector(-C_SAMPLE_LOUD);
            else
              tx_sample := f_sample_vector(C_SAMPLE_LOUD);
            end if;
            toggle_l := not toggle_l;
          else
            tx_sample := f_sample_vector(left_sample);
          end if;
        else
          if right_sample = -1 then
            if toggle_r then
              tx_sample := f_sample_vector(-C_SAMPLE_LOUD);
            else
              tx_sample := f_sample_vector(C_SAMPLE_LOUD);
            end if;
            toggle_r := not toggle_r;
          else
            tx_sample := f_sample_vector(right_sample);
          end if;
        end if;
      end if;

      if bclk_prev = '1' and i2s_bclk = '0' then
        i2s_sdin <= tx_sample(23);
        tx_sample  := tx_sample(22 downto 0) & '0';
        if bit_idx = 23 then
          bit_idx := 0;
        else
          bit_idx := bit_idx + 1;
        end if;
      end if;

      bclk_prev := i2s_bclk;
      lrck_prev := i2s_lrck;
    end loop;
  end process p_i2s_feed;

  p_stim : process is
    constant C_XOVERS : t_xover_table(0 to 4) := (
      x"00", x"40", x"80", x"C0", x"FF"
    );
    type t_nat_array is array (natural range <>) of natural;
    variable bass_vals : t_nat_array(0 to 4);
    variable treb_vals : t_nat_array(0 to 4);
    variable sig_vals  : t_nat_array(0 to 4);
  begin
    report "tb_audio_input: start (envelopes bypassed, shift=0)";
    wait for 100 ns;

    assert audio_sig = C_ZERO10 and audio_t = C_ZERO10 and audio_b = C_ZERO10
      report "reset: outputs should be zero"
      severity failure;
    report "[PASS] reset defaults";

    rst <= '0';
    wait for 200 ns;

    -- Right channel must not affect outputs
    set_channels(left_sample, right_sample, 0, C_SAMPLE_LOUD);
    crossover <= x"40";
    wait_bclk_falls(C_SIM_BITS_PER_CH * 24 * 4);
    assert f_u(audio_sig) < 8 and f_u(audio_t) < 8 and f_u(audio_b) < 8
      report "right-only: outputs should stay near zero"
      severity failure;
    report "[PASS] left channel only";

    -- Steady left: full-band sig and bass rise; treble stays low at dark crossover
    set_channels(left_sample, right_sample, C_SAMPLE_LOUD, 0);
    crossover <= x"20";
    wait_left_frames(120);
    assert f_u(audio_sig) > 32
      report "steady left: full-band level too low (" & integer'image(f_u(audio_sig)) & ")"
      severity failure;
    assert f_u(audio_b) > 32
      report "steady left: bass too low (" & integer'image(f_u(audio_b)) & ")"
      severity failure;
    assert f_u(audio_t) < f_u(audio_b) / 4
      report "steady left: treble should stay below bass at dark crossover"
      severity failure;
    report "[PASS] steady left -> sig/bass, low treble";

    -- Graduated crossover sweep (envelope off): bass falls, treble rises
    set_channels(left_sample, right_sample, -1, 0);
    for step in C_XOVERS'range loop
      rst <= '1';
      wait for 100 ns;
      rst <= '0';
      wait for 200 ns;
      crossover <= C_XOVERS(step);
      wait_left_frames(160);
      bass_vals(step) := f_u(audio_b);
      treb_vals(step) := f_u(audio_t);
      sig_vals(step)  := f_u(audio_sig);
      report "filter xover=" & integer'image(to_integer(unsigned(C_XOVERS(step)))) &
             " bass=" & integer'image(bass_vals(step)) &
             " treb=" & integer'image(treb_vals(step)) &
             " sig=" & integer'image(sig_vals(step));
    end loop;

    for step in 0 to C_XOVERS'high - 1 loop
      assert bass_vals(step) >= bass_vals(step + 1)
        report "filter: bass should decrease as crossover rises (" &
               integer'image(bass_vals(step)) & " then " & integer'image(bass_vals(step + 1)) & ")"
        severity failure;
      assert treb_vals(step + 1) >= treb_vals(step)
        report "filter: treble should increase as crossover rises (" &
               integer'image(treb_vals(step)) & " then " & integer'image(treb_vals(step + 1)) & ")"
        severity failure;
    end loop;

    assert bass_vals(C_XOVERS'high) < bass_vals(C_XOVERS'low) / 2
      report "filter: brightest setting should cut bass well below darkest"
      severity failure;
    assert treb_vals(C_XOVERS'high) > treb_vals(C_XOVERS'low) + 8
      report "filter: brightest setting should exceed darkest treble"
      severity failure;
    report "[PASS] crossover filter is graduated (not all-or-nothing)";

    assert saw_mclk and saw_bclk and saw_lrck
      report "I2S clocks inactive"
      severity failure;
    report "[PASS] I2S clocks active";

    report "tb_audio_input: all checks passed";
    wait;
  end process p_stim;

end architecture sim;
