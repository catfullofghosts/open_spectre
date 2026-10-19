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
    G_BAND_ENV_SHIFT : natural := 5;  -- T/B envelope (faster response to crossover)
    G_ENV_BITS    : positive := 12;  -- envelope state width (analog matrix uses 12-bit)
    -- |sample| right-shift into G_ENV_BITS; smaller = louder (legacy top-12 was 12)
    G_MAG_SHIFT   : natural  := 8;
    -- Extra left-gain on T/B band mags vs full-scale LP width (saturates)
    G_BAND_GAIN   : natural  := 4
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
    audio_b    : out std_logic_vector(G_OUT_BITS - 1 downto 0);
    -- Instantaneous |sample| magnitude (12-bit), before envelope follower
    audio_mag_pre : out std_logic_vector(G_ENV_BITS - 1 downto 0)
  );
end entity audio_input;

architecture rtl of audio_input is

  constant C_MCLK_HALF      : natural := (G_CLK_HZ / G_MCLK_HZ) / 2;
  constant C_BCLK_HALF      : natural := (G_CLK_HZ / G_BCLK_HZ) / 2;
  constant C_LP_SHIFT_MIN   : natural := 2;
  constant C_LP_SHIFT_MAX   : natural := 14;
  constant C_LP_BITS        : natural := 18;
  constant C_ENV_TO_OUT_SHIFT : natural := G_ENV_BITS - G_OUT_BITS;
  constant C_ENV_MAX        : unsigned(G_ENV_BITS - 1 downto 0) := (others => '1');

  subtype u_env is unsigned(G_ENV_BITS - 1 downto 0);

  type lp_shift_lut_t is array (0 to 255) of unsigned(3 downto 0);

  function f_lp_shift_lut return lp_shift_lut_t is
    variable lut : lp_shift_lut_t;
    variable shift_n : natural;
  begin
    for i in 0 to 255 loop
      shift_n := C_LP_SHIFT_MIN + (i * (C_LP_SHIFT_MAX - C_LP_SHIFT_MIN)) / 255;
      lut(i) := to_unsigned(shift_n, lut(i)'length);
    end loop;
    return lut;
  end function f_lp_shift_lut;

  constant C_LP_SHIFT_LUT : lp_shift_lut_t := f_lp_shift_lut;

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

  signal lp_state      : signed(C_LP_BITS - 1 downto 0) := (others => '0');
  signal env_state     : u_env := (others => '0');
  signal env_b_state   : u_env := (others => '0');
  signal env_t_state   : u_env := (others => '0');
  signal mag_sig_env   : u_env := (others => '0');
  signal mag_b_env     : u_env := (others => '0');
  signal mag_t_env     : u_env := (others => '0');
  signal dsp_pending   : std_logic := '0';
  signal env_clear_d   : std_logic := '0';
  signal lp_shift_r    : unsigned(3 downto 0) := to_unsigned(8, 4);
  signal crossover_r   : std_logic_vector(7 downto 0) := x"80";
  signal crossover_prev : std_logic_vector(7 downto 0) := (others => '0');
  signal diff_r        : signed(C_LP_BITS - 1 downto 0) := (others => '0');
  signal lp_base_r     : signed(C_LP_BITS - 1 downto 0) := (others => '0');
  signal sample_lp_r   : signed(C_LP_BITS - 1 downto 0) := (others => '0');
  signal sample_full_r : signed(G_I2S_BITS - 1 downto 0) := (others => '0');
  signal shift_amt_r   : unsigned(3 downto 0) := (others => '0');
  signal shifted_lo_r  : signed(C_LP_BITS - 1 downto 0) := (others => '0');
  signal lp_s1         : signed(C_LP_BITS - 1 downto 0) := (others => '0');
  signal treb_s1       : signed(C_LP_BITS - 1 downto 0) := (others => '0');
  signal sample_s1     : signed(G_I2S_BITS - 1 downto 0) := (others => '0');
  signal filt_go       : std_logic := '0';
  signal shift_go      : std_logic := '0';
  signal mag_go        : std_logic := '0';
  signal audio_sig_int : std_logic_vector(G_OUT_BITS - 1 downto 0);
  signal audio_t_int   : std_logic_vector(G_OUT_BITS - 1 downto 0);
  signal audio_b_int   : std_logic_vector(G_OUT_BITS - 1 downto 0);
  signal audio_mag_pre_r : std_logic_vector(G_ENV_BITS - 1 downto 0) := (others => '0');

  function f_env_step (
    state   : u_env;
    target  : u_env;
    shift_n : natural
  ) return u_env is
  begin
    if shift_n = 0 then
      return target;
    elsif target >= state then
      return state + shift_right(target - state, shift_n);
    else
      return state - shift_right(state - target, shift_n);
    end if;
  end function f_env_step;

  function f_to_env_mag (
    value : signed(G_I2S_BITS - 1 downto 0)
  ) return u_env is
    variable v : signed(G_I2S_BITS - 1 downto 0);
    variable u : unsigned(G_I2S_BITS - 1 downto 0);
    variable shifted : unsigned(G_I2S_BITS - 1 downto 0);
  begin
    if value < 0 then
      v := -value;
    else
      v := value;
    end if;
    u := unsigned(v);
    if G_MAG_SHIFT >= G_I2S_BITS then
      return (others => '0');
    end if;
    -- Saturate if any bit above the kept window is set
    if G_I2S_BITS > G_MAG_SHIFT + G_ENV_BITS then
      if shift_right(u, G_MAG_SHIFT + G_ENV_BITS) /= 0 then
        return C_ENV_MAX;
      end if;
    end if;
    shifted := shift_right(u, G_MAG_SHIFT);
    return resize(shifted, G_ENV_BITS);
  end function f_to_env_mag;

  function f_signed_to_env_mag (
    value : signed
  ) return u_env is
    variable u : unsigned(value'length - 1 downto 0);
    variable drop : integer;
    variable shift_n : natural;
  begin
    if value < 0 then
      u := unsigned(-value);
    else
      u := unsigned(value);
    end if;
    drop := value'length - G_ENV_BITS - G_BAND_GAIN;
    if drop < 0 then
      shift_n := 0;
    else
      shift_n := drop;
    end if;
    if shift_n > 0 and value'length > shift_n + G_ENV_BITS then
      if shift_right(u, shift_n + G_ENV_BITS) /= 0 then
        return C_ENV_MAX;
      end if;
    end if;
    if shift_n > 0 then
      return resize(shift_right(u, shift_n), G_ENV_BITS);
    else
      return resize(u, G_ENV_BITS);
    end if;
  end function f_signed_to_env_mag;

  function f_to_out (
    value : u_env
  ) return std_logic_vector is
  begin
    if C_ENV_TO_OUT_SHIFT > 0 then
      return std_logic_vector(
        resize(shift_right(value, C_ENV_TO_OUT_SHIFT), G_OUT_BITS)
      );
    else
      return std_logic_vector(resize(value, G_OUT_BITS));
    end if;
  end function f_to_out;

  function f_sample_to_lp (
    value : signed(G_I2S_BITS - 1 downto 0)
  ) return signed is
    constant C_SHIFT : natural := G_I2S_BITS - C_LP_BITS;
  begin
    return resize(shift_right(value, C_SHIFT), C_LP_BITS);
  end function f_sample_to_lp;

  -- Literal shifts are wiring. A variable shift_right by 0..15 is a barrel
  -- that, chained with the magnitude scale, missed 100 MHz.
  function f_shift_lo (
    value : signed(C_LP_BITS - 1 downto 0);
    sel   : unsigned(1 downto 0)
  ) return signed is
  begin
    case sel is
      when "00"   => return value;
      when "01"   => return shift_right(value, 1);
      when "10"   => return shift_right(value, 2);
      when others => return shift_right(value, 3);
    end case;
  end function f_shift_lo;

  function f_shift_hi (
    value : signed(C_LP_BITS - 1 downto 0);
    sel   : unsigned(1 downto 0)
  ) return signed is
  begin
    case sel is
      when "00"   => return value;
      when "01"   => return shift_right(value, 4);
      when "10"   => return shift_right(value, 8);
      when others => return shift_right(value, 12);
    end case;
  end function f_shift_hi;

begin

  i2s_sdout <= '0';

  p_crossover_r : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        crossover_r <= x"80";
      else
        crossover_r <= crossover;
      end if;
    end if;
  end process p_crossover_r;

  p_lp_shift : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        lp_shift_r <= C_LP_SHIFT_LUT(128);
      else
        lp_shift_r <= C_LP_SHIFT_LUT(to_integer(unsigned(crossover_r)));
      end if;
    end if;
  end process p_lp_shift;

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

  -- Low-pass split across three clocks, then magnitude on a fourth.
  -- Samples are ~48 kHz, so the extra cycles do not change the envelopes.
  -- filt_go -> shift_go -> mag_go keeps env_clear_d asserted until the
  -- matching envelope step, including a crossover that lands on a sample.
  p_dsp_filter : process (clk) is
    variable v_lp_base  : signed(C_LP_BITS - 1 downto 0);
    variable v_sample_u : signed(C_LP_BITS - 1 downto 0);
    variable v_lp       : signed(C_LP_BITS - 1 downto 0);
    variable v_xover    : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        lp_state       <= (others => '0');
        crossover_prev <= crossover_r;
        env_clear_d    <= '0';
        diff_r         <= (others => '0');
        lp_base_r      <= (others => '0');
        sample_lp_r    <= (others => '0');
        sample_full_r  <= (others => '0');
        shift_amt_r    <= (others => '0');
        shifted_lo_r   <= (others => '0');
        lp_s1          <= (others => '0');
        treb_s1        <= (others => '0');
        sample_s1      <= (others => '0');
        filt_go        <= '0';
        shift_go       <= '0';
        mag_go         <= '0';
      else
        shift_go <= filt_go;
        mag_go   <= shift_go;
        filt_go  <= '0';

        v_xover := crossover_r /= crossover_prev;

        if v_xover then
          env_clear_d <= '1';
          crossover_prev <= crossover_r;
          if sample_v = '0' then
            lp_state <= (others => '0');
          end if;
        elsif env_clear_d = '1' and
              (dsp_pending = '1' or
               (sample_v = '0' and filt_go = '0' and shift_go = '0' and mag_go = '0')) then
          env_clear_d <= '0';
        end if;

        if sample_v = '1' then
          if v_xover then
            v_lp_base := (others => '0');
          else
            v_lp_base := lp_state;
          end if;

          v_sample_u    := f_sample_to_lp(signed(shift_reg));
          diff_r        <= v_sample_u - v_lp_base;
          lp_base_r     <= v_lp_base;
          sample_lp_r   <= v_sample_u;
          sample_full_r <= signed(shift_reg);
          shift_amt_r   <= lp_shift_r;
          filt_go       <= '1';
        end if;

        if filt_go = '1' then
          shifted_lo_r <= f_shift_lo(diff_r, shift_amt_r(1 downto 0));
        end if;

        if shift_go = '1' then
          v_lp      := lp_base_r + f_shift_hi(shifted_lo_r, shift_amt_r(3 downto 2));
          lp_state  <= v_lp;
          lp_s1     <= v_lp;
          treb_s1   <= sample_lp_r - v_lp;
          sample_s1 <= sample_full_r;
        end if;
      end if;
    end if;
  end process p_dsp_filter;

  p_dsp_mag : process (clk) is
  begin
    if rising_edge(clk) then
      if rst = '1' then
        dsp_pending     <= '0';
        mag_sig_env     <= (others => '0');
        mag_t_env       <= (others => '0');
        mag_b_env       <= (others => '0');
        audio_mag_pre_r <= (others => '0');
      else
        dsp_pending <= mag_go;
        if mag_go = '1' then
          audio_mag_pre_r <= std_logic_vector(mag_sig_env);
          mag_sig_env     <= f_to_env_mag(sample_s1);
          mag_t_env       <= f_signed_to_env_mag(treb_s1);
          mag_b_env       <= f_signed_to_env_mag(lp_s1);
        end if;
      end if;
    end if;
  end process p_dsp_mag;

  -- Stage 2: 12-bit envelope followers (short carry chains)
  p_dsp_env : process (clk) is
    variable v_env   : u_env;
    variable v_env_b : u_env;
    variable v_env_t : u_env;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        env_state   <= (others => '0');
        env_b_state <= (others => '0');
        env_t_state <= (others => '0');
        audio_sig_int <= (others => '0');
        audio_t_int   <= (others => '0');
        audio_b_int   <= (others => '0');
      else
        if env_clear_d = '1' and dsp_pending = '0' then
          env_b_state <= (others => '0');
          env_t_state <= (others => '0');
          audio_t_int   <= (others => '0');
          audio_b_int   <= (others => '0');
        end if;

        if dsp_pending = '1' then
          if env_clear_d = '1' then
            v_env_t := (others => '0');
            v_env_b := (others => '0');
          else
            v_env_t := env_t_state;
            v_env_b := env_b_state;
          end if;

          v_env_t := f_env_step(v_env_t, mag_t_env, G_BAND_ENV_SHIFT);
          env_t_state <= v_env_t;
          audio_t_int <= f_to_out(v_env_t);

          v_env_b := f_env_step(v_env_b, mag_b_env, G_BAND_ENV_SHIFT);
          env_b_state <= v_env_b;
          audio_b_int <= f_to_out(v_env_b);

          v_env := f_env_step(env_state, mag_sig_env, G_ENV_SHIFT);
          env_state <= v_env;
          audio_sig_int <= f_to_out(v_env);
        end if;
      end if;
    end if;
  end process p_dsp_env;

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

  audio_mag_pre <= audio_mag_pre_r;

end architecture rtl;
