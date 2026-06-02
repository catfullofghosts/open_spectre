-- Does a 6 step aproximation of a square root using Herons method of square root aproximation
-- 140 clocks total delay but runs a video rate

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


use IEEE.NUMERIC_STD.ALL;

entity herons_pipelined is
  Port ( 
        clk      : in  std_logic;
        value_in : in  unsigned(31 downto 0):= (others => '0'); 
        sqrt_out : out unsigned(31 downto 0) 
  
  );
end herons_pipelined;

architecture Behavioral of herons_pipelined is

  signal x_current,x_current2,x_current3,x_current4,x_current5 : unsigned(31 downto 0) := (others => '1');
  signal x_next,x_next2,x_next3,x_next4,x_next5,next6    : unsigned(31 downto 0) := (others => '1');
  signal S,S2,S3,S4,S5,s6,s7       : unsigned(31 downto 0) := (others => '1');  

begin


   process(clk)
   
    begin
        if rising_edge(clk) then
            
        if  value_in < 200 then   
               x_current <= value_in/4;
        elsif value_in < 800 then
               x_current <= value_in/32;
        else 
               x_current <= value_in/64;
        end if;
 
         S         <= value_in;
         sqrt_out <= x_next5;

        end if;
    end process;
    
    
    
  herron_pipe_1 : entity work.heron_func
  Port map( 
        clk     => clk,
        s => s,
        x_current => x_current,
        x_next => x_next ,
        s_next => s2
    );
    
  herron_pipe_2 : entity work.heron_func 
  Port map( 
        clk     => clk,
        s => s2,
        x_current => x_next,
        x_next => x_current2 ,
        s_next => s3
    );
    
  herron_pipe_3 : entity work.heron_func
  Port map( 
        clk     => clk,
        s => s3,
        x_current => x_current2,
        x_next => x_next2, 
        s_next => s4
    );
    
      herron_pipe_4 : entity work.heron_func
  Port map( 
        clk     => clk,
        s => s4,
        x_current => x_next2,
        x_next => x_current3 ,
        s_next => s5
    );
    
      herron_pipe_5 : entity work.heron_func
  Port map( 
        clk     => clk,
        s => s5,
        x_current => x_current3,
        x_next => x_next3 ,
        s_next => s6
    );
    
      herron_pipe_6 : entity work.heron_func
  Port map( 
        clk     => clk,
        s => s6,
        x_current => x_next3,
        x_next => x_next4 ,
        s_next => s7
    );
    
  herron_pipe_7 : entity work.heron_func
  Port map( 
        clk     => clk,
        s => s7,
        x_current => x_next4,
        x_next => x_next5 
    );
    

end Behavioral;
