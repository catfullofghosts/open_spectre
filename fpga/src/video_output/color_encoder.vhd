library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Colour encoder designed to replicate the kind of unique video colourspace encoder 
-- of the EMS Spectre 
-- Based on code contributed by Andrey Demenev 2025 (https://github.com/ademenev) and
-- Used with his permission

entity color_encoder is
    port (
        clk        : in  std_logic;
        y          : in  std_logic_vector(7 downto 0);  -- Changed from 10:0 to 7:0
        c1         : in  std_logic_vector(7 downto 0);  -- Changed from 10:0 to 7:0
        c2         : in  std_logic_vector(7 downto 0);  -- Changed from 10:0 to 7:0
        swap_early : in  std_logic;
        red        : out std_logic_vector(7 downto 0);
        green      : out std_logic_vector(7 downto 0);
        blue       : out std_logic_vector(7 downto 0)
    );
end entity color_encoder;

architecture rtl of color_encoder is
    constant DELAY : integer := 4;
    
    signal swap : std_logic_vector(DELAY-1 downto 0) := (others => '0');
    
    signal swapped_c1 : std_logic_vector(7 downto 0);
    signal swapped_c2 : std_logic_vector(7 downto 0);
    
    -- Extended to 9-bit signed for overflow detection (was 12-bit for 11-bit input)
    signal c1_ext : signed(8 downto 0);
    signal c2_ext : signed(8 downto 0);
    signal g      : signed(8 downto 0);
    
    signal red_scaled   : std_logic_vector(18 downto 0);
    signal blue_scaled  : std_logic_vector(18 downto 0);
    signal green_scaled : std_logic_vector(18 downto 0);
    signal green_mult_a : std_logic_vector(7 downto 0);  -- Green multiplier input
    
begin
    -- Swap delay pipeline
    swap_pipeline : process(clk)
    begin
        if rising_edge(clk) then
            swap(DELAY-1 downto 0) <= swap(DELAY-2 downto 0) & swap_early;
        end if;
    end process swap_pipeline;
    
    -- Swap c1 and c2 based on delayed swap signal
    swapped_c1 <= c1 when swap(DELAY-1) = '1' else c2;
    swapped_c2 <= c2 when swap(DELAY-1) = '1' else c1;
    
    -- Extend to signed 9-bit for overflow detection
    c1_ext <= signed('0' & swapped_c1);
    c2_ext <= signed('0' & swapped_c2);
    
    -- Calculate green: 255 - c1 - c2 (was 2047 for 11-bit, now 255 for 8-bit)
    g <= to_signed(255, 9) - c1_ext - c2_ext;
    
    -- Green multiplier input: use g[7:0] if positive (g[8] = '0'), else use 0
    green_mult_a <= std_logic_vector(g(7 downto 0)) when g(8) = '0' else (others => '0');
    
    -- Instantiate multipliers
    mult1 : entity work.color_mult
        port map (
            dout   => red_scaled,
            a      => swapped_c1,  -- Changed from swapped_c1[10:3] to full 8 bits
            b      => y,           -- Changed from y[10:3] to full 8 bits
            ce     => '1',
            clk    => clk,
            reset  => '0'
        );
    
    mult2 : entity work.color_mult
        port map (
            dout   => blue_scaled,
            a      => swapped_c2,  -- Changed from swapped_c2[10:3] to full 8 bits
            b      => y,           -- Changed from y[10:3] to full 8 bits
            ce     => '1',
            clk    => clk,
            reset  => '0'
        );
    
    -- Green multiplier input: use g[7:0] if positive, else use 0
    mult3 : entity work.color_mult
        port map (
            dout   => green_scaled,
            a      => green_mult_a,  -- Changed from g[11] check to g[8], and g[10:3] to g[7:0]
            b      => y,             -- Changed from y[10:3] to full 8 bits
            ce     => '1',
            clk    => clk,
            reset  => '0'
        );
    
    -- Output registers
    output_reg : process(clk)
    begin
        if rising_edge(clk) then
            red   <= red_scaled(15 downto 8);
            blue  <= blue_scaled(15 downto 8);
            green <= green_scaled(15 downto 8);
        end if;
    end process output_reg;
    
end architecture rtl;

