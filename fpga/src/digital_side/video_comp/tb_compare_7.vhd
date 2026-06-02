library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_compare_7 is
end tb_compare_7;

architecture sim of tb_compare_7 is

    -- DUT ports
    signal clk     : std_logic := '0';
    signal luma_i  : std_logic_vector(7 downto 0) := (others => '0');
    signal span    : std_logic_vector(7 downto 0) := (others => '0');
    signal output  : std_logic_vector(6 downto 0);

    -- Clock period
    constant clk_period : time := 10 ns;

begin

    -- DUT Instantiation
    uut: entity work.compare_7
        port map (
            clk     => clk,
            luma_i  => luma_i,
            span    => span,
            output  => output
        );

    -- Clock generation
    clk_process : process
    begin
        while now < 3000 ns loop  -- adjust as needed
            clk <= '0';
            wait for clk_period / 2;
            clk <= '1';
            wait for clk_period / 2;
        end loop;
        wait;
    end process;

    -- Stimulus process
    stim_proc: process
        variable i : integer := 0;
    begin
        span <= x"1f";  -- Fixed span

        wait for clk_period * 12;  -- Let things settle

        for i in 0 to 255 loop
            luma_i <= std_logic_vector(to_unsigned(i, 8));
            wait for clk_period;

        end loop;

        wait;
    end process;

end sim;
