library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sharpness_effect is
    Port (
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        enable : in STD_LOGIC;
        mode : in STD_LOGIC; -- 0 = blur, 1 = sharpness
        strength : in STD_LOGIC_VECTOR(7 downto 0); -- 0-255 effect strength
        r_in : in STD_LOGIC_VECTOR(7 downto 0);
        g_in : in STD_LOGIC_VECTOR(7 downto 0);
        b_in : in STD_LOGIC_VECTOR(7 downto 0);
        hsync_in : in STD_LOGIC;
        vsync_in : in STD_LOGIC;
        de_in : in STD_LOGIC;
        r_out : out STD_LOGIC_VECTOR(7 downto 0);
        g_out : out STD_LOGIC_VECTOR(7 downto 0);
        b_out : out STD_LOGIC_VECTOR(7 downto 0);
        hsync_out : out STD_LOGIC;
        vsync_out : out STD_LOGIC;
        de_out : out STD_LOGIC
    );
end sharpness_effect;

architecture Behavioral of sharpness_effect is

    -- Horizontal kernels
    -- Sharpening kernel: [-1, 3, -1]
    -- Blur kernel: [1, 2, 1] (normalized to [0.25, 0.5, 0.25])
    constant SHARP_K_LEFT : INTEGER := -1;
    constant SHARP_K_CENTER : INTEGER := 3;
    constant SHARP_K_RIGHT : INTEGER := -1;
    
    constant BLUR_K_LEFT : INTEGER := 1;
    constant BLUR_K_CENTER : INTEGER := 2;
    constant BLUR_K_RIGHT : INTEGER := 1;
    
    -- Pipeline registers for 3-pixel horizontal kernel
    signal pixel_left, pixel_center, pixel_right : STD_LOGIC_VECTOR(23 downto 0);
    
    -- Luminance calculation signals
    signal luminance_left, luminance_center, luminance_right : STD_LOGIC_VECTOR(15 downto 0);
    
    -- Sharpening calculation signals
    signal sharpened_luminance : STD_LOGIC_VECTOR(7 downto 0);
    
    -- Sync signal pipeline (2 clock delay to match processing)
    signal hsync_pipe : STD_LOGIC_VECTOR(1 downto 0);
    signal vsync_pipe : STD_LOGIC_VECTOR(1 downto 0);
    signal de_pipe : STD_LOGIC_VECTOR(1 downto 0);
    
    -- Strength control
    signal strength_unsigned : UNSIGNED(7 downto 0);

begin

    strength_unsigned <= unsigned(strength);


    process(clk)
        variable sharpening_value : SIGNED(31 downto 0);
        variable temp_luminance : UNSIGNED(7 downto 0);
        variable final_luminance : UNSIGNED(7 downto 0);
        variable blended_luminance : UNSIGNED(15 downto 0);
        variable luminance_ratio : UNSIGNED(15 downto 0);
        variable luminance_diff : SIGNED(16 downto 0);
        variable temp_calc : UNSIGNED(15 downto 0);
        variable scaled_ch : UNSIGNED(15 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                pixel_left <= (others => '0');
                pixel_center <= (others => '0');
                pixel_right <= (others => '0');
                luminance_left <= (others => '0');
                luminance_center <= (others => '0');
                luminance_right <= (others => '0');
                hsync_pipe <= (others => '0');
                vsync_pipe <= (others => '0');
                de_pipe <= (others => '0');
                r_out <= (others => '0');
                g_out <= (others => '0');
                b_out <= (others => '0');
                hsync_out <= '0';
                vsync_out <= '0';
                de_out <= '0';
            else
                -- Pipeline sync signals
                hsync_pipe <= hsync_pipe(0) & hsync_in;
                vsync_pipe <= vsync_pipe(0) & vsync_in;
                de_pipe <= de_pipe(0) & de_in;
                
                hsync_out <= hsync_pipe(1);
                vsync_out <= vsync_pipe(1);
                de_out <= de_pipe(1);
                
                -- Shift horizontal pixel pipeline during active video
                if de_in = '1' then
                    pixel_left   <= pixel_center;
                    pixel_center <= pixel_right;
                    pixel_right  <= b_in & g_in & r_in;
                end if;
                
                -- Calculate luminance for each pixel in the pipeline
                if de_pipe(0) = '1' then
                    -- B, G, R packed in pixel vector (matches video_effects bus)
                    temp_calc := (unsigned(pixel_left(23 downto 16)) * 77 + 
                                 unsigned(pixel_left(15 downto 8)) * 150 + 
                                 unsigned(pixel_left(7 downto 0)) * 29) srl 8;
                    luminance_left <= std_logic_vector(temp_calc);
                    
                    temp_calc := (unsigned(pixel_center(23 downto 16)) * 77 + 
                                 unsigned(pixel_center(15 downto 8)) * 150 + 
                                 unsigned(pixel_center(7 downto 0)) * 29) srl 8;
                    luminance_center <= std_logic_vector(temp_calc);
                    
                    temp_calc := (unsigned(pixel_right(23 downto 16)) * 77 + 
                                 unsigned(pixel_right(15 downto 8)) * 150 + 
                                 unsigned(pixel_right(7 downto 0)) * 29) srl 8;
                    luminance_right <= std_logic_vector(temp_calc);
                end if;
                
                if enable = '0' then
                    r_out <= r_in;
                    g_out <= g_in;
                    b_out <= b_in;
                elsif de_pipe(1) = '1' then
                    if mode = '1' then
                        -- Sharpening mode: [-1, 3, -1]
                        sharpening_value := SHARP_K_LEFT * signed("00000000" & luminance_left(7 downto 0)) +
                                           SHARP_K_CENTER * signed("00000000" & luminance_center(7 downto 0)) +
                                           SHARP_K_RIGHT * signed("00000000" & luminance_right(7 downto 0));
                    else
                        -- Blur mode: [1, 2, 1] (divide by 4 for normalization)
                        sharpening_value := (BLUR_K_LEFT * signed("00000000" & luminance_left(7 downto 0)) +
                                            BLUR_K_CENTER * signed("00000000" & luminance_center(7 downto 0)) +
                                            BLUR_K_RIGHT * signed("00000000" & luminance_right(7 downto 0))) / 4;
                    end if;
                    
                    -- Clamp sharpening result to 0-255 range
                    if sharpening_value < 0 then
                        temp_luminance := to_unsigned(0, 8);
                    elsif sharpening_value > 255 then
                        temp_luminance := to_unsigned(255, 8);
                    else
                        temp_luminance := unsigned(sharpening_value(7 downto 0));
                    end if;
                    
                    -- Blend original and sharpened based on strength
                    -- blended = original + (sharpened - original) * strength / 255
                    luminance_diff := signed("0" & temp_luminance) - signed("0" & unsigned(luminance_center));
                    blended_luminance := unsigned(luminance_center(7 downto 0)) + ((unsigned(std_logic_vector(luminance_diff(7 downto 0))) * strength_unsigned) / 255);
                    
                    -- Apply the luminance change proportionally to all RGB channels
                    -- This preserves the original color ratios while applying sharpening
                    if unsigned(luminance_center(7 downto 0)) > 0 then
                        luminance_ratio := (blended_luminance(7 downto 0) * 255) / unsigned(luminance_center(7 downto 0));

                        scaled_ch := (unsigned(pixel_center(7 downto 0)) * luminance_ratio(7 downto 0)) / 255;
                        if scaled_ch > 255 then
                            r_out <= (others => '1');
                        else
                            r_out <= std_logic_vector(scaled_ch(7 downto 0));
                        end if;

                        scaled_ch := (unsigned(pixel_center(15 downto 8)) * luminance_ratio(7 downto 0)) / 255;
                        if scaled_ch > 255 then
                            g_out <= (others => '1');
                        else
                            g_out <= std_logic_vector(scaled_ch(7 downto 0));
                        end if;

                        scaled_ch := (unsigned(pixel_center(23 downto 16)) * luminance_ratio(7 downto 0)) / 255;
                        if scaled_ch > 255 then
                            b_out <= (others => '1');
                        else
                            b_out <= std_logic_vector(scaled_ch(7 downto 0));
                        end if;
                    else
                        r_out <= pixel_center(7 downto 0);
                        g_out <= pixel_center(15 downto 8);
                        b_out <= pixel_center(23 downto 16);
                    end if;
                else
                    r_out <= pixel_center(7 downto 0);
                    g_out <= pixel_center(15 downto 8);
                    b_out <= pixel_center(23 downto 16);
                end if;
            end if;
        end if;
    end process;

end Behavioral;
