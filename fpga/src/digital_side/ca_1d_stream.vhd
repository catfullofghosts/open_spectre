-- Streaming 1D elementary cellular automaton (Wolfram rule 0-255).
-- Steps on rising edges of gated step_en; h-sync line reset; optional block stride.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ca_1d_stream is
  port (
    clk          : in  std_logic;
    rst          : in  std_logic; -- line reset (active high, h-sync)
    step_en      : in  std_logic; -- pixel enable from X counter path
    frame_active : in  std_logic; -- active video only (not in blanking)
    rule         : in  std_logic_vector(7 downto 0);
    ctrl         : in  std_logic_vector(3 downto 0);
    x_div        : in  std_logic_vector(1 downto 0); -- 00=/1 01=/2 10=/4 11=/8
    y_div        : in  std_logic_vector(1 downto 0);
    y_line       : in  std_logic_vector(7 downto 0);
    x_pos        : in  std_logic_vector(7 downto 0);
    inject       : in  std_logic;
    ca_out       : out std_logic
  );
end entity ca_1d_stream;

architecture rtl of ca_1d_stream is

  signal left_r     : std_logic := '0';
  signal center_r   : std_logic := '0';
  signal right_r    : std_logic := '0';
  signal step_d     : std_logic := '0';
  signal step_edge  : std_logic := '0';
  signal pattern    : std_logic_vector(2 downto 0);
  signal ca_out_r   : std_logic := '0';
  signal ca_out_blk : std_logic := '0';
  signal rule_eff   : std_logic_vector(7 downto 0);
  signal inject_eff : std_logic;
  signal x_div_ok   : std_logic;
  signal y_div_ok   : std_logic;
  signal step_en_g  : std_logic;

  function f_div_ok (
    count   : std_logic_vector(7 downto 0);
    div_sel : std_logic_vector(1 downto 0)
  ) return std_logic is
    variable u : unsigned(7 downto 0);
  begin
    u := unsigned(count);
    case div_sel is
      when "00"   => return '1';
      when "01"   => return '0' when u(0) /= '0' else '1';
      when "10"   => return '0' when u(1 downto 0) /= "00" else '1';
      when others => return '0' when u(2 downto 0) /= "000" else '1';
    end case;
  end function f_div_ok;

begin

  rule_eff <= rule xor y_line when ctrl(1) = '1' else rule;

  inject_eff <= inject
                xor (y_line(0) when ctrl(0) = '1' else '0')
                xor (x_pos(0) when ctrl(3) = '1' else '0');

  x_div_ok  <= f_div_ok(x_pos, x_div);
  y_div_ok  <= f_div_ok(y_line, y_div);
  step_en_g <= step_en when frame_active = '1' and x_div_ok = '1' else '0';

  process (clk)
  begin
    if rising_edge(clk) then
      step_d    <= step_en_g;
      step_edge <= '1' when step_d = '0' and step_en_g = '1' else '0';

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

      if frame_active = '0' then
        ca_out_blk <= '0';
      elsif x_div_ok = '1' and y_div_ok = '1' then
        ca_out_blk <= ca_out_r;
      end if;
    end if;
  end process;

  ca_out <= ca_out_blk;

end architecture rtl;
