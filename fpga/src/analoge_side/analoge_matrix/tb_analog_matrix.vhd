library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.array_pck.all;

entity tb_analog_matrix is
end entity tb_analog_matrix;

architecture behavior of tb_analog_matrix is

    signal clk          : std_logic := '0';
    signal mixer_inputs : array_12(15 downto 0);
    signal mutes        : array_16(19 downto 0);
    signal outputs      : array_12(19 downto 0);

    constant clk_period : time := 10 ns;

begin

    -- Instantiate the unit under test (UUT)
    uut: entity work.analog_matrix
        port map (
            clk           => clk,
            mixer_inputs  => mixer_inputs,
            mutes         => mutes,
            outputs       => outputs
        );

    -- Clock generation
    clk_process : process
    begin
        while now < 1 ms loop
            clk <= '0';
            wait for clk_period / 2;
            clk <= '1';
            wait for clk_period / 2;
        end loop;
        wait;
    end process;

    -- Stimulus process
    stim_proc : process
    begin
        -- Initialize inputs
        for i in 0 to 15 loop
            mixer_inputs(i) <= std_logic_vector(to_unsigned(i, 12));
        end loop;

        -- All mutes off initially (allow signal through)
        for i in 0 to 19 loop
            mutes(i) <= (others => '0');
        end loop;

        wait for 100 ns;
        
        -- All mutes on  
        for i in 0 to 19 loop
            mutes(i) <= (others => '1');
        end loop;

        wait for 100 ns;

        -- Enable all mute on even outputs
        for i in 0 to 19 loop
            if i mod 2 = 0 then
                mutes(i) <= (others => '1'); -- all channels muted
            else
                mutes(i) <= (others => '0'); -- unmuted
            end if;
        end loop;

        wait for 100 ns;

--        -- Set all mixer inputs to max value
--        for i in 0 to 10 loop
--            mixer_inputs(i) <= (others => '1');  -- max 12-bit value
--        end loop;

--        wait for 100 ns;

--        -- All mutes active
--        for i in 0 to 9 loop
--            mutes(i) <= (others => '1');
--        end loop;

--        wait for 100 ns;

        -- Done
        wait;
    end process;

end architecture behavior;
