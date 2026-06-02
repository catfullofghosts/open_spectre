library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity color_encoder_tb is
end entity color_encoder_tb;

architecture testbench of color_encoder_tb is
    -- Clock and reset signals
    signal clk : std_logic := '0';
    signal reset : std_logic := '0';
    
    -- DAC input signals (4-bit inputs for each channel)
    signal y_dac_in   : std_logic_vector(3 downto 0) := (others => '0');
    signal c1_dac_in  : std_logic_vector(3 downto 0) := (others => '0');
    signal c2_dac_in  : std_logic_vector(3 downto 0) := (others => '0');
    
    -- DAC output signals (8-bit outputs)
    signal y_dac_out  : std_logic_vector(7 downto 0);
    signal c1_dac_out : std_logic_vector(7 downto 0);
    signal c2_dac_out : std_logic_vector(7 downto 0);
    
    -- Color encoder input signals (8-bit inputs - changed from 11-bit)
    signal y_enc_in   : std_logic_vector(7 downto 0);
    signal c1_enc_in  : std_logic_vector(7 downto 0);
    signal c2_enc_in  : std_logic_vector(7 downto 0);
    signal swap_early : std_logic := '0';
    
    -- Color encoder output signals
    signal red   : std_logic_vector(7 downto 0);
    signal green : std_logic_vector(7 downto 0);
    signal blue  : std_logic_vector(7 downto 0);
    
    -- Clock period
    constant CLK_PERIOD : time := 10 ns;  -- 100 MHz
    
begin
    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;
    
    -- Instantiate DAC for Y (luma) channel - 4-bit width
    dac_y : entity work.fake_dac
        generic map (
            width => 4
        )
        port map (
            dac_in  => y_dac_in,
            dac_out => y_dac_out
        );
    
    -- Instantiate DAC for C1 (chroma 1) channel - 3-bit width
    dac_c1 : entity work.fake_dac
        generic map (
            width => 4
        )
        port map (
            dac_in  => c1_dac_in,
            dac_out => c1_dac_out
        );
    
    -- Instantiate DAC for C2 (chroma 2) channel - 3-bit width
    dac_c2 : entity work.fake_dac
        generic map (
            width => 4
        )
        port map (
            dac_in  => c2_dac_in,
            dac_out => c2_dac_out
        );
    
    -- Connect DAC outputs directly to encoder inputs (8-bit to 8-bit, no extension needed)
    y_enc_in  <= y_dac_out;
    c1_enc_in <= c1_dac_out;
    c2_enc_in <= c2_dac_out;
    
    -- Instantiate color encoder (Verilog module)
    color_encoder_inst : entity work.color_encoder
        port map (
            clk        => clk,
            y          => y_enc_in,
            c1         => c1_enc_in,
            c2         => c2_enc_in,
            swap_early => swap_early,
            red        => red,
            green      => green,
            blue       => blue
        );
    
    -- Test stimulus process
    stimulus : process
    begin
        -- Initial reset
        reset <= '1';
        wait for 100 ns;
        reset <= '0';
        wait for 100 ns;
        
--        -- Test case 1: All channels at minimum
--        y_dac_in  <= "0000";
--        c1_dac_in <= "0000";
--        c2_dac_in <= "0000";
--        swap_early <= '0';
--        wait for 200 ns;
        
--        -- Test case 2: All channels at maximum
--        y_dac_in  <= "1111";
--        c1_dac_in <= "0111";
--        c2_dac_in <= "0111";
--        swap_early <= '0';
--        wait for 200 ns;
        
--        -- Test case 3: Mid-range values
--        y_dac_in  <= "1000";
--        c1_dac_in <= "0100";
--        c2_dac_in <= "0100";
--        swap_early <= '0';
--        wait for 200 ns;
        
--        -- Test case 4: Different chroma values
--        y_dac_in  <= "1010";
--        c1_dac_in <= "0011";
--        c2_dac_in <= "0101";
--        swap_early <= '0';
--        wait for 200 ns;
        
--        -- Test case 5: Test swap functionality
--        y_dac_in  <= "1100";
--        c1_dac_in <= "0111";
--        c2_dac_in <= "0001";
--        swap_early <= '1';
--        wait for 200 ns;
        
--        -- Test case 6: Sweep through some values
--        for i in 0 to 15 loop
--            y_dac_in <= std_logic_vector(to_unsigned(i, 4));
--            c1_dac_in <= std_logic_vector(to_unsigned(i mod 8, 3));
--            c2_dac_in <= std_logic_vector(to_unsigned((i + 4) mod 8, 3));
--            wait for 100 ns;
--        end loop;
        
        -- Hold for a bit more
        wait for 500 ns;
        
        -- End simulation
        report "Simulation completed" severity note;
        wait;
    end process stimulus;
    
    -- Monitor process (optional - for debugging)
    monitor : process(clk)
    begin
        if rising_edge(clk) then
            report "Y=" & integer'image(to_integer(unsigned(y_dac_in))) & 
                   " -> " & integer'image(to_integer(unsigned(y_dac_out))) &
                   ", C1=" & integer'image(to_integer(unsigned(c1_dac_in))) &
                   " -> " & integer'image(to_integer(unsigned(c1_dac_out))) &
                   ", C2=" & integer'image(to_integer(unsigned(c2_dac_in))) &
                   " -> " & integer'image(to_integer(unsigned(c2_dac_out))) &
                   " | RGB=(" & integer'image(to_integer(unsigned(red))) & "," &
                   integer'image(to_integer(unsigned(green))) & "," &
                   integer'image(to_integer(unsigned(blue))) & ")";
        end if;
    end process monitor;
    
end architecture testbench;

