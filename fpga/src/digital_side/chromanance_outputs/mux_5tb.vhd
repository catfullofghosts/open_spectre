--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: 
-- Created: Early 2023
-- Description: 
-- Dependencies: 
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE-

-- created by   :   RD Jordan
--TB for 5 paralell 2:1 muxes with a common select

library ieee;
use ieee.std_logic_1164.all;

entity mux5p is
    port (
        sel: in std_logic;
        a: in std_logic_vector(5 downto 0);
        b: in std_logic_vector(5 downto 0);
        c: out std_logic_vector(5 downto 0)
    );
end mux5p;

architecture beh of mux5p is
    component mux is
        port (
            sel: in std_logic;
            a: in std_logic;
            b: in std_logic;
            c: out std_logic
        );
    end component;
begin
    mux1: mux port map (sel=>sel, a=>a(0), b=>b(0), c=>c(0));
    mux2: mux port map (sel=>sel, a=>a(1), b=>b(1), c=>c(1));
    mux3: mux port map (sel=>sel, a=>a(2), b=>b(2), c=>c(2));
    mux4: mux port map (sel=>sel, a=>a(3), b=>b(3), c=>c(3));
    mux5: mux port map (sel=>sel, a=>a(4), b=>b(4), c=>c(4));
    mux6: mux port map (sel=>sel, a=>a(5), b=>b(5), c=>c(5));
end beh;
