library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.array_pck.all;

entity tb_mixer_interface is
end tb_mixer_interface;

architecture behavior of tb_mixer_interface is

    -- Component under test
    component mixer_interface
        port (
            clk         : in std_logic;
            rst         : in std_logic;
            wr          : in std_logic;
            out_addr    : in integer;
            gain_in     : in std_logic_vector(15 downto 0);
            gain_out    : out std_logic_vector(15 downto 0);
            mixer_inputs: in array_12(15 downto 0);
            outputs     : out array_12(19 downto 0)
        );
    end component;

    -- Signals
    signal clk         : std_logic := '0';
    signal rst         : std_logic := '0';
    signal wr          : std_logic := '0';
    signal out_addr    : integer := 0;
    signal gain_in     : std_logic_vector(15 downto 0) := (others => '0');
    signal gain_out    : std_logic_vector(15 downto 0);
    signal mixer_inputs: array_12(15 downto 0) :=  (others =>  (others => '0'));
    signal outputs     : array_12(19 downto 0);

    -- Clock period
    constant clk_period : time := 10 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: mixer_interface
        port map (
            clk         => clk,
            rst         => rst,
            wr          => wr,
            out_addr    => out_addr,
            gain_in     => gain_in,
            gain_out    => gain_out,
            mixer_inputs=> mixer_inputs,
            outputs     => outputs
        );

    -- Clock generation
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for clk_period / 2;
            clk <= '1';
            wait for clk_period / 2;
        end loop;
    end process;

    -- Stimulus process
    stim_proc: process
    begin
        -- Apply reset
        rst <= '1';
        wait for clk_period * 2;
        rst <= '0';
        
        mixer_inputs(0) <=  (others => '1');
        mixer_inputs(1) <=  (others => '1');
        
       wait for 100 ns;
       
       
      
        -- Write to a few addresses
        for addr in 0 to 3 loop
            wr <= '1';
            out_addr <= addr;
            gain_in <= std_logic_vector(to_unsigned(1, 16));
            wait for clk_period;
            wr <= '0';
            wait for clk_period;
        end loop;
        
        wait for 100 ns;
        mixer_inputs(1) <=  (others => '0');
        wait for 100 ns;
        mixer_inputs(0) <=  (others => '0');
        
        
--        -- Readout test
--        wait for clk_period * 4;

--        -- Hold simulation
        wait;
    end process;

end behavior;
