library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_distance_wrapper is
    port (
        px_clk         : in  std_logic;
        reset          : in  std_logic;
        -- center coordinate inputs
        cx_level       : in  std_logic_vector(15 downto 0);
        cy_level       : in  std_logic_vector(15 downto 0);
        -- VGA signals to outside if needed
        h_sync         : out std_logic;
        v_sync         : out std_logic;
        video_on       : out std_logic;
        start_of_frame : out std_logic;
        start_of_active_video : out std_logic;
        frame_counter  : out std_logic_vector(3 downto 0);
        -- distance output
        distance       : out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of vga_distance_wrapper is

    -- signals to connect modules
    signal h_sync_s          : std_logic;
    signal v_sync_s          : std_logic;
    signal h_sync_d          : std_logic;
    signal v_sync_d          : std_logic;
    signal video_on_s        : std_logic;
    signal start_of_frame_s  : std_logic;
    signal start_of_active_s : std_logic;
    signal frame_counter_s   : std_logic_vector(3 downto 0);

    -- pixel counters
    signal x_pixel : unsigned(15 downto 0) := (others => '0');
    signal y_pixel : unsigned(15 downto 0) := (others => '0');

begin

    -- instance of vga_trimming_signals
    vga_inst : entity work.vga_trimming_signals
        port map (
            px_clk                => px_clk,
            reset                 => reset,
            mode_select           => mode_select,
            h_sync                => h_sync_s,
            v_sync                => v_sync_s,
            video_on              => video_on_s,
            start_of_frame        => start_of_frame_s,
            start_of_active_video => start_of_active_s,
            frame_counter         => frame_counter_s
        );

    -- connect outputs to wrapper ports
    h_sync         <= h_sync_s;
    v_sync         <= v_sync_s;
    video_on       <= video_on_s;
    start_of_frame <= start_of_frame_s;
    start_of_active_video <= start_of_active_s;
    frame_counter  <= frame_counter_s;

    -- pixel counters: simple X/Y counter
    process(px_clk)
    begin
        if rising_edge(px_clk) then
            h_sync_d <= h_sync_s;
            v_sync_d <= v_sync_s;
        
            if reset = '1' or start_of_frame_s = '1' then
                x_pixel <= (others => '0');
                y_pixel <= (others => '0');
            else 
                if h_sync_s = '1' and h_sync_d = '0' then
                    -- end of line
                    x_pixel <= (others => '0');
                    if v_sync_s = '1'  and v_sync_d = '0' then
                        -- end of frame
                        y_pixel <= (others => '0');
                    else
                        y_pixel <= y_pixel + 1;
                    end if;
                else
                    x_pixel <= x_pixel + 1;
                end if;
            end if;
        end if;
    end process;

    -- instance of distance_calc
    dist_inst : entity work.distance_calc
        port map (
            clk      => px_clk,
            rst      => reset,
            cx_in    => cx_level,
            cy_in    => cy_level,
            x_in     => std_logic_vector(x_pixel),
            y_in     => std_logic_vector(y_pixel),
            dist_out => distance
        );

end architecture;
