library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- convert the 3 and 4 bit luma/chrom asignals from the digital side into evenly distributed values

entity fake_dac is
    generic (
        width : integer := 4 
    );
    port (
        dac_in   : in std_logic_vector(3 downto 0);
        dac_out  : out std_logic_vector(7 downto 0)
        
    );
end entity fake_dac;

architecture rtl of fake_dac is
    signal dac_out_int : integer range 0 to 255;
begin
    luma_dac : if width = 4 generate
        process (dac_in)
            begin
                case dac_in is
                    when "0000" =>
                        dac_out_int <= 0;  
                    when "0001" =>
                        dac_out_int <= 17;  
                    when "0010" =>
                        dac_out_int <= 33;  
                    when "0011" =>
                        dac_out_int <= 51;  
                    when "0100" =>
                        dac_out_int <= 69;  
                    when "0101" =>
                        dac_out_int <= 85;  
                    when "0110" =>
                        dac_out_int <= 102;  
                    when "0111" =>
                        dac_out_int <= 119;  
                    when "1000" =>
                        dac_out_int <= 137;  
                    when "1001" =>
                        dac_out_int <= 153;  
                    when "1010" =>
                        dac_out_int <= 170;  
                    when "1011" =>
                        dac_out_int <= 186;  
                    when "1100" =>
                        dac_out_int <= 204;  
                    when "1101" =>
                        dac_out_int <= 221;  
                    when "1110" =>
                        dac_out_int <= 239;  
                    when "1111" =>
                        dac_out_int <= 255;  
                
                    when others =>
                        dac_out_int <= 0;
                end case;
        end process;
        
    end generate;

    chroma_dac : if width = 3 generate
        process (dac_in)
        begin
            case dac_in is
                when "0000" =>
                    dac_out_int <= 0;  
                when "0001" =>
                    dac_out_int <= 36;  
                when "0010" =>
                    dac_out_int <= 72;  
                when "0011" =>
                    dac_out_int <= 107;  
                when "0100" =>
                    dac_out_int <= 144;  
                when "0101" =>
                    dac_out_int <= 181;  
                when "0110" =>
                    dac_out_int <= 218;  
                when "0111" =>
                    dac_out_int <= 255;  
            
                when others =>
                    dac_out_int <= 0;
            end case;
        end process;
        
        
    end generate;
    
    -- Convert integer to std_logic_vector
    dac_out <= std_logic_vector(to_unsigned(dac_out_int, 8));

    

end architecture;