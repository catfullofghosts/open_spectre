-- need to fix this there isnt enough granualr controll over rate

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nco_dual_wrapper is
    port (
        i_clk        : in  std_logic;
        i_rstb       : in  std_logic;
        i_sync_reset : in  std_logic; -- must = 1 for ncos to run
        i_enable     : in  std_logic;
        i_repeat     : in  std_logic;  
        i_fcw        : in  std_logic_vector(8 downto 0);
        o_nco       : out std_logic_vector(15 downto 0)
    );
end entity;

architecture rtl of nco_dual_wrapper is

    signal nco1_out       : std_logic_vector(15 downto 0);
    signal nco2_out       : std_logic_vector(15 downto 0);

    signal enable_nco2    : std_logic := '0';
    signal enable_nco2_masked    : std_logic := '0';

begin

enable_nco2_masked <= enable_nco2 and i_enable;

    -- first NCO
    nco1_inst : entity work.nco
        port map (
            i_clk        => i_clk,
            i_rstb       => i_rstb,
            i_sync_reset => i_sync_reset,
            i_enable     => i_enable,
            i_fcw        => i_fcw,
            o_nco        => nco1_out
        );

    -- second NCO
    nco2_inst : entity work.nco
        port map (
            i_clk        => i_clk,
            i_rstb       => i_rstb,
            i_sync_reset => i_sync_reset,
            i_enable     => enable_nco2_masked,
            i_fcw        => i_fcw,
            o_nco        => nco2_out
        );

    -- half-period detection
    process(i_clk, i_rstb)
        variable halfway_value : unsigned(15 downto 0) := "1000000000000000"; 
    begin
        if i_rstb = '1' then
            enable_nco2 <= '0';
        elsif rising_edge(i_clk) then
            if i_sync_reset = '0' then
                enable_nco2 <= '0';
            elsif enable_nco2 = '0' and unsigned(nco1_out) >= halfway_value then
                enable_nco2 <= '1';
            end if;
        end if;
    end process;

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if i_repeat = '1' then
            
                if nco1_out > nco2_out then
                        o_nco <= "00000000" & nco1_out(15 downto 8);
                else
                    o_nco <=  "00000000" & nco2_out(15 downto 8);
                end if;
           else
                o_nco <= "00000000" & nco1_out(15 downto 8);
           
           end if;
        end if;
    end process;
    
    -- outputs


end rtl;
