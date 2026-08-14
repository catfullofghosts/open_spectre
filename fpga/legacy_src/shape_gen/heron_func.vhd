
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity heron_func is
  Port ( 
        clk      : in  std_logic;
        s : in  unsigned(31 downto 0) := (others => '0');  
        x_current : in  unsigned(31 downto 0) := (others => '0');  
        x_next : out unsigned(31 downto 0);
        s_next : out unsigned(31 downto 0)
  
  );
end heron_func;

architecture Behavioral of heron_func is

        signal temp_div : unsigned(15 downto 0);
        signal s_16 : unsigned(15 downto 0);
        signal s_next16 : unsigned(15 downto 0);
        signal s_next16_d : unsigned(15 downto 0);
        signal s_next16_d2 : unsigned(15 downto 0);
        signal x_current_16 : unsigned(15 downto 0);
        signal temp_sum : unsigned(32 downto 0);  -- one extra bit for addition
        
         -- define a custom array type for the delay line
        type t_delay_line is array (0 to 18) of unsigned(15 downto 0);
    
        -- now declare the signal with an explicit default
        signal delay_line : t_delay_line := (others => (others => '0'));
        signal x_delayed  : unsigned(15 downto 0) := (others => '0');
    


begin

s_16 <= s(15 downto 0);
x_current_16 <= x_current(15 downto 0);
s_next <= x"0000" & s_next16_d2;

    process(clk)
    begin
        if rising_edge(clk) then
            -- shift all stages
            delay_line(0) <= x_current_16;
            for i in 1 to 16 loop
                delay_line(i) <= delay_line(i-1);
            end loop;

            -- output is the last stage
            s_next16_d <= s_next16; 
            s_next16_d2 <= s_next16_d;
            x_delayed <= delay_line(15);
        end if;
    end process;


   process(clk)
    begin
        if rising_edge(clk) then 
            if x_current = 0 then
                temp_sum <= resize(x_delayed, 33) + resize(temp_div, 33); -- when the input x_current changes, the new input and the old temp div are used to calculate a new invalid 
                -- result x current needs to go through the div pipeline r be delayed by 16 clcocks
        
                x_next <= unsigned(temp_sum(32 downto 1));  -- divide by 2
            else
                temp_sum <= resize(x_delayed, 33) + resize(temp_div, 33);
        
                x_next <= unsigned(temp_sum(32 downto 1));  -- divide by 2
            end if;
             
        end if;
    end process;
    
  div_pipe : entity work.pipelined_divider
  port map(
    clk         => clk, 
    rst      => '0',   
    valid_in     => '1',
    num_in       => s_16,
    den_in       => x_current_16,
    valid_out    => open,
    quotient_out => temp_div,
    remainder_out => open,
    s_delayed => s_next16
  );


end Behavioral;

