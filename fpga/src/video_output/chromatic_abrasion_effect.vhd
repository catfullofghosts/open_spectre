library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity chromatic_abrasion_effect is
    Port (
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        enable : in STD_LOGIC;
        delay_g : in STD_LOGIC_VECTOR(3 downto 0); -- 0-8 pixel clocks for green
        delay_b : in STD_LOGIC_VECTOR(3 downto 0); -- 0-8 pixel clocks for blue
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

    constant C_DLY_MAX : natural := 8;

    type delay_line_t is array (0 to C_DLY_MAX - 1) of STD_LOGIC_VECTOR(7 downto 0);
    type sync_delay_line_t is array (0 to C_DLY_MAX - 1) of STD_LOGIC;

    signal g_delay_line : delay_line_t;
    signal b_delay_line : delay_line_t;
    signal hsync_delay_line : sync_delay_line_t;
    signal vsync_delay_line : sync_delay_line_t;
    signal de_delay_line : sync_delay_line_t;

    signal delay_g_unsigned : UNSIGNED(3 downto 0);
    signal delay_b_unsigned : UNSIGNED(3 downto 0);

    function f_clamp_dly (d : unsigned(3 downto 0)) return integer is
        variable n : integer;
    begin
        n := to_integer(d);
        if n < 0 then
            return 0;
        elsif n > C_DLY_MAX then
            return C_DLY_MAX;
        else
            return n;
        end if;
    end function f_clamp_dly;

    function f_pick_byte (
        live : std_logic_vector(7 downto 0);
        line : delay_line_t;
        dly  : integer
    ) return std_logic_vector is
    begin
        if dly <= 0 then
            return live;
        else
            return line(dly - 1);
        end if;
    end function f_pick_byte;

    function f_pick_bit (
        live : std_logic;
        line : sync_delay_line_t;
        dly  : integer
    ) return std_logic is
    begin
        if dly <= 0 then
            return live;
        else
            return line(dly - 1);
        end if;
    end function f_pick_bit;

begin

    delay_g_unsigned <= unsigned(delay_g);
    delay_b_unsigned <= unsigned(delay_b);

    process(clk)
        variable v_g : integer;
        variable v_b : integer;
        variable v_sync : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                for i in 0 to C_DLY_MAX - 1 loop
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
                for i in C_DLY_MAX - 1 downto 1 loop
                    g_delay_line(i) <= g_delay_line(i - 1);
                    b_delay_line(i) <= b_delay_line(i - 1);
                    hsync_delay_line(i) <= hsync_delay_line(i - 1);
                    vsync_delay_line(i) <= vsync_delay_line(i - 1);
                    de_delay_line(i) <= de_delay_line(i - 1);
                end loop;

                g_delay_line(0) <= g_in;
                b_delay_line(0) <= b_in;
                hsync_delay_line(0) <= hsync_in;
                vsync_delay_line(0) <= vsync_in;
                de_delay_line(0) <= de_in;

                v_g := f_clamp_dly(delay_g_unsigned);
                v_b := f_clamp_dly(delay_b_unsigned);
                if v_g > v_b then
                    v_sync := v_g;
                else
                    v_sync := v_b;
                end if;

                if enable = '1' then
                    r_out <= r_in;
                    g_out <= f_pick_byte(g_in, g_delay_line, v_g);
                    b_out <= f_pick_byte(b_in, b_delay_line, v_b);
                    hsync_out <= f_pick_bit(hsync_in, hsync_delay_line, v_sync);
                    vsync_out <= f_pick_bit(vsync_in, vsync_delay_line, v_sync);
                    de_out <= f_pick_bit(de_in, de_delay_line, v_sync);
                else
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
