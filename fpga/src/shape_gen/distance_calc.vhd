-- Calculated the distence between 2 points on a per pixel basis just using squares, not pythag


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity distance_calc is
    generic (
        WIDTH  : integer := 800;
        HEIGHT : integer := 600
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        -- inputs: center of distance
        cx_in  : in  std_logic_vector(15 downto 0);
        cy_in  : in  std_logic_vector(15 downto 0);
        -- inputs: current pixel coordinates
        x_in   : in  std_logic_vector(15 downto 0);
        y_in   : in  std_logic_vector(15 downto 0);
        -- output: normalized distance (0..255)
        dist_out : out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of distance_calc is

    signal cx, cy : integer;
    signal x, y   : integer;
    signal dx, dy : integer;
    signal dx_sq, dy_sq : integer;
    signal sum_sq : unsigned(31 downto 0);

    signal sqrt_result_valid : std_logic;
    signal sqrt_result_data  : std_logic_vector(31 downto 0);

    signal dist_norm : integer;
    
    signal result : unsigned(31 downto 0);  -- integer part of sqrt

begin

    process(clk)
    begin
        if rising_edge(clk) then
            -- Convert inputs to integers
            cx <= to_integer(unsigned(cx_in));
            cy <= to_integer(unsigned(cy_in));
            x  <= to_integer(unsigned(x_in));
            y  <= to_integer(unsigned(y_in));

            -- Calculate dx, dy
            dx <= x - cx;
            dy <= y - cy;

            -- Square terms
            dx_sq <= dx * dx;
            dy_sq <= dy * dy;

            -- Pack sum for CORDIC input
            sum_sq <= to_unsigned((dx_sq + dy_sq)/64, 32);
            


                -- Drive output
--                dist_out <= std_logic_vector(result(15 downto 0));
                dist_out <= std_logic_vector(sum_sq(15 downto 0));

            end if;
    end process;
    
--sqrt_pipeline : entity work.herons_pipelined
--  Port map ( 
--        clk     => clk,
--        value_in => sum_sq,
--        sqrt_out => result
  
--  );

end architecture;

