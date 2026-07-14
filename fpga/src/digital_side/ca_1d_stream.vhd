-- Streaming 1D elementary cellular automaton (Wolfram rule 0-255).
-- Steps on each rising edge of step_en (digital X counter rate).
-- Resets on h-sync so each scanline starts fresh; optional Y/X modulation via ctrl.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ca_1d_stream is
  port (
    clk     : in  std_logic;
    rst     : in  std_logic; -- line reset (active high, h-sync), clears shift register
    step_en : in  std_logic; -- pixel enable from X counter path
    rule    : in  std_logic_vector(7 downto 0);
    ctrl    : in  std_logic_vector(3 downto 0);
    -- ctrl(0) inject_xor_y0 : XOR inject with y_line(0)
    -- ctrl(1) rule_xor_y    : effective rule = rule xor y_line
    -- ctrl(2) line_seed_y0  : seed center cell from y_line(0) on line reset
    -- ctrl(3) inject_xor_x0 : XOR inject with x_pos(0)
    y_line  : in  std_logic_vector(7 downto 0);
    x_pos   : in  std_logic_vector(7 downto 0);
    inject  : in  std_logic;
    ca_out  : out std_logic
  );
end entity ca_1d_stream;

architecture rtl of ca_1d_stream is

  signal left_r        : std_logic := '0';
  signal center_r      : std_logic := '0';
  signal right_r       : std_logic := '0';
  signal step_d        : std_logic := '0';
  signal step_edge     : std_logic := '0';
  signal pattern       : std_logic_vector(2 downto 0);
  signal ca_out_r      : std_logic := '0';
  signal rule_eff      : std_logic_vector(7 downto 0);
  signal inject_eff    : std_logic;

  attribute MARK_DEBUG                 : string;
  attribute MARK_DEBUG of step_edge : signal is "TRUE";
  attribute MARK_DEBUG of step_en   : signal is "TRUE";
  attribute MARK_DEBUG of ca_out_r  : signal is "TRUE";
  attribute MARK_DEBUG of pattern   : signal is "TRUE";

begin

  rule_eff <= rule xor y_line when ctrl(1) = '1' else rule;

  inject_eff <= inject
                xor (y_line(0) when ctrl(0) = '1' else '0')
                xor (x_pos(0) when ctrl(3) = '1' else '0');

  process (clk)
  begin
    if rising_edge(clk) then
      step_d    <= step_en;
      step_edge <= '1' when step_d = '0' and step_en = '1' else '0';

      if rst = '1' then
        left_r   <= '0';
        center_r <= y_line(0) when ctrl(2) = '1' else '0';
        right_r  <= '0';
        ca_out_r <= '0';
      elsif step_edge = '1' then
        pattern  <= left_r & center_r & right_r;
        ca_out_r <= rule_eff(to_integer(unsigned(pattern)));

        left_r   <= center_r;
        center_r <= right_r;
        right_r  <= inject_eff;
      end if;
    end if;
  end process;

  ca_out <= ca_out_r;

end architecture rtl;
