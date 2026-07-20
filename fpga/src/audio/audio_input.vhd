library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- I2S audio input (left channel only) for Digilent Pmod I2S2.
-- Generates I2S clocks in slave-drive mode, extracts energy envelopes for
-- analog-matrix modulation: overall (sig), treble (T), bass (B).
--
-- Crossover: 8-bit register sets low-pass shift (higher = brighter bass split).
-- Envelope: G_ENV_SHIFT controls attack/release smoothing (larger = slower).

entity audio_input is
  generic (
    G_OUT_BITS    : positive := 10;
    G_I2S_BITS    : positive := 24;
    G_CLK_HZ      : positive := 100_000_000;
    G_MCLK_HZ     : positive := 12_500_000;
    G_BCLK_HZ     : positive := 6_250_000;  -- ~64*2*48kHz
    G_BITS_PER_CH : positive := 64;
    G_ENV_SHIFT   : natural  := 8
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    crossover  : in  std_logic_vector(7 downto 0);

    -- Pmod I2S2 (drive both converter rows from the same clocks)
    i2s_mclk   : out std_logic;
    i2s_lrck   : out std_logic;
    i2s_bclk   : out std_logic;
    i2s_sdin   : in  std_logic; -- A/D SDOUT
    i2s_sdout  : out std_logic; -- D/A SDIN (unused, held low)

    audio_sig  : out std_logic_vector(G_OUT_BITS - 1 downto 0);
    audio_t    : out std_logic_vector(G_OUT_BITS - 1 downto 0);
    audio_b    : out std_logic_vector(G_OUT_BITS - 1 downto 0)
  );
end entity audio_input;

architecture rtl of audio_input is

  constant C_MCLK_HALF      : natural := (G_CLK_HZ / G_MCLK_HZ) / 2;
  constant C_BCLK_HALF        : natural := (G_CLK_HZ / G_BCLK_HZ) / 2;
  constant C_LP_SHIFT_MIN     : natural := 2;
  constant C_LP_SHIFT_MAX     : natural := 14;

  signal mclk_cnt    : unsigned(15 downto 0) := (others => '0');
  signal bclk_cnt    : unsigned(15 downto 0) := (others => '0');
  signal bclk_cycles : unsigned(6 downto 0) := (others => '0');
  signal mclk_r      : std_logic := '0';
  signal bclk_r      : std_logic := '0';
  signal lrck_r      : std_logic := '0';
  signal bclk_prev   : std_logic := '0';
  signal bclk_fall   : std_logic := '0';

  signal bit_idx    : unsigned(5 downto 0) := (others => '0');
  signal shift_reg  : std_logic_vector(G_I2S_BITS - 1 downto 0) := (others => '0');
  signal sample_v   : std_logic := '0';

  signal sample_s   : signed(G_I2S_BITS - 1 downto 0) := (others => '0');
  signal sample_mag : unsigned(G_OUT_BITS + 13 downto 0) := (others => '0');

  signal lp_state   : signed(G_OUT_BITS + 13 downto 0) := (others => '0');
  signal env_state  : unsigned(G_OUT_BITS + 13 downto 0) := (others => '0');
  signal lp_shift_v : natural range 0 to 15 := 8;

  function f_abs_mag (
    value : signed(G_I2S_BITS - 1 downto 0)
  ) return unsigned is
    variable v : signed(G_I2S_BITS - 1 downto 0);
  begin
    if value < 0 then
      v := -value;
    else
      v := value;
    end if;
    return resize(unsigned(v), sample_mag'length);
  end function f_abs_mag;

  function f_to_out (
    value : unsigned(sample_mag'range)
  ) return std_logic_vector is
    alias v : unsigned(sample_mag'range) is value;
    variable r : std_logic_vector(G_OUT_BITS - 1 downto 0);
  begin
    if v(v'high) = '1' then
      r := (others => '1');
      return r;
    else
      return std_logic_vector(v(v'high downto v'high - (G_OUT_BITS - 1)));
    end if;
  end function f_to_out;

begin

  i2s_sdout <= '0';

  lp_shift_v <= C_LP_SHIFT_MIN
                + (to_integer(unsigned(crossover)) * (C_LP_SHIFT_MAX - C_LP_SHIFT_MIN)) / 255;

  -- ~12.5 MHz MCLK from 100 MHz ref
  p_mclk : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        mclk_cnt <= (others => '0');
        mclk_r   <= '0';
      else
        if mclk_cnt = to_unsigned(C_MCLK_HALF - 1, mclk_cnt'length) then
          mclk_cnt <= (others => '0');
          mclk_r   <= not mclk_r;
        else
          mclk_cnt <= mclk_cnt + 1;
        end if;
      end if;
    end if;
  end process p_mclk;

  i2s_mclk <= mclk_r;

  -- Bit clock (~3.05 MHz) and word clock (~48 kHz left/right)
  p_bclk_lrck : process (clk) is
  begin
    if rising_edge(clk) then
      bclk_prev <= bclk_r;
      if rst = '1' then
        bclk_cnt    <= (others => '0');
        bclk_cycles <= (others => '0');
        bclk_r      <= '0';
        lrck_r      <= '0';
      else
        if bclk_cnt = to_unsigned(C_BCLK_HALF - 1, bclk_cnt'length) then
          bclk_cnt <= (others => '0');
          bclk_r   <= not bclk_r;
          if bclk_r = '1' then
            if bclk_cycles = to_unsigned(G_BITS_PER_CH - 1, bclk_cycles'length) then
              bclk_cycles <= (others => '0');
              lrck_r      <= not lrck_r;
            else
              bclk_cycles <= bclk_cycles + 1;
            end if;
          end if;
        else
          bclk_cnt <= bclk_cnt + 1;
        end if;
      end if;
    end if;
  end process p_bclk_lrck;

  i2s_bclk  <= bclk_r;
  i2s_lrck  <= lrck_r;
  bclk_fall <= '1' when bclk_prev = '1' and bclk_r = '0' else '0';

  -- Left channel only (lrck = '0')
  p_i2s_rx : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        bit_idx   <= (others => '0');
        shift_reg <= (others => '0');
        sample_v  <= '0';
      elsif bclk_fall = '1' and lrck_r = '0' then
        shift_reg <= shift_reg(G_I2S_BITS - 2 downto 0) & i2s_sdin;
        if bit_idx = G_I2S_BITS - 1 then
          bit_idx  <= (others => '0');
          sample_v <= '1';
        else
          bit_idx <= bit_idx + 1;
        end if;
      else
        sample_v <= '0';
      end if;
    end if;
  end process p_i2s_rx;

  p_dsp : process (clk) is
    variable v_mag      : unsigned(sample_mag'range);
    variable v_lp       : signed(lp_state'range);
    variable v_treb     : signed(lp_state'range);
    variable v_env      : unsigned(env_state'range);
    variable v_sample_u : signed(lp_state'range);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sample_s  <= (others => '0');
        lp_state  <= (others => '0');
        env_state <= (others => '0');
        audio_sig <= (others => '0');
        audio_t   <= (others => '0');
        audio_b   <= (others => '0');
      elsif sample_v = '1' then
        sample_s  <= signed(shift_reg);
        sample_mag <= f_abs_mag(signed(shift_reg));

        v_sample_u := signed(shift_reg);

        -- One-pole low-pass (crossover); treble = input - lowpass
        v_lp := lp_state + shift_right(v_sample_u - lp_state, lp_shift_v);
        lp_state <= v_lp;

        v_treb := v_sample_u - v_lp;
        if v_treb < 0 then
          v_mag := unsigned(-v_treb);
        else
          v_mag := unsigned(v_treb);
        end if;
        audio_t <= f_to_out(v_mag);

        if v_lp < 0 then
          v_mag := unsigned(-v_lp);
        else
          v_mag := unsigned(v_lp);
        end if;
        audio_b <= f_to_out(v_mag);

        -- Envelope follower on full-band magnitude
        v_mag := resize(sample_mag, v_mag'length);
        if v_mag >= env_state then
          v_env := env_state + shift_right(v_mag - env_state, G_ENV_SHIFT);
        else
          v_env := env_state - shift_right(env_state - v_mag, G_ENV_SHIFT);
        end if;
        env_state <= v_env;
        audio_sig <= f_to_out(v_env);
      end if;
    end if;
  end process p_dsp;

end architecture rtl;
