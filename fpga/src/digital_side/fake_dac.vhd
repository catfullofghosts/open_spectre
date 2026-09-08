
-- convert the 3 and 4 bit luma/chrom asignals from the digital side into evenly distributed values
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fake_dac is
    generic (
        width : natural  := 4 
    );
    port (
        dac_in   : in std_logic_vector(3 downto 0);
        dac_out  : out std_logic_vector(7 downto 0)
    );
end fake_dac;

architecture rtl of fake_dac is
    begin
    luma_dac : if width = 4 generate
        process (dac_in)
            begin
                case dac_in is
                    when "0000" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(0,8));  
                    when "0001" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(10,8));  
                    when "0010" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(15,8));  
                    when "0011" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(26,8));  
                    when "0100" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(35,8));  
                    when "0101" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(54,8));  
                    when "0110" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(63,8));  
                    when "0111" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(75,8));  
                    when "1000" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(88,8));  
                    when "1001" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(100,8));  
                    when "1010" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(120,8));  
                    when "1011" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(150,8));  
                    when "1100" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(175,8));  
                    when "1101" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(190,8));  
                    when "1110" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(210,8));  
                    when "1111" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(255,8));  
                
                    when others =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(0,8));
                end case;
        end process;
        
    end generate;

    chroma_dac : if width = 3 generate
        process (dac_in)
        begin
            case dac_in is
                when "0000" => -- is non linier to reflect the actual EMS performence
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(0,8));  
                when "0001" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(25,8));  
                when "0010" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(55,8));  
                when "0011" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(175,8));  
                when "0100" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(101,8));  
                when "0101" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(151,8));  
                when "0110" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(190,8));  
                when "0111" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(255,8));  
            
                when others =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(0,8));


            end case;
        end process;
        
        
    end generate;


    

end architecture;