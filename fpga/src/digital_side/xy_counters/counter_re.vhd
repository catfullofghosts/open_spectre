-- 9-bit counter with reset, driven not by a clock but by the rising edge of a signal

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter_re is
    generic (
        width: integer := 9  -- width of the counter
    );
    port (
        clk: in std_logic;       -- clock input
        rst: in std_logic;       -- reset input
        counter_up : in std_logic; 
        enable: in std_logic;    -- enable input
        count: out std_logic_vector(width-1 downto 0)  -- count output
    );
end entity;

architecture behavioral of counter_re is
    signal count_int: unsigned(width-1 downto 0);  -- internal count
    signal cnt_d : std_logic;
    signal counter_up_edge : std_logic;


begin
    process(clk, rst)  -- sensitivity list
    begin
        if rst = '1' then
            count_int <= (others => '0');
        elsif rising_edge(clk) then

            -- detect the edge of the counter signal to use to drive the counter
            cnt_d <= counter_up;
            if cnt_d = '0' and counter_up = '1' then
                counter_up_edge <= '1';
            else
                counter_up_edge <= '0';
            end if;

            if counter_up_edge = '1' then
                count_int <= count_int + 1;
            end if;
        end if;
    end process;
    count <= std_logic_vector(count_int);
end architecture;
