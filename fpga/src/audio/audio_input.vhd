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
    G_ENV_SHIFT   : natural  := 8;  -- overall envelope smoothing
    G_BAND_ENV_SHIFT : natural := 5  -- T/B envelope (faster response to crossover)
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
  constant C_MAG_BITS         : natural := G_OUT_BITS + 14;
  constant C_OUT_SHIFT        : natural := C_MAG_BITS - G_OUT_BITS;

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
  signal lrck_prev  : std_logic := '0';
  signal lrck_rise  : std_logic;
  signal lrck_fall  : std_logic;
  signal cap_left   : std_logic := '1';

  signal sample_s   : signed(G_I2S_BITS - 1 downto 0) := (others => '0');
  signal sample_mag : unsigned(G_OUT_BITS + 13 downto 0) := (others => '0');

  signal lp_state   : signed(G_OUT_BITS + 13 downto 0) := (others => '0');
  signal env_state  : unsigned(G_OUT_BITS + 13 downto 0) := (others => '0');
  signal env_b_state : unsigned(G_OUT_BITS + 13 downto 0) := (others => '0');
  signal env_t_state : unsigned(G_OUT_BITS + 13 downto 0) := (others => '0');
  signal lp_shift_v : natural range 0 to 15 := 8;
  signal crossover_r      : std_logic_vector(7 downto 0) := x"80";
  signal crossover_prev     : std_logic_vector(7 downto 0) := (others => '0');
  signal audio_sig_int      : std_logic_vector(G_OUT_BITS - 1 downto 0);
  signal audio_t_int        : std_logic_vector(G_OUT_BITS - 1 downto 0);
  signal audio_b_int        : std_logic_vector(G_OUT_BITS - 1 downto 0);

  function f_env_step (
    state   : unsigned;
    target  : unsigned;
    shift_n : natural
  ) return unsigned is
    alias s : unsigned(state'range) is state;
    alias t : unsigned(target'range) is target;
  begin
    if shift_n = 0 then
      return t;
    elsif t >= s then
      return s + shift_right(t - s, shift_n);
    else
      return s - shift_right(s - t, shift_n);
    end if;
  end function f_env_step;

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
    value : unsigned
  ) return std_logic_vector is
    variable v : unsigned(C_MAG_BITS - 1 downto 0);
  begin
    v := resize(value, C_MAG_BITS);
    return std_logic_vector(
      resize(shift_right(v, C_OUT_SHIFT), G_OUT_BITS)
    );
  end function f_to_out;

begin

  i2s_sdout <= '0';

  p_crossover_in : process (clk) is
    variable v_shift : natural range 0 to 15;
  begin
    if rising_edge(clk) then
      crossover_r <= crossover;
      v_shift := C_LP_SHIFT_MIN
                 + (to_integer(unsigned(crossover)) * (C_LP_SHIFT_MAX - C_LP_SHIFT_MIN)) / 255;
      lp_shift_v <= v_shift;
    end if;
  end process p_crossover_in;

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
  lrck_rise <= '1' when lrck_prev = '0' and lrck_r = '1' else '0';
  lrck_fall <= '1' when lrck_prev = '1' and lrck_r = '0' else '0';

  -- Left channel only: one G_I2S_BITS word per LRCK low phase; ignore right phase
  p_i2s_rx : process (clk) is
  begin
    if rising_edge(clk) then
      lrck_prev <= lrck_r;
      if rst = '1' then
        bit_idx   <= (others => '0');
        shift_reg <= (others => '0');
        sample_v  <= '0';
        cap_left  <= '1';
      elsif lrck_rise = '1' then
        cap_left  <= '0';
        bit_idx   <= (others => '0');
        shift_reg <= (others => '0');
        sample_v  <= '0';
      elsif lrck_fall = '1' then
        cap_left  <= '1';
        bit_idx   <= (others => '0');
        shift_reg <= (others => '0');
        sample_v  <= '0';
      elsif cap_left = '1' and bclk_fall = '1' and lrck_r = '0' then
        shift_reg <= shift_reg(G_I2S_BITS - 2 downto 0) & i2s_sdin;
        if bit_idx = to_unsigned(G_I2S_BITS - 1, bit_idx'length) then
          bit_idx  <= (others => '0');
          cap_left <= '0';
          sample_v <= '1';
        else
          bit_idx  <= bit_idx + 1;
          sample_v <= '0';
        end if;
      else
        sample_v <= '0';
      end if;
    end if;
  end process p_i2s_rx;

  p_dsp : process (clk) is
    variable v_mag      : unsigned(env_state'range);
    variable v_lp       : signed(lp_state'range);
    variable v_treb     : signed(lp_state'range);
    variable v_env      : unsigned(env_state'range);
    variable v_env_b    : unsigned(env_b_state'range);
    variable v_env_t    : unsigned(env_t_state'range);
    variable v_sample_u : signed(lp_state'range);
    variable v_xover    : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sample_s       <= (others => '0');
        lp_state       <= (others => '0');
        env_state      <= (others => '0');
        env_b_state    <= (others => '0');
        env_t_state    <= (others => '0');
        crossover_prev <= crossover_r;
        audio_sig_int  <= (others => '0');
        audio_t_int    <= (others => '0');
        audio_b_int    <= (others => '0');
      else
        v_xover := crossover_r /= crossover_prev;

        if v_xover and sample_v = '0' then
          lp_state       <= (others => '0');
          env_b_state    <= (others => '0');
          env_t_state    <= (others => '0');
          crossover_prev <= crossover_r;
          audio_t_int    <= (others => '0');
          audio_b_int    <= (others => '0');
        elsif sample_v = '1' then
          if v_xover then
            crossover_prev <= crossover_r;
            v_lp    := (others => '0');
            v_env_b := (others => '0');
            v_env_t := (others => '0');
          else
            v_lp    := lp_state;
            v_env_b := env_b_state;
            v_env_t := env_t_state;
          end if;

          sample_s   <= signed(shift_reg);
          sample_mag <= f_abs_mag(signed(shift_reg));
          v_sample_u := signed(shift_reg);

          v_lp := v_lp + shift_right(v_sample_u - v_lp, lp_shift_v);
          lp_state <= v_lp;

          v_treb := v_sample_u - v_lp;
          if v_treb < 0 then
            v_mag := unsigned(-v_treb);
          else
            v_mag := unsigned(v_treb);
          end if;
          v_env_t := f_env_step(v_env_t, v_mag, G_BAND_ENV_SHIFT);
          env_t_state <= v_env_t;
          audio_t_int     <= f_to_out(v_env_t);

          if v_lp < 0 then
            v_mag := unsigned(-v_lp);
          else
            v_mag := unsigned(v_lp);
          end if;
          v_env_b := f_env_step(v_env_b, v_mag, G_BAND_ENV_SHIFT);
          env_b_state <= v_env_b;
          audio_b_int     <= f_to_out(v_env_b);

          v_mag := resize(sample_mag, v_mag'length);
          v_env := f_env_step(env_state, v_mag, G_ENV_SHIFT);
          env_state <= v_env;
          audio_sig_int <= f_to_out(v_env);
        end if;
      end if;
    end if;
  end process p_dsp;

  p_audio_out : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        audio_sig <= (others => '0');
        audio_t   <= (others => '0');
        audio_b   <= (others => '0');
      else
        audio_sig <= audio_sig_int;
        audio_t   <= audio_t_int;
        audio_b   <= audio_b_int;
      end if;
    end if;
  end process p_audio_out;

end architecture rtl;
