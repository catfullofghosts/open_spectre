
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: analog_matrix by RD Jordan
-- Created: Early 2023
-- Description: 
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE-

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.ALL;
library work;
use work.array_pck.all;

entity analog_matrix is
    Port (
         clk : in STD_LOGIC;
         mixer_inputs : in array_12(15 downto 0); -- the inputs to the matrix mixer
         mutes : in array_16(19 downto 0); -- the mutes for each out of the matrix mixer
        outputs : out array_12(19 downto 0)  
    );
end analog_matrix;

architecture Behavioral of analog_matrix is

  signal input_0   : std_logic_vector(11 downto 0);
  signal input_1   : std_logic_vector(11 downto 0);
  signal input_2   : std_logic_vector(11 downto 0);
  signal input_3   : std_logic_vector(11 downto 0);
  signal input_4   : std_logic_vector(11 downto 0);
  signal input_5   : std_logic_vector(11 downto 0);
  signal input_6   : std_logic_vector(11 downto 0);
  signal input_7   : std_logic_vector(11 downto 0);
  signal input_8   : std_logic_vector(11 downto 0);
  signal input_9   : std_logic_vector(11 downto 0);
  signal input_10  : std_logic_vector(11 downto 0);
  signal input_11  : std_logic_vector(11 downto 0);
  signal input_12  : std_logic_vector(11 downto 0) := (others => '0');
  signal input_13  : std_logic_vector(11 downto 0) := (others => '0');
  signal input_14  : std_logic_vector(11 downto 0) := (others => '0');
  signal input_15  : std_logic_vector(11 downto 0) := (others => '0');

begin
    -- unpack input channels
    input_0  <= mixer_inputs(0);
    input_1  <= mixer_inputs(1);
    input_2  <= mixer_inputs(2);
    input_3  <= mixer_inputs(3);
    input_4  <= mixer_inputs(4);
    input_5  <= mixer_inputs(5);
    input_6  <= mixer_inputs(6);
    input_7  <= mixer_inputs(7);
    input_8  <= mixer_inputs(8);
    input_9  <= mixer_inputs(9);
    input_10 <= mixer_inputs(10);
    input_11 <= mixer_inputs(11);
--    input_12 <= mixer_inputs(12); -- these 4 inputs are from the sliders, it would be easyer to get write directly tot he outputs or something like that rather then have the 4 extra mixer channels
--    input_13 <= mixer_inputs(13); 
--    input_14 <= mixer_inputs(14);
--    input_15 <= mixer_inputs(15);



    -- Instantiate 20 instances of the AudioMixer module
    g_GENERATE_MIXER: for ii in 0 to 19 generate

    Mix: entity work.mixer_11_1 -- change to output name for clarity
    port map (
      clk       => clk,
      input_0   => input_0,
      input_1   => input_1,
      input_2   => input_2,
      input_3   => input_3,
      input_4   => input_4,
      input_5   => input_5,
      input_6   => input_6,
      input_7   => input_7,
      input_8   => input_8,
      input_9   => input_9,
      input_10  => input_10,
      input_11  => input_11,
      input_12  => input_12,
      input_13  => input_13,
      input_14  => input_14,
      input_15  => input_15,
      mutes     => mutes(ii),
      mixed_out => outputs(ii)
    );
    
  end generate g_GENERATE_MIXER;


end Behavioral;
