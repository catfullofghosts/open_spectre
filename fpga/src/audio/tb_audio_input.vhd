library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Self-checking testbench for audio_input.
-- Feeds serial left-channel I2S data in sync with the DUT-generated BCLK/LRCK.

entity tb_audio_input is
end entity tb_audio_input;

architecture sim of tb_audio_input is

  constant C_CLK_PERIOD : time := 10 ns; -- 100 MHz

  -- Shortened dividers so envelope/crossover tests finish quickly in sim.
  constant C_SIM_CLK_HZ      : positive := 1_000;
  constant C_SIM_MCLK_HZ     : positive := 100;
  constant C_SIM_BCLK_HZ     : positive := 50;
  constant C_SIM_BITS_PER_CH : positive := 32;
  constant C_SIM_ENV_SHIFT   : natural  := 3;

  type t_stim_mode is (STIM_STEADY, STIM_TOGGLE);

  signal clk            : std_logic := '0';
  signal rst            : std_logic := '1';
  signal crossover      : std_logic_vector(7 downto 0) := x"80";
  signal stim_mode      : t_stim_mode := STIM_STEADY;

  signal i2s_mclk       : std_logic;
  signal i2s_lrck       : std_logic;
  signal i2s_bclk       : std_logic;
  signal i2s_sdin       : std_logic := '0';
  signal i2s_sdout      : std_logic;

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

  procedure wait_left_bits (
    count : in natural
  ) is
    variable seen   : natural := 0;
    variable bclk_d : std_logic := '0';
  begin
    while seen < count loop
      wait until rising_edge(clk);
      if bclk_d = '1' and i2s_bclk = '0' and i2s_lrck = '0' then
        seen := seen + 1;
      end if;
      bclk_d := i2s_bclk;
    end loop;
  end procedure wait_left_bits;

begin

  dut : entity work.audio_input
    generic map (
      G_OUT_BITS    => 10,
      G_I2S_BITS    => 24,
      G_CLK_HZ      => C_SIM_CLK_HZ,
      G_MCLK_HZ     => C_SIM_MCLK_HZ,
      G_BCLK_HZ     => C_SIM_BCLK_HZ,
      G_BITS_PER_CH => C_SIM_BITS_PER_CH,
      G_ENV_SHIFT   => C_SIM_ENV_SHIFT
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

  p_i2s_feed : process is
    variable tx_sample  : std_logic_vector(23 downto 0) := f_sample_vector(16#500000#);
    variable bit_idx    : natural range 0 to 23 := 0;
    variable bclk_prev  : std_logic := '0';
    variable toggle_neg : boolean := false;
  begin
    wait until rising_edge(clk);
    loop
      wait until rising_edge(clk);
      if bclk_prev = '1' and i2s_bclk = '0' and i2s_lrck = '0' then
        i2s_sdin <= tx_sample(23);
        tx_sample  := tx_sample(22 downto 0) & '0';
        if bit_idx = 23 then
          bit_idx := 0;
          case stim_mode is
            when STIM_STEADY =>
              tx_sample := f_sample_vector(16#500000#);
            when STIM_TOGGLE =>
              if toggle_neg then
                tx_sample := f_sample_vector(-16#500000#);
              else
                tx_sample := f_sample_vector(16#500000#);
              end if;
              toggle_neg := not toggle_neg;
          end case;
        else
          bit_idx := bit_idx + 1;
        end if;
      end if;
      bclk_prev := i2s_bclk;
    end loop;
  end process p_i2s_feed;

  p_stim : process is
    constant C_ZERO10 : std_logic_vector(9 downto 0) := (others => '0');
  begin
    report "tb_audio_input: start";
    wait for 100 ns;

    assert audio_sig = C_ZERO10
      report "reset: audio_sig should be zero"
      severity failure;
    assert audio_t = C_ZERO10
      report "reset: audio_t should be zero"
      severity failure;
    assert audio_b = C_ZERO10
      report "reset: audio_b should be zero"
      severity failure;
    assert i2s_sdout = '0'
      report "i2s_sdout should stay low"
      severity failure;
    report "[PASS] reset defaults";

    rst <= '0';
    wait for 200 ns;

    stim_mode <= STIM_STEADY;
    crossover <= x"20";
    wait_left_bits(80);

    assert unsigned(audio_b) > 32
      report "steady input: bass energy too low (" & integer'image(to_integer(unsigned(audio_b))) & ")"
      severity failure;
    assert unsigned(audio_sig) > 32
      report "steady input: envelope too low (" & integer'image(to_integer(unsigned(audio_sig))) & ")"
      severity failure;
    report "[PASS] steady input drives bass and envelope";

    stim_mode <= STIM_TOGGLE;
    crossover <= x"E0";
    wait_left_bits(120);

    assert unsigned(audio_t) > 8
      report "toggle input: treble energy too low (" & integer'image(to_integer(unsigned(audio_t))) & ")"
      severity failure;
    report "[PASS] alternating input drives treble";

    report "tb_audio_input: all checks passed";
    wait;
  end process p_stim;

end architecture sim;
