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
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE

-- created by   :   RD Jordan

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.Numeric_Std.all;

entity tb_test_digital_side is
end tb_test_digital_side;

architecture behavior of tb_test_digital_side is

  signal sys_clk        : std_logic := '0';
  signal clk_25_in      : std_logic := '0';
  signal rst            : std_logic := '0';
  signal YCRCB          : std_logic_vector(23 downto 0);
  signal RBG            : std_logic_vector(23 downto 0);
  signal matrix_in_addr : std_logic_vector(5 downto 0);
  signal matrix_load    : std_logic;
  signal matrix_latch   : std_logic;
  signal matrix_mask_in : std_logic_vector(63 downto 0); --controls which inputs are routed to a selected output
  signal invert_matrix  : std_logic_vector(63 downto 0) := (others => '0'); --inverts a matrix input globaly
  signal h_sync         : std_logic                     := '0';
  signal v_sync         : std_logic                     := '0';
  signal ext_vid_in     : std_logic_vector(7 downto 0);
  signal vid_span       : std_logic_vector(7 downto 0) := x"ff";

  function shift_left_64(index : integer) return std_logic_vector is
    variable result              : unsigned(63 downto 0) := (others => '0');
  begin
    if index >= 0 and index < 64 then
      result(index) := '1';
    end if;
    return std_logic_vector(result);
  end function;

begin
  RBG <= YCRCB;

  vga_trimming_signals : entity work.vga_trimming_signals
    port map
    (
      px_clk      => clk_25_in,
      reset       => '0',
      mode_select => '0',
      h_sync      => h_sync,
      v_sync      => v_sync
    );

  DUT : entity work.digital_side
    port map
    (
      sys_clk        => sys_clk,
      h_sync         => h_sync,
      v_sync         => v_sync,
      pix_clk        => clk_25_in,
      rst            => rst,
      YCRCB          => YCRCB,
      matrix_in_addr => matrix_in_addr,
      matrix_load    => matrix_load,
      matrix_mask_in => matrix_mask_in,
      invert_matrix  => invert_matrix,
      ext_vid_in     => ext_vid_in,
      vid_span       => vid_span
    );

  clk_process : process
  begin
    sys_clk   <= '0';
    clk_25_in <= '0';
    wait for 10 ns;
    sys_clk <= '1';
    wait for 10 ns;
    sys_clk   <= '0';
    clk_25_in <= '1';
    wait for 10 ns;
    sys_clk <= '1';
    wait for 10 ns;
  end process clk_process;

  simulation : process
  begin
    -- Reset
    rst <= '0';
    wait for 100 ns;
    rst          <= '1';
    matrix_load  <= '0';
    matrix_latch <= '0';
    wait for 100 ns;
    rst <= '0';
    wait for 100 ns;

    for i in 0 to 63 loop
      matrix_in_addr <= std_logic_vector(to_unsigned(i, 6)); -- this is the output
      matrix_mask_in <= shift_left_64(63);
      wait for 50 ns;
      matrix_load  <= '1';
      matrix_latch <= '1';
      wait for 50 ns;
      matrix_load  <= '0';
      matrix_latch <= '0';
    end loop;

    -- Test case 1
    wait for 500 ns;
    --test the video input comparitor
    for i in 0 to 254 loop
      ext_vid_in <= std_logic_vector(to_unsigned(i, 8));
      wait for 50 ns;
    end loop;
    ------------------------------------------------------- test flip flops (masked by vertical balnking)
    matrix_in_addr <= std_logic_vector(to_unsigned(32, 6));
    matrix_mask_in <= shift_left_64(1);
    wait for 50 ns;
    matrix_load  <= '1';
    matrix_latch <= '1';
    wait for 50 ns;
    matrix_load    <= '0';
    matrix_latch   <= '0';
    matrix_in_addr <= std_logic_vector(to_unsigned(33, 6));
    matrix_mask_in <= shift_left_64(2);
    wait for 50 ns;
    matrix_load  <= '1';
    matrix_latch <= '1';
    wait for 50 ns;
    matrix_load  <= '0';
    matrix_latch <= '0';

    ------------------------------------------------------- test edge detector
    matrix_in_addr <= std_logic_vector(to_unsigned(30, 6));
    matrix_mask_in <= shift_left_64(1);
    wait for 50 ns;
    matrix_load  <= '1';
    matrix_latch <= '1';
    wait for 50 ns;
    matrix_load  <= '0';
    matrix_latch <= '0';

    ------------------------------------------------------- test edge detector, invertor and delay, and overlay gates
    for i in 18 to 31 loop
      matrix_in_addr <= std_logic_vector(to_unsigned(i, 6)); -- this is the output
      matrix_mask_in <= shift_left_64(1);
      wait for 50 ns;
      matrix_load  <= '1';
      matrix_latch <= '1';
      wait for 50 ns;
      matrix_load  <= '0';
      matrix_latch <= '0';
    end loop;

    -- End simulation
    -- wait for 10 ns;
    --  assert false report "End of simulation" severity failure;
    wait;
  end process simulation;
end behavior;
