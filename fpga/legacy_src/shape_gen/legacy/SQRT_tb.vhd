
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: SQRT_tb by RD Jordan
-- Created: 2025
-- Description: test bench for square root module
-- Dependencies: Sqrt function form Stack overflow, used by the shape gen ramp to get a nice curve rather then a sharp triangle
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SQRT_tb is
end entity;

architecture tb of SQRT_tb is

    -- Component under test
    component SQRT is
        generic ( b  : natural range 4 to 32 := 19 ); 
        port (
            value  : in  std_logic_vector (18 downto 0);
            result : out std_logic_vector (18 downto 0)
        );
    end component;

    -- Signals
    signal value  : std_logic_vector (18 downto 0) := (others => '0');
    signal result : std_logic_vector (18 downto 0);

begin

    -- DUT instantiation
    uut : SQRT
        generic map ( b => 19 )
        port map (
            value  => value,
            result => result
        );

    -- Stimulus process
    process
        variable i : integer := 0;
    begin
        -- Sweep input values from 0 to 400
        for i in 0 to 400 loop
            value <= std_logic_vector(to_unsigned(i, 19));
            wait for 10 ns;
            report "value=" & integer'image(i) & 
                   " result=" & integer'image(to_integer(unsigned(result)));
        end loop;

        -- End simulation
        report "Simulation finished" severity failure;
    end process;

end architecture;
