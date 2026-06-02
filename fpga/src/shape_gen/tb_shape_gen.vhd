library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_shape_gen is
end tb_shape_gen;

architecture sim of tb_shape_gen is

    -- Clock and reset
    signal clk         : std_logic := '0';
    signal clk_div2         : std_logic := '0';
    signal clk_divV         : std_logic := '0';

    signal rst         : std_logic := '1';

    -- VGA sync outputs
    signal h_sync                : std_logic :='1';
    signal v_sync                : std_logic := '1';
    signal video_on             : std_logic;
    signal start_of_frame       : std_logic;
    signal start_of_active_video: std_logic;
    signal frame_counter        : std_logic_vector(3 downto 0);
    signal mode_select          : std_logic := '0'; -- SVGA 800x600

    -- Shape gen inputs
    signal pos_h   : std_logic_vector(11 downto 0) := x"190";--(others => '0');
    signal pos_v   : std_logic_vector(11 downto 0) := x"12c";--(others => '0');
    signal zoom_h : std_logic_vector(11 downto 0) := x"0f9";
    signal zoom_v : std_logic_vector(11 downto 0) := x"349";

    signal circle_i       : std_logic_vector(11 downto 0) := x"0f4";
    signal gear_i         : std_logic_vector(11 downto 0) := x"002";
    signal lantern_i      : std_logic_vector(11 downto 0) := x"002";
    signal fizz_i         : std_logic_vector(11 downto 0) := x"100";
    signal shape_a_sel    : std_logic_vector(3 downto 0) := "1110";
    signal shape_b_sel    : std_logic_vector(3 downto 0) := "0000";

    signal shape_a        : std_logic;
    signal shape_b        : std_logic;
    
    signal x_in : std_logic_vector(8 downto 0) := (others => '0');
    signal y_in : std_logic_vector(8 downto 0) := (others => '0');

    -- Write_file_ex inputs
    signal r, g, b        : std_logic_vector(7 downto 0);

begin

    -- Clock process
    clk_proc : process
    begin
        clk <= '0';
        wait for 10 ns;
        clk <= '1';
        wait for 10 ns;
    end process;
    
    clk_proc_div2 : process
    begin
        clk_div2 <= '0';
        wait for 20 ns;
        clk_div2 <= '1';
        wait for 20 ns;
    end process;
    
        clk_proc_divV : process
    begin
        clk_divV <= '0';
        wait for 8000 ns;
        clk_divV <= '1';
        wait for 8000 ns;
    end process;

    -- Release reset after a short delay
    rst_proc : process
    begin
        wait for 100 ns;
        rst <= '0';
        wait;
    end process;
    
    x_counter : entity work.counter_re
    port
    map (
    clk    => clk, 
    rst    => h_sync, --rst, -- x needs to be reset by hs otherwise some bits out run over and get out of sync on the next line
    counter_up => clk_div2,
    enable => '1',
    count  => x_in
    );
    
        
    y_counter : entity work.counter_re
    port
    map (
    clk    => clk, 
    rst    => v_sync, --rst, -- x needs to be reset by hs otherwise some bits out run over and get out of sync on the next line
    counter_up => clk_divV,
    enable => '1',
    count  => y_in
    );

    -- VGA sync generator
    vga_gen_inst : entity work.vga_trimming_signals
        port map (
            px_clk                 => clk,
            reset                  => rst,
            mode_select            => mode_select,
            h_sync                 => h_sync,
            v_sync                 => v_sync,
            video_on               => video_on,
            start_of_frame         => start_of_frame,
            start_of_active_video  => start_of_active_video,
            frame_counter          => frame_counter
        );

    -- Shape generator
    shape_gen_inst : entity work.shape_gen
        port map (
            clk                    => clk,
            rst                    => rst,
            h_sync                 => h_sync,
            v_sync                 => v_sync,
            start_of_frame         => start_of_frame,
            start_of_active_video  => start_of_active_video,
            video_on               => video_on,
            pos_h                  => pos_h,
            pos_v                  => pos_v,
            zoom_h                 => zoom_h,
            zoom_v                 => zoom_v,
            circle_i               => circle_i,
            gear_i                 => gear_i,
            lantern_i              => lantern_i,
            fizz_i                 => fizz_i,
            x_in                   => x_in,
            y_in                   => y_in,
            shape_a_sel            => shape_a_sel,
            shape_b_sel            => shape_b_sel,
            shape_a                => shape_a,
            shape_b                => shape_b
        );

    -- Output RGB all bits driven from shape_a
    r <= (others => shape_a);
    g <= (others => shape_a);
    b <= (others => shape_a);

    -- Write output to file
    writer_inst : entity work.write_file_ex
        port map (
            clk => clk,
            hs  => h_sync,
            vs  => v_sync,
            start_of_frame => start_of_frame,
            r   => r,
            g   => g,
            b   => b
        );

end architecture;
