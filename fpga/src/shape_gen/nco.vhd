library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nco is
    port (
        i_clk        : in  std_logic;
        i_rstb       : in  std_logic;
        i_sync_reset : in  std_logic;
        i_enable     : in  std_logic;  -- new enable signal
        i_fcw        : in  std_logic_vector(8 downto 0);
        o_nco        : out std_logic_vector(15 downto 0)
    );
end nco;

architecture rtl of nco is
    signal r_sync_reset : std_logic;
    signal r_fcw        : unsigned(8 downto 0);
    signal r_nco        : unsigned(15 downto 0);
begin

    p_nco8 : process(i_clk, i_rstb)
    begin
        if i_rstb = '1' then
            r_sync_reset <= '1';
            r_fcw        <= (others => '0');
            r_nco        <= (others => '0');
        elsif rising_edge(i_clk) then
            r_sync_reset <= i_sync_reset;
            r_fcw        <= unsigned(i_fcw);

            if r_sync_reset = '0' then
                r_nco <= (others => '0');
            else
                if i_enable = '1' then
                    r_nco <= r_nco + r_fcw;
                end if;
            end if;
        end if;
    end process p_nco8;

    o_nco <= std_logic_vector(r_nco);

end rtl;
