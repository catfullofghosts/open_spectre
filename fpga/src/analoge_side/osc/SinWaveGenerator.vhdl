--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
-- Create Date: 2023
-- Created by: Rob D Jordan
-- Notes: 12-bit phase (4096 steps); sine ROM in sine_rom_pkg.vhd (regenerate via scripts/make_sinwave_table.py).

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use work.sine_rom_pkg.all;

entity SinWaveGenerator is
    Port (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        speed : in STD_LOGIC;
        freq : in STD_LOGIC_VECTOR(13 downto 0);
        sync_sel : in STD_LOGIC_VECTOR(1 downto 0);
        sync_plus : in STD_LOGIC;
        sync_minus : in STD_LOGIC;
        dist_level      : in STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
        pwm_duty        : in STD_LOGIC_VECTOR(8 downto 0) := "010110100"; -- 0-360 degrees, default 180 = 50%
        wave_sel        : in STD_LOGIC_VECTOR(1 downto 0) := "00";
        wave_out : out STD_LOGIC_VECTOR(11 downto 0);
        square_out : out STD_LOGIC
    );
end SinWaveGenerator;

architecture Behavioral of SinWaveGenerator is
    constant C_DIV_FULL : natural := 65536 / C_SINE_PHASE_FULL;  -- 16
    constant C_DIV_HALF : natural := 65536 / C_SINE_PHASE_HALF;  -- 32

    signal counter, counterB : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal scaled_freq : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal prescaler, prescalerB : STD_LOGIC_VECTOR(4 downto 0) := (others => '0');

    signal phase_accumulator, phase_accumulatorB : integer range 0 to C_SINE_PHASE_MAX := 0;
    signal rom_address, rom_address_dist : integer range 0 to C_SINE_PHASE_MAX;
    signal sine_table, sine_table_dist, wave_table_xmod : STD_LOGIC_VECTOR(11 downto 0);
    signal square_i : STD_LOGIC := '0';
    signal sync_edge : STD_LOGIC := '0';
    signal sync_in : STD_LOGIC := '0';
    signal speed_eff : STD_LOGIC := '0';
    signal dist_freq : STD_LOGIC_VECTOR(15 downto 0) := (others => '1');
    signal pwm_threshold : integer range 0 to C_SINE_PHASE_MAX := C_SINE_PHASE_HALF;

    signal freq_reg : std_logic_vector(13 downto 0) := (others => '0');
    signal freq_plus_36 : std_logic_vector(15 downto 0) := (others => '0');
    signal sync_sel_reg : std_logic_vector(1 downto 0) := "00";
    signal phase_inc_reg : integer range 0 to C_SINE_PHASE_MAX := 1;

    signal atten_val    : unsigned(11 downto 0);
    signal atten_val_d    : unsigned(11 downto 0);
    signal atten_val_inv : unsigned(11 downto 0);

    signal ramp_value : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal ramp_reverse_value : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal triangle_value : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal sine_table_d : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');

    signal phase_accumulator_reg : integer range 0 to C_SINE_PHASE_MAX := 0;
    signal wave_sel_reg : std_logic_vector(1 downto 0) := "00";
    signal wave_sel_reg2 : std_logic_vector(1 downto 0) := "00";
    signal wave_sel_reg3 : std_logic_vector(1 downto 0) := "00";
    signal phase_le_half : std_logic := '0';
    signal phase_le_half_reg : std_logic := '0';
    signal phase_inverted : integer range 0 to C_SINE_PHASE_MAX := 0;
    signal phase_inverted_reg : integer range 0 to C_SINE_PHASE_MAX := 0;
    signal waveform_mult_result : integer range 0 to 8382465 := 0;
    signal waveform_mult_result_reg : integer range 0 to 8382465 := 0;
    signal div_multiplier : integer range 0 to 63 := 0;
    signal div_multiplier_reg : integer range 0 to 63 := 0;
    signal waveform_div_mult_result : unsigned(28 downto 0) := (others => '0');
    signal waveform_div_mult_result_reg : unsigned(28 downto 0) := (others => '0');
    signal waveform_div_result : std_logic_vector(11 downto 0) := (others => '0');
    signal waveform_div_result_reg : std_logic_vector(11 downto 0) := (others => '0');

begin

   process(clk)
     variable v_phase_inc : integer range 0 to C_SINE_PHASE_MAX;
   begin
   if rising_edge(clk) then
       freq_reg <= freq;
       sync_sel_reg <= sync_sel;
       freq_plus_36 <= "00" & std_logic_vector(unsigned(freq_reg) + 36);
       dist_freq <= freq_plus_36;
       scaled_freq <= "00" & freq_reg;

       v_phase_inc := ((64 - to_integer(unsigned(freq_reg(5 downto 0))))
                       * C_SINE_PHASE_FULL) / 360;
       if v_phase_inc < 1 then
         phase_inc_reg <= 1;
       else
         phase_inc_reg <= v_phase_inc;
       end if;

       -- Map legacy 0-360 duty register into 12-bit phase
       if unsigned(pwm_duty) > 360 then
           pwm_threshold <= C_SINE_PHASE_MAX;
       else
           pwm_threshold <= (to_integer(unsigned(pwm_duty)) * C_SINE_PHASE_FULL) / 360;
       end if;
      end if;
    end process;


    process(clk, reset, sync_in)
    begin
        if reset = '1' then
            counter <= (others => '0');
            counterB <= (others => '0');
            prescaler <= (others => '0');
            prescalerB <= (others => '0');
            phase_accumulator <= 0;
            phase_accumulatorB <= 0;
            sync_edge <= '0';
        elsif rising_edge(clk) then

            if sync_sel = "00" then
                sync_in <= '0';
            elsif sync_sel = "01" then
                sync_in <= sync_plus;
            elsif sync_sel = "10" then
                sync_in <= sync_minus;
            else
                sync_in <= '0';
            end if;

            speed_eff <= '0' when sync_sel_reg = "10" else speed;

            if sync_in = '1' and sync_edge = '0' then
                sync_edge <= '1';
                counter <= (others => '0');
                counterB <= (others => '0');
                prescaler <= (others => '0');
                prescalerB <= (others => '0');
                phase_accumulator <= 0;
                phase_accumulatorB <= 0;
            else
                sync_edge <= sync_in;

                if speed_eff = '0' then
                    counter  <= std_logic_vector(unsigned(counter) + 1);
                    counterB <= std_logic_vector(unsigned(counterB) + 1);
                else
                    prescaler  <= std_logic_vector(unsigned(prescaler) + 1);
                    prescalerB <= std_logic_vector(unsigned(prescalerB) + 1);
                    if prescaler = "10001" then
                        counter <= std_logic_vector(unsigned(counter) + 1);
                        prescaler <= (others => '0');
                    end if;
                    if prescalerB = "10001" then
                        counterB <= std_logic_vector(unsigned(counterB) + 1);
                        prescalerB <= (others => '0');
                    end if;
                end if;

                if phase_accumulator > pwm_threshold then
                    square_i <= '1';
                else
                    square_i <= '0';
                end if;

                if counter = scaled_freq then
                    counter <= (others => '0');
                    if speed_eff = '1' then
                        prescaler <= (others => '0');
                    end if;
                    if phase_accumulator >= C_SINE_PHASE_MAX then
                        phase_accumulator <= 0;
                    elsif sync_sel_reg = "10" then
                        phase_accumulator <= phase_accumulator + phase_inc_reg;
                    else
                        phase_accumulator <= phase_accumulator + 1;
                    end if;
                end if;

                if counterB = dist_freq then
                    counterB <= (others => '0');
                    if speed_eff = '1' then
                        prescalerB <= (others => '0');
                    end if;
                    if phase_accumulatorB >= C_SINE_PHASE_MAX then
                        phase_accumulatorB <= 0;
                    elsif sync_sel_reg = "10" then
                        phase_accumulatorB <= phase_accumulatorB + phase_inc_reg;
                    else
                        phase_accumulatorB <= phase_accumulatorB + 1;
                    end if;
                end if;

            end if;
        end if;
    end process;


process(clk)
begin
  if rising_edge(clk) then
        phase_accumulator_reg <= phase_accumulator;
        wave_sel_reg <= wave_sel;

        rom_address <= phase_accumulator;
        rom_address_dist <= phase_accumulatorB;
        sine_table <= C_SINE_ROM(rom_address);
        sine_table_dist <= C_SINE_ROM(rom_address_dist);

        phase_le_half <= '1' when phase_accumulator_reg <= C_SINE_PHASE_HALF else '0';
        phase_le_half_reg <= phase_le_half;
        phase_inverted <= C_SINE_PHASE_MAX - phase_accumulator_reg;
        phase_inverted_reg <= phase_inverted;
        wave_sel_reg2 <= wave_sel_reg;

        case wave_sel_reg is
            when "01" =>
                waveform_mult_result <= phase_accumulator_reg * 2047;
            when "10" =>
                waveform_mult_result <= phase_inverted_reg * 2047;
            when "11" =>
                if phase_le_half_reg = '1' then
                    waveform_mult_result <= phase_accumulator_reg * 2047;
                else
                    waveform_mult_result <= phase_inverted_reg * 2047;
                end if;
            when others =>
                waveform_mult_result <= 0;
        end case;
        waveform_mult_result_reg <= waveform_mult_result;
        wave_sel_reg3 <= wave_sel_reg2;

        case wave_sel_reg2 is
            when "01" =>
                div_multiplier <= C_DIV_FULL;
            when "10" =>
                div_multiplier <= C_DIV_FULL;
            when "11" =>
                div_multiplier <= C_DIV_HALF;
            when others =>
                div_multiplier <= 0;
        end case;
        div_multiplier_reg <= div_multiplier;

        waveform_div_mult_result <= to_unsigned(waveform_mult_result_reg, 23)
                                    * to_unsigned(div_multiplier_reg, 6);
        waveform_div_mult_result_reg <= waveform_div_mult_result;

        waveform_div_result <= std_logic_vector(waveform_div_mult_result_reg(27 downto 16));
        waveform_div_result_reg <= waveform_div_result;

        case wave_sel_reg3 is
            when "01" =>
                ramp_value <= waveform_div_result_reg;
            when "10" =>
                ramp_reverse_value <= waveform_div_result_reg;
            when "11" =>
                triangle_value <= waveform_div_result_reg;
            when others =>
                null;
        end case;

    end if;
    end process;


process(clk)
  variable mult_resultA : unsigned(19 downto 0);
  variable mult_resultB : unsigned(23 downto 0);
begin
  if rising_edge(clk) then
    sine_table_d <= sine_table;

    mult_resultA := unsigned(sine_table_dist) * (unsigned(dist_level));
    atten_val <= mult_resultA(19 downto 8);
    atten_val_d <= atten_val;
    atten_val_inv <= 4095 - atten_val_d;

    case wave_sel is
                when "00" =>
                    mult_resultB := unsigned(sine_table_d) * atten_val_inv;
                when "01" =>
                    mult_resultB := unsigned(ramp_value) * atten_val_inv;
                when "10" =>
                    mult_resultB := unsigned(ramp_reverse_value) * atten_val_inv;
                when "11" =>
                    mult_resultB := unsigned(triangle_value) * atten_val_inv;
                when others =>
                    mult_resultB := unsigned(sine_table_d) * atten_val_inv;
            end case;
    wave_table_xmod <= std_logic_vector(mult_resultB(23 downto 12));
    wave_out <= wave_table_xmod;
  end if;
end process;

    square_out <= square_i;

end Behavioral;
