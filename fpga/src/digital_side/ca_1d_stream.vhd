-- Streaming 1D elementary cellular automaton (Wolfram rule 0-255).
-- Steps on each rising edge of step_en (digital X counter rate).
-- inject is the right-neighbour source (shared with inv_in(1) xored with inv_in(2) / matrix out 27 , 28).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ca_1d_stream is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic; -- line reset (active high), clears shift register
    step_en : in  std_logic; -- pixel enable from X counter path
    rule    : in  std_logic_vector(7 downto 0);
    inject  : in  std_logic;
    ca_out  : out std_logic
  );
end entity ca_1d_stream;

architecture rtl of ca_1d_stream is

  signal left_r   : std_logic := '0';
  signal center_r : std_logic := '0';
  signal right_r  : std_logic := '0';
  signal step_d,step_d2   : std_logic := '0';
  signal step_edge : std_logic := '0';
  signal pattern  : std_logic_vector(2 downto 0);
  signal ca_out_r : std_logic := '0';

begin



  process (clk)
  begin
    if rising_edge(clk) then
      step_d <= step_en;
      step_d2 <= step_d;
      step_edge <= '1' when step_d = '0' and step_en = '1' else '0';

      if rst = '1' then
        left_r   <= '0';
        center_r <= '0';
        right_r  <= '0';
        ca_out_r <= '0';
      elsif step_edge = '1' then
        pattern <= left_r & center_r & right_r;
        ca_out_r <= rule(to_integer(unsigned(pattern)));

        left_r   <= center_r;
        center_r <= right_r;
        right_r  <= inject;
      end if;
    end if;
  end process;

  ca_out <= ca_out_r;

end architecture rtl;
