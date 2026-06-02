library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity mixer_11_1_tb is
end entity;

architecture sim of mixer_11_1_tb is

  -- DUT signals
  signal clk       : std_logic := '0';
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
  signal input_10  : std_logic_vector(11 downto 0) := (others => '0');
  signal input_11  : std_logic_vector(11 downto 0) := (others => '0');
  signal input_12  : std_logic_vector(11 downto 0) := (others => '0');
  signal input_13  : std_logic_vector(11 downto 0) := (others => '0');
  signal input_14  : std_logic_vector(11 downto 0) := (others => '0');
  signal input_15  : std_logic_vector(11 downto 0) := (others => '0');
  signal mutes     : std_logic_vector(15 downto 0);
  signal mixed_out : std_logic_vector(11 downto 0);

begin

  -- Instantiate DUT
  uut: entity work.mixer_11_1
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
      mutes     => mutes,
      mixed_out => mixed_out
    );

  -- Clock process: 10ns period
  clk_process : process
  begin
    while now < 2000 ns loop
      clk <= '0';
      wait for 5 ns;
      clk <= '1';
      wait for 5 ns;
    end loop;
    wait;
  end process;

  -- Stimulus process
  stim_proc : process
  begin
    report "Starting testbench";

    -- Default values
    input_0   <= std_logic_vector(to_unsigned(0, 12));
    input_1   <= std_logic_vector(to_unsigned(0, 12));
    input_2   <= std_logic_vector(to_unsigned(0, 12));
    input_3   <= std_logic_vector(to_unsigned(0, 12));
    input_4   <= std_logic_vector(to_unsigned(0, 12));
    input_5   <= std_logic_vector(to_unsigned(0, 12));
    input_6   <= std_logic_vector(to_unsigned(0, 12));
    input_7   <= std_logic_vector(to_unsigned(0, 12));
    input_8   <= std_logic_vector(to_unsigned(0, 12));
    input_9   <= std_logic_vector(to_unsigned(0, 12));
    input_10  <= std_logic_vector(to_unsigned(0, 12));
    mutes     <= (others => '0');  -- all unmuted

    wait until rising_edge(clk);  -- wait one cycle for processing
    input_0   <= std_logic_vector(to_unsigned(1, 12));
    input_1   <= std_logic_vector(to_unsigned(1, 12));
    input_2   <= std_logic_vector(to_unsigned(1, 12));
    input_3   <= std_logic_vector(to_unsigned(1, 12));
    input_4   <= std_logic_vector(to_unsigned(1, 12));
    input_5   <= std_logic_vector(to_unsigned(1, 12));
    input_6   <= std_logic_vector(to_unsigned(1, 12));
    input_7   <= std_logic_vector(to_unsigned(1, 12));
    input_8   <= std_logic_vector(to_unsigned(1, 12));
    input_9   <= std_logic_vector(to_unsigned(1, 12));
    input_10  <= std_logic_vector(to_unsigned(1, 12));
    wait for 100 ns;
    input_0   <= std_logic_vector(to_unsigned(0, 12));
    input_1   <= std_logic_vector(to_unsigned(0, 12));
    input_2   <= std_logic_vector(to_unsigned(0, 12));
    input_3   <= std_logic_vector(to_unsigned(0, 12));
    input_4   <= std_logic_vector(to_unsigned(0, 12));
    input_5   <= std_logic_vector(to_unsigned(0, 12));
    input_6   <= std_logic_vector(to_unsigned(2, 12));
    input_7   <= std_logic_vector(to_unsigned(2, 12));
    input_8   <= std_logic_vector(to_unsigned(2, 12));
    input_9   <= std_logic_vector(to_unsigned(2, 12));
    input_10  <= std_logic_vector(to_unsigned(2, 12));
    wait for 100 ns;
    input_0   <= std_logic_vector(to_unsigned(1, 12));
    input_1   <= std_logic_vector(to_unsigned(1, 12));
    input_2   <= std_logic_vector(to_unsigned(1, 12));
    input_3   <= std_logic_vector(to_unsigned(1, 12));
    input_4   <= std_logic_vector(to_unsigned(1, 12));
    input_5   <= std_logic_vector(to_unsigned(1, 12));
    input_6   <= std_logic_vector(to_unsigned(1, 12));
    input_7   <= std_logic_vector(to_unsigned(1, 12));
    input_8   <= std_logic_vector(to_unsigned(1, 12));
    input_9   <= std_logic_vector(to_unsigned(1, 12));
    input_10  <= std_logic_vector(to_unsigned(1, 12));
    wait for 100 ns;
    mutes     <= (others => '1');  -- all unmuted

    

--    report "All unmuted, mixed_out = " & integer'image(to_integer(unsigned(mixed_out)));

--    -- Mute some inputs
--    mutes(3) <= '1';  -- mute input_3 (400)
--    mutes(7) <= '1';  -- mute input_7 (800)

--    wait until rising_edge(clk);
--    wait until rising_edge(clk);

--    report "Muted input_3 and input_7, mixed_out = " & integer'image(to_integer(unsigned(mixed_out)));

--    -- Mute all inputs
--    mutes <= (others => '1');

--    wait until rising_edge(clk);
--    wait until rising_edge(clk);

--    report "All muted, mixed_out = " & integer'image(to_integer(unsigned(mixed_out)));

--    -- Saturation test: set all to max
--    mutes <= (others => '0');
--    input_0  <= (others => '1');  -- 4095
--    input_1  <= (others => '1');
--    input_2  <= (others => '1');
--    input_3  <= (others => '1');
--    input_4  <= (others => '1');
--    input_5  <= (others => '1');
--    input_6  <= (others => '1');
--    input_7  <= (others => '1');
--    input_8  <= (others => '1');
--    input_9  <= (others => '1');
--    input_10 <= (others => '1');

--    wait until rising_edge(clk);
--    wait until rising_edge(clk);

--    report "Saturation case, mixed_out = " & integer'image(to_integer(unsigned(mixed_out)));

    wait;
  end process;

end architecture;
