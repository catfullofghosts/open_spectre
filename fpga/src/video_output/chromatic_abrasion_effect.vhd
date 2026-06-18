library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity chromatic_abrasion_effect is
    Port (
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        enable : in STD_LOGIC;
        delay_g : in STD_LOGIC_VECTOR(2 downto 0); -- 0-5 clock cycles for green
        delay_b : in STD_LOGIC_VECTOR(2 downto 0); -- 0-5 clock cycles for blue
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
end chromatic_abrasion_effect;

architecture Behavioral of chromatic_abrasion_effect is

    -- Delay line types for green and blue channels
    type delay_line_g is array (0 to 5) of STD_LOGIC_VECTOR(7 downto 0);
    type delay_line_b is array (0 to 5) of STD_LOGIC_VECTOR(7 downto 0);
    type sync_delay_line is array (0 to 5) of STD_LOGIC;
    
    -- Delay line signals
    signal g_delay_line : delay_line_g;
    signal b_delay_line : delay_line_b;
    signal hsync_delay_line : sync_delay_line;
    signal vsync_delay_line : sync_delay_line;
    signal de_delay_line : sync_delay_line;
    
    -- Delay control signals
    signal delay_g_unsigned : UNSIGNED(2 downto 0);
    signal delay_b_unsigned : UNSIGNED(2 downto 0);
    
    -- Output signals
    signal g_delayed, b_delayed : STD_LOGIC_VECTOR(7 downto 0);
    signal hsync_delayed, vsync_delayed, de_delayed : STD_LOGIC;

begin

    delay_g_unsigned <= unsigned(delay_g);
    delay_b_unsigned <= unsigned(delay_b);

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- Reset all delay lines
                for i in 0 to 5 loop
                    g_delay_line(i) <= (others => '0');
                    b_delay_line(i) <= (others => '0');
                    hsync_delay_line(i) <= '0';
                    vsync_delay_line(i) <= '0';
                    de_delay_line(i) <= '0';
                end loop;
                
                r_out <= (others => '0');
                g_out <= (others => '0');
                b_out <= (others => '0');
                hsync_out <= '0';
                vsync_out <= '0';
                de_out <= '0';
            else
                -- Shift delay lines
                for i in 5 downto 1 loop
                    g_delay_line(i) <= g_delay_line(i-1);
                    b_delay_line(i) <= b_delay_line(i-1);
                    hsync_delay_line(i) <= hsync_delay_line(i-1);
                    vsync_delay_line(i) <= vsync_delay_line(i-1);
                    de_delay_line(i) <= de_delay_line(i-1);
                end loop;
                
                -- Input to delay lines
                g_delay_line(0) <= g_in;
                b_delay_line(0) <= b_in;
                hsync_delay_line(0) <= hsync_in;
                vsync_delay_line(0) <= vsync_in;
                de_delay_line(0) <= de_in;
                
                -- Select delayed outputs based on delay settings (0-5 pixel clocks)
                case delay_g_unsigned is
                    when "000" => g_delayed <= g_in;
                    when "001" => g_delayed <= g_delay_line(0);
                    when "010" => g_delayed <= g_delay_line(1);
                    when "011" => g_delayed <= g_delay_line(2);
                    when "100" => g_delayed <= g_delay_line(3);
                    when "101" => g_delayed <= g_delay_line(4);
                    when others => g_delayed <= g_delay_line(5);
                end case;
                
                case delay_b_unsigned is
                    when "000" => b_delayed <= b_in;
                    when "001" => b_delayed <= b_delay_line(0);
                    when "010" => b_delayed <= b_delay_line(1);
                    when "011" => b_delayed <= b_delay_line(2);
                    when "100" => b_delayed <= b_delay_line(3);
                    when "101" => b_delayed <= b_delay_line(4);
                    when others => b_delayed <= b_delay_line(5);
                end case;
                
                -- For sync signals, use the maximum delay to maintain alignment
                -- This ensures all channels are properly synchronized
                if delay_g_unsigned > delay_b_unsigned then
                    case delay_g_unsigned is
                        when "000" => 
                            hsync_delayed <= hsync_in;
                            vsync_delayed <= vsync_in;
                            de_delayed <= de_in;
                        when "001" => 
                            hsync_delayed <= hsync_delay_line(0);
                            vsync_delayed <= vsync_delay_line(0);
                            de_delayed <= de_delay_line(0);
                        when "010" => 
                            hsync_delayed <= hsync_delay_line(1);
                            vsync_delayed <= vsync_delay_line(1);
                            de_delayed <= de_delay_line(1);
                        when "011" => 
                            hsync_delayed <= hsync_delay_line(2);
                            vsync_delayed <= vsync_delay_line(2);
                            de_delayed <= de_delay_line(2);
                        when "100" => 
                            hsync_delayed <= hsync_delay_line(3);
                            vsync_delayed <= vsync_delay_line(3);
                            de_delayed <= de_delay_line(3);
                        when "101" => 
                            hsync_delayed <= hsync_delay_line(4);
                            vsync_delayed <= vsync_delay_line(4);
                            de_delayed <= de_delay_line(4);
                        when others => 
                            hsync_delayed <= hsync_delay_line(5);
                            vsync_delayed <= vsync_delay_line(5);
                            de_delayed <= de_delay_line(5);
                    end case;
                else
                    case delay_b_unsigned is
                        when "000" => 
                            hsync_delayed <= hsync_in;
                            vsync_delayed <= vsync_in;
                            de_delayed <= de_in;
                        when "001" => 
                            hsync_delayed <= hsync_delay_line(0);
                            vsync_delayed <= vsync_delay_line(0);
                            de_delayed <= de_delay_line(0);
                        when "010" => 
                            hsync_delayed <= hsync_delay_line(1);
                            vsync_delayed <= vsync_delay_line(1);
                            de_delayed <= de_delay_line(1);
                        when "011" => 
                            hsync_delayed <= hsync_delay_line(2);
                            vsync_delayed <= vsync_delay_line(2);
                            de_delayed <= de_delay_line(2);
                        when "100" => 
                            hsync_delayed <= hsync_delay_line(3);
                            vsync_delayed <= vsync_delay_line(3);
                            de_delayed <= de_delay_line(3);
                        when "101" => 
                            hsync_delayed <= hsync_delay_line(4);
                            vsync_delayed <= vsync_delay_line(4);
                            de_delayed <= de_delay_line(4);
                        when others => 
                            hsync_delayed <= hsync_delay_line(5);
                            vsync_delayed <= vsync_delay_line(5);
                            de_delayed <= de_delay_line(5);
                    end case;
                end if;
                
                -- Apply chromatic abrasion effect if enabled
                if enable = '1' then
                    r_out <= r_in;  -- Red channel is not delayed
                    g_out <= g_delayed;
                    b_out <= b_delayed;
                    hsync_out <= hsync_delayed;
                    vsync_out <= vsync_delayed;
                    de_out <= de_delayed;
                else
                    -- Pass through if effect disabled
                    r_out <= r_in;
                    g_out <= g_in;
                    b_out <= b_in;
                    hsync_out <= hsync_in;
                    vsync_out <= vsync_in;
                    de_out <= de_in;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
