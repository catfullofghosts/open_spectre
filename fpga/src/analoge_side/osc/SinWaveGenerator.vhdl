--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|      
-- Create Date: 2023
-- Created by: Rob D Jordan
-- Notes: Sinewave ROM should live somewhere cleaner.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity SinWaveGenerator is
    Port (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        speed : in STD_LOGIC;
        freq : in STD_LOGIC_VECTOR(13 downto 0);
        sync_sel : in STD_LOGIC_VECTOR(1 downto 0);
        sync_plus : in STD_LOGIC;
        sync_minus : in STD_LOGIC;
        dist_level      : in STD_LOGIC_VECTOR(7 downto 0) := (others => '0'); -- distortion wave level
        pwm_duty        : in STD_LOGIC_VECTOR(8 downto 0) := "010110100"; -- PWM duty cycle (0-360, default 180 for 50%)
        wave_sel        : in STD_LOGIC_VECTOR(1 downto 0) := "00"; -- Waveform select: 00=sine, 01=ramp up, 10=ramp down, 11=triangle
        wave_out : out STD_LOGIC_VECTOR(11 downto 0);
        square_out : out STD_LOGIC
    );
end SinWaveGenerator;

architecture Behavioral of SinWaveGenerator is
    signal counter, counterB : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal scaled_freq : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal prescaler, prescalerB : STD_LOGIC_VECTOR(4 downto 0) := (others => '0'); -- Prescaler for speed mode (24x slower)

    signal phase_accumulator,phase_accumulatorB:  integer range 0 to 360;--unsigned(13 downto 0) := (others => '0');  -- Use 12 bits for phase accumulator
    signal rom_address, rom_address_dist : integer range 0 to 360;
    signal sine_table, sine_table_dist,sin_table_xmod : STD_LOGIC_VECTOR(11 downto 0);
    signal sine_table_summed, sine_table_summed_limited : STD_LOGIC_VECTOR(12 downto 0);
    signal square_i : STD_LOGIC := '0';
    signal sync_edge : STD_LOGIC := '0';
    signal sync_in : STD_LOGIC := '0';
    signal dist_freq : STD_LOGIC_VECTOR(15 downto 0) := (others => '1');
    signal pwm_threshold : integer range 0 to 360 := 180; -- PWM threshold for duty cycle control
    
    -- Pipeline registers to break combinatorial paths
    signal freq_reg : std_logic_vector(13 downto 0) := (others => '0');
    signal freq_plus_36 : std_logic_vector(15 downto 0) := (others => '0');
    
    signal atten_val    : unsigned(11 downto 0);
    signal atten_val_d    : unsigned(11 downto 0);
    signal atten_val_inv : unsigned(11 downto 0); -- 4095 - atten_val_d (pipelined)
    
    --
    
    signal attenuated_out   : STD_LOGIC_VECTOR(11 downto 0);
    signal ramp_value : STD_LOGIC_VECTOR(11 downto 0) := (others => '0'); -- Ramp wave output value (up)
    signal ramp_reverse_value : STD_LOGIC_VECTOR(11 downto 0) := (others => '0'); -- Reverse ramp wave output value (down)
    signal triangle_value : STD_LOGIC_VECTOR(11 downto 0) := (others => '0'); -- Triangle wave output value
    signal sine_table_d : STD_LOGIC_VECTOR(11 downto 0) := (others => '0'); -- Pipeline stage to align with atten_val_d
    
    -- Pipeline registers for waveform generation to break combinatorial paths
    signal phase_accumulator_reg : integer range 0 to 360 := 0;
    signal wave_sel_reg : std_logic_vector(1 downto 0) := "00";
    signal wave_sel_reg2 : std_logic_vector(1 downto 0) := "00";
    signal wave_sel_reg3 : std_logic_vector(1 downto 0) := "00";
    signal phase_le_180 : std_logic := '0';
    signal phase_le_180_reg : std_logic := '0';
    signal phase_inverted : integer range 0 to 360 := 0; -- 360 - phase_accumulator_reg
    signal phase_inverted_reg : integer range 0 to 360 := 0;
    -- Single shared multiplier for all waveforms (only compute selected one)
    signal waveform_mult_result : integer range 0 to 737280 := 0; -- 360 * 2047 = 737280
    signal waveform_mult_result_reg : integer range 0 to 737280 := 0;
    -- Pipeline registers for division (using multiplication by reciprocal to avoid long division)
    -- Division by 360: multiply by 182 and shift right 16 bits (182 = 65536/360)
    -- Division by 180: multiply by 364 and shift right 16 bits (364 = 65536/180)
    signal div_multiplier : integer range 0 to 364 := 0;
    signal div_multiplier_reg : integer range 0 to 364 := 0;
    signal waveform_div_mult_result : unsigned(28 downto 0) := (others => '0'); -- 20 bits * 9 bits = 29 bits max
    signal waveform_div_mult_result_reg : unsigned(28 downto 0) := (others => '0');
    signal waveform_div_result : std_logic_vector(11 downto 0) := (others => '0');
    signal waveform_div_result_reg : std_logic_vector(11 downto 0) := (others => '0');

    type ROM is array (0 to 360) of STD_LOGIC_VECTOR(11 downto 0); -- Full 360 degree sine wave (361 entries: 0-360)
    constant sine_rom : ROM := (
"011111111111",
"100001000110",
"100010001101",
"100011010100",
"100100011011",
"100101100010",
"100110101000",
"100111101110",
"101000110011",
"101001110111",
"101010111011",
"101011111101",
"101100111111",
"101110000000",
"101111000000",
"101111111110",
"110000111011",
"110001110111",
"110010110010",
"110011101011",
"110100100010",
"110101011000",
"110110001100",
"110110111111",
"110111110000",
"111000011111",
"111001001100",
"111001110111",
"111010100000",
"111011000110",
"111011101011",
"111100001110",
"111100101110",
"111101001101",
"111101101000",
"111110000010",
"111110011001",
"111110101110",
"111111000001",
"111111010001",
"111111011110",
"111111101010",
"111111110010",
"111111111001",
"111111111100",
"111111111110",
"111111111100",
"111111111001",
"111111110010",
"111111101010",
"111111011110",
"111111010001",
"111111000001",
"111110101110",
"111110011001",
"111110000010",
"111101101000",
"111101001101",
"111100101110",
"111100001110",
"111011101011",
"111011000110",
"111010100000",
"111001110111",
"111001001100",
"111000011111",
"110111110000",
"110110111111",
"110110001100",
"110101011000",
"110100100010",
"110011101011",
"110010110010",
"110001110111",
"110000111011",
"101111111110",
"101111000000",
"101110000000",
"101100111111",
"101011111101",
"101010111011",
"101001110111",
"101000110011",
"100111101110",
"100110101000",
"100101100010",
"100100011011",
"100011010100",
"100010001101",
"100001000110",
"100000000010",
"011110111010",
"011101110011",
"011100101100",
"011011100101",
"011010011110",
"011001011000",
"011000010010",
"010111001101",
"010110001001",
"010101000101",
"010100000011",
"010011000001",
"010010000000",
"010001000000",
"010000000010",
"001111000101",
"001110001001",
"001101001110",
"001100010101",
"001011011110",
"001010101000",
"001001110100",
"001001000001",
"001000010000",
"000111100001",
"000110110100",
"000110001001",
"000101100000",
"000100111010",
"000100010101",
"000011110010",
"000011010010",
"000010110011",
"000010011000",
"000001111110",
"000001100111",
"000001010010",
"000000111111",
"000000101111",
"000000100010",
"000000010110",
"000000001110",
"000000000111",
"000000000100",
"000000000010",
"000000000100",
"000000000111",
"000000001110",
"000000010110",
"000000100010",
"000000101111",
"000000111111",
"000001010010",
"000001100111",
"000001111110",
"000010011000",
"000010110011",
"000011010010",
"000011110010",
"000100010101",
"000100111010",
"000101100000",
"000110001001",
"000110110100",
"000111100001",
"001000010000",
"001001000001",
"001001110100",
"001010101000",
"001011011110",
"001100010101",
"001101001110",
"001110001001",
"001111000101",
"010000000010",
"010001000000",
"010010000000",
"010011000001",
"010100000011",
"010101000101",
"010110001001",
"010111001101",
"011000010010",
"011001011000",
"011010011110",
"011011100101",
"011100101100",
"011101110011",
"011110111010",
"100000000001",
"100000100010",
"100001101010",
"100010110001",
"100011111000",
"100100111111",
"100110000101",
"100111001011",
"101000010000",
"101001010101",
"101010011001",
"101011011100",
"101100011110",
"101101100000",
"101110100000",
"101111011111",
"110000011101",
"110001011001",
"110010010101",
"110011001110",
"110100000111",
"110100111101",
"110101110011",
"110110100110",
"110111011000",
"111000000111",
"111000110101",
"111001100001",
"111010001011",
"111010110011",
"111011011001",
"111011111101",
"111100011110",
"111100111110",
"111101011011",
"111101110110",
"111110001110",
"111110100100",
"111110111000",
"111111001001",
"111111011000",
"111111100100",
"111111101110",
"111111110110",
"111111111011",
"111111111101",
"111111111101",
"111111111011",
"111111110110",
"111111101110",
"111111100100",
"111111011000",
"111111001001",
"111110111000",
"111110100100",
"111110001110",
"111101110110",
"111101011011",
"111100111110",
"111100011110",
"111011111101",
"111011011001",
"111010110011",
"111010001011",
"111001100001",
"111000110101",
"111000000111",
"110111011000",
"110110100110",
"110101110011",
"110100111101",
"110100000111",
"110011001110",
"110010010101",
"110001011001",
"110000011101",
"101111011111",
"101110100000",
"101101100000",
"101100011110",
"101011011100",
"101010011001",
"101001010101",
"101000010000",
"100111001011",
"100110000101",
"100100111111",
"100011111000",
"100010110001",
"100001101010",
"100000100010",
"011111011110",
"011110010110",
"011101001111",
"011100001000",
"011011000001",
"011001111011",
"011000110101",
"010111110000",
"010110101011",
"010101100111",
"010100100100",
"010011100010",
"010010100000",
"010001100000",
"010000100001",
"001111100011",
"001110100111",
"001101101011",
"001100110010",
"001011111001",
"001011000011",
"001010001101",
"001001011010",
"001000101000",
"000111111001",
"000111001011",
"000110011111",
"000101110101",
"000101001101",
"000100100111",
"000100000011",
"000011100010",
"000011000010",
"000010100101",
"000010001010",
"000001110010",
"000001011100",
"000001001000",
"000000110111",
"000000101000",
"000000011100",
"000000010010",
"000000001010",
"000000000101",
"000000000011",
"000000000011",
"000000000101",
"000000001010",
"000000010010",
"000000011100",
"000000101000",
"000000110111",
"000001001000",
"000001011100",
"000001110010",
"000010001010",
"000010100101",
"000011000010",
"000011100010",
"000100000011",
"000100100111",
"000101001101",
"000101110101",
"000110011111",
"000111001011",
"000111111001",
"001000101000",
"001001011010",
"001010001101",
"001011000011",
"001011111001",
"001100110010",
"001101101011",
"001110100111",
"001111100011",
"010000100001",
"010001100000",
"010010100000",
"010011100010",
"010100100100",
"010101100111",
"010110101011",
"010111110000",
"011000110101",
"011001111011",
"011011000001",
"011100001000",
"011101001111",
"011110010110",
"011111011110"
    );

begin

   process(clk)
   begin
   if rising_edge(clk) then
       -- Pipeline stage 1: Register freq input to break combinatorial path
       freq_reg <= freq;
       
       -- Pipeline stage 2: Compute addition using registered freq
       freq_plus_36 <= "00" & std_logic_vector(unsigned(freq_reg) + 36);
       dist_freq <= freq_plus_36;
       
       scaled_freq <= "00" & freq_reg;
       
       -- Convert PWM duty cycle input (0-360) to threshold value
       -- Limit to 360 to match phase accumulator range
       if unsigned(pwm_duty) > 360 then
           pwm_threshold <= 360;
       else
           pwm_threshold <= to_integer(unsigned(pwm_duty));
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
            end if;
        
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
                
                -- Prescaler logic: when speed is on, only increment counters every 24th clock
                if speed = '0' then
                    -- Normal speed: increment every clock
                    counter <= counter + 1;
                    counterB <= counterB + 1;
                else
                    -- Slow speed: use prescaler to increment every 24th clock (24x slower)
                    prescaler <= prescaler + 1;
                    prescalerB <= prescalerB + 1;
                    if prescaler = "10111" then  -- 23 in binary (0-23 = 24 counts)
                        counter <= counter + 1;
                        prescaler <= (others => '0');
                    end if;
                    if prescalerB = "10111" then  -- 23 in binary (0-23 = 24 counts)
                        counterB <= counterB + 1;
                        prescalerB <= (others => '0');
                    end if;
                end if;
                
                -- PWM control: compare phase against PWM threshold for variable duty cycle
                if phase_accumulator > pwm_threshold then
                    square_i <= '1';
                else 
                    square_i <= '0';
                end if; 
                if counter = scaled_freq then
                    counter <= (others => '0');
                    if speed = '1' then
                        prescaler <= (others => '0');
                    end if;
                    if phase_accumulator >= 360 then
                        phase_accumulator <= 0;
                    else
                        if sync_sel = "10" then 
                        phase_accumulator <= phase_accumulator + 8;
                        else
                        phase_accumulator <= phase_accumulator + 1;
                        end if;
                    end if;
                end if;
                if counterB = dist_freq then
                    counterB <= (others => '0');
                    if speed = '1' then
                        prescalerB <= (others => '0');
                    end if;
                    if phase_accumulatorB >= 360 then
                        phase_accumulatorB <= 0;
                    else
                        if sync_sel = "10" then 
                        phase_accumulatorB <= phase_accumulatorB + 8;
                        else
                        phase_accumulatorB <= phase_accumulatorB + 1;
                        end if;
                    end if;
                end if;
                
            end if;
        end if;
    end process;


   
    
process(clk) -- ff the output to lower the logic levels in the acumulator path
  variable ramp_scaled : integer range 0 to 2047;
  variable ramp_reverse_scaled : integer range 0 to 2047;
  variable triangle_scaled : integer range 0 to 2047;
begin
  if rising_edge(clk) then
        -- Pipeline stage 1: Register phase_accumulator and wave_sel to break combinatorial path
        phase_accumulator_reg <= phase_accumulator;
        wave_sel_reg <= wave_sel;
        
        -- ROM lookup (0-360 degrees, 361 entries)
        rom_address <= phase_accumulator;
        -- Distort wave lookup (0-360 degrees, 361 entries)
        rom_address_dist <= phase_accumulatorB;
        -- Create the full sine wave using symmetry
        sine_table <= sine_rom(rom_address);
        -- Create the distortion sinwave
        sine_table_dist <= sine_rom(rom_address_dist); -- needs to have a amplitude control to mix the level
        
        -- Pipeline stage 2: Register comparison result, compute subtraction, and register wave_sel again
        phase_le_180 <= '1' when phase_accumulator_reg <= 180 else '0';
        phase_le_180_reg <= phase_le_180;
        phase_inverted <= 360 - phase_accumulator_reg;
        phase_inverted_reg <= phase_inverted;
        wave_sel_reg2 <= wave_sel_reg;
        
        -- Pipeline stage 3: Compute multiplication only for selected waveform (saves 2 DSPs)
        case wave_sel_reg is
            when "01" =>   -- Ramp up: use phase_accumulator_reg
                waveform_mult_result <= phase_accumulator_reg * 2047;
            when "10" =>   -- Ramp down: use phase_inverted_reg
                waveform_mult_result <= phase_inverted_reg * 2047;
            when "11" =>   -- Triangle: use phase_accumulator_reg or phase_inverted_reg
                if phase_le_180_reg = '1' then
                    waveform_mult_result <= phase_accumulator_reg * 2047;
                else
                    waveform_mult_result <= phase_inverted_reg * 2047;
                end if;
            when others => -- Sine or invalid: don't compute (sine doesn't need this multiplier)
                waveform_mult_result <= 0;
        end case;
        waveform_mult_result_reg <= waveform_mult_result;
        wave_sel_reg3 <= wave_sel_reg2;
        
        -- Pipeline stage 4: Select multiplier for division by reciprocal method
        -- Division by 360: multiply by 182, then shift right 16
        -- Division by 180: multiply by 364, then shift right 16
        case wave_sel_reg2 is
            when "01" =>   -- Ramp up: divide by 360
                div_multiplier <= 182;
            when "10" =>   -- Ramp down: divide by 360
                div_multiplier <= 182;
            when "11" =>   -- Triangle: divide by 180
                div_multiplier <= 364;
            when others => -- Sine: no update needed
                div_multiplier <= 0;
        end case;
        div_multiplier_reg <= div_multiplier;
        
        -- Pipeline stage 5: Multiply by reciprocal (pipelined multiplication)
        waveform_div_mult_result <= to_unsigned(waveform_mult_result_reg, 20) * to_unsigned(div_multiplier_reg, 9);
        waveform_div_mult_result_reg <= waveform_div_mult_result;
        
        -- Pipeline stage 6: Extract bits 27:16 (shift right 16, equivalent to /65536)
        -- This is just bit selection, no division needed!
        waveform_div_result <= std_logic_vector(waveform_div_mult_result_reg(27 downto 16));
        waveform_div_result_reg <= waveform_div_result;
        
        -- Pipeline stage 7: Assign to output signals (already converted in stage 6)
        case wave_sel_reg3 is
            when "01" =>   -- Ramp up
                ramp_value <= waveform_div_result_reg;
            when "10" =>   -- Ramp down
                ramp_reverse_value <= waveform_div_result_reg;
            when "11" =>   -- Triangle
                triangle_value <= waveform_div_result_reg;
            when others => -- Sine: no update needed (uses sin_table_xmod)
                null;
        end case;
        
    end if;
    end process;
    
    
process(clk) -- modulate the sinwave by the attenuated other sinwave
  variable mult_resultA : unsigned(19 downto 0); -- 12+8
  variable mult_resultB : unsigned(23 downto 0); -- 12+8
--  variable atten_val    : unsigned(11 downto 0);
--  variable atten_val_d    : unsigned(11 downto 0);

begin
  if rising_edge(clk) then
    -- Pipeline stage: delay sine_table to align with atten_val_d
    sine_table_d <= sine_table;
    
    -- Step 1: attenuate distortion
    mult_resultA := unsigned(sine_table_dist) * (unsigned(dist_level));  -- 12 x 8
    atten_val <= mult_resultA(19 downto 8);  -- keep 12 bits

    -- Save result
--    attenuated_out <= std_logic_vector(atten_val);
    atten_val_d <= atten_val; 
    
    -- Pipeline stage: Compute subtraction to break combinatorial path before multiplication
    atten_val_inv <= 4095 - atten_val_d;

    -- Step 2: use it to attenuate main sine (using pipelined sine_table_d and atten_val_inv)
    mult_resultB := unsigned(sine_table_d) * atten_val_inv;
    sin_table_xmod <= std_logic_vector(mult_resultB(23 downto 12));
  end if;
end process;
    
--    process(clk) 
--        begin
--        if rising_edge(clk) then
--        sine_table_summed <= ('0'& sine_table) + ('0' & attenuated_out); 

--        if sine_table_summed(12) = '1' then
--            sine_table_summed_limited <= (others => '1');
--         else
--            sine_table_summed_limited <= sine_table_summed;
--         end if;
         
--          end if;
        
--        end process;

    -- Waveform output mux
    process(clk)
    begin
        if rising_edge(clk) then
            case wave_sel is
                when "00" =>   -- Sine wave
                    wave_out <= sin_table_xmod;
                when "01" =>   -- Ramp up
                    wave_out <= ramp_value;
                when "10" =>   -- Ramp down
                    wave_out <= ramp_reverse_value;
                when "11" =>   -- Triangle
                    wave_out <= triangle_value;
                when others =>
                    wave_out <= sin_table_xmod; -- Default to sine
            end case;
        end if;
    end process;
    
    square_out <= square_i;

end Behavioral;
