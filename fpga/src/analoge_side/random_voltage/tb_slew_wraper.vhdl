library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_slew_wraper is
end tb_slew_wraper;

architecture Behavioral of tb_slew_wraper is

  -- Component under test
  component slew_wraper is
    Port (
      clk       : in  std_logic;
      rst       : in  std_logic;
      slew_sel  : in  std_logic_vector(2 downto 0);
      input     : in  std_logic_vector(9 downto 0);
      output    : out std_logic_vector(9 downto 0)
    );
  end component;

  -- Signals to connect to DUT
  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal slew_sel  : std_logic_vector(2 downto 0) := (others => '0');
  signal input_sig : std_logic_vector(9 downto 0) := (others => '0');
  signal output_sig: std_logic_vector(9 downto 0);

  constant CLK_PERIOD : time := 10 ns;

begin

  -- Instantiate DUT
  uut: slew_wraper
    port map (
      clk       => clk,
      rst       => rst,
      slew_sel  => slew_sel,
      input     => input_sig,
      output    => output_sig
    );

  -- Clock process
  clk_process : process
  begin
    while true loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
  end process;

  -- Stimulus process
  stim_proc : process
  begin
    -- Hold reset for a few cycles
    wait for 20 ns;
    rst <= '0';
    
    -- Apply input and test each slew_sel setting
    for sel in 0 to 4 loop
      slew_sel <= std_logic_vector(to_unsigned(sel, 3));
      for i in 0 to 31 loop
        input_sig <= std_logic_vector(to_unsigned(i * 32, 10));
        wait for CLK_PERIOD;
      end loop;
      wait for CLK_PERIOD * 5;
      for i in 0 to 31 loop
        input_sig <= std_logic_vector(to_unsigned(1023-(i * 32), 10));
        wait for CLK_PERIOD;
      end loop;
      wait for CLK_PERIOD * 5;
    end loop;

    -- Test invalid selector
    slew_sel <= "111";
    input_sig <= (others => '1');
    wait for 5 * CLK_PERIOD;

    wait;
  end process;

end Behavioral;
