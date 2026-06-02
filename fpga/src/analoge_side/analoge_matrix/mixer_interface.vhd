--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|      
-- Created by: Rob D Jordan
-- Create Date: 12.09.2023 14:52:58
-- Design Name: 
-- Module Name: mixer_interface - Behavioral

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
library work;
use work.array_pck.all;


entity mixer_interface is

  Port ( 
    clk      :in    STD_LOGIC;
    rst      :in    STD_LOGIC;
    wr       :in    STD_LOGIC;
    out_addr     :in    integer;
--    ch_addr      :in    integer;
    gain_in  :in    std_logic_vector(15 downto 0); -- 1= mute 0 = unmuted
    gain_out  :out    std_logic_vector(15 downto 0); -- matrix state read out
    mixer_inputs : in array_12(15 downto 0);
    outputs : out array_12(19 downto 0)  

  );
end mixer_interface;

architecture Behavioral of mixer_interface is

    signal mutes        : array_16(19 downto 0);
    signal ram_address        : std_logic_vector(7 downto 0); 

begin

ram_address <= std_logic_vector(to_unsigned(out_addr, 8));

process (clk) is
begin
    if rising_edge (clk) then
        if wr = '1' then 
          mutes(out_addr) <= gain_in;

        elsif rst = '1' then -- on reset all inputs are muted (all pins in matrix removed)
             mutes <= (others => (others => '1'));
       end if;
    
    end if;
end process;

analog_matrix: entity work.analog_matrix
        port map (
            clk           => clk,
            mixer_inputs  => mixer_inputs,
            mutes         => mutes,
            outputs       => outputs
       );
       
matrix_state_ram : entity work.RAM_16x20 -- holds the state of the analog matrix for reading back the pin state
      port map ( clk => clk,
           reset => rst,
           write_enable => wr,
           address => ram_address,
           data_in => gain_in,
           data_out => gain_out
        );


end Behavioral;
