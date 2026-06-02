
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
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(17,8));  
                    when "0010" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(33,8));  
                    when "0011" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(51,8));  
                    when "0100" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(69,8));  
                    when "0101" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(85,8));  
                    when "0110" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(102,8));  
                    when "0111" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(119,8));  
                    when "1000" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(137,8));  
                    when "1001" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(153,8));  
                    when "1010" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(170,8));  
                    when "1011" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(186,8));  
                    when "1100" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(204,8));  
                    when "1101" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(221,8));  
                    when "1110" =>
                        dac_out <= STD_LOGIC_VECTOR(to_unsigned(239,8));  
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
                when "0000" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(0,8));  
                when "0001" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(36,8));  
                when "0010" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(72,8));  
                when "0011" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(107,8));  
                when "0100" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(144,8));  
                when "0101" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(181,8));  
                when "0110" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(218,8));  
                when "0111" =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(255,8));  
            
                when others =>
                    dac_out <= STD_LOGIC_VECTOR(to_unsigned(0,8));
            end case;
        end process;
        
        
    end generate;


    

end architecture;