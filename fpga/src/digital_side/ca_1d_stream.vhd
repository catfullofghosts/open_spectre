--VHDL2008
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
    rule_xor_y   : in  std_logic;
    rule_xor_x   : in  std_logic;
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
  signal xorY, XorX   : std_logic_vector(7 downto 0);
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
      when "00" =>
        return '1';
      when "01" =>
        if u(0) /= '0' then
          return '0';
        else
          return '1';
        end if;
      when "10" =>
        if u(1 downto 0) /= "00" then
          return '0';
        else
          return '1';
        end if;
      when others =>
        if u(2 downto 0) /= "000" then
          return '0';
        else
          return '1';
        end if;
    end case;
  end function f_div_ok;

begin
  -- Conditional assignments rewritten without when/else: Vivado 2024.2
  -- flags some of those forms as VHDL-2019 even under -vhdl2008.
  process (y_line, rule_xor_y)
  begin
    if rule_xor_y = '1' then
      xorY <= y_line;
    else
      xorY <= (others => '0');
    end if;
  end process;

  process (x_pos, rule_xor_x)
  begin
    if rule_xor_x = '1' then
      xorX <= x_pos;
    else
      xorX <= (others => '0');
    end if;
  end process;

  rule_eff <= rule xor xorY xor xorX;

  x_div_ok  <= f_div_ok(x_pos, x_div);
  y_div_ok  <= f_div_ok(y_line, y_div);

  process (step_en, frame_active, x_div_ok, y_div_ok)
  begin
    if frame_active = '1' and x_div_ok = '1' and y_div_ok = '1' then
      step_en_g <= step_en;
    else
      step_en_g <= '0';
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      step_d <= step_en_g;
      if step_d = '0' and step_en_g = '1' then
        step_edge <= '1';
      else
        step_edge <= '0';
      end if;

      if rst = '1' then
        left_r   <= '0';
        center_r <= '0';
        right_r  <= '0';
        ca_out_r <= '0';
      elsif step_edge = '1' then
        pattern  <= left_r & center_r & right_r;
        ca_out_r <= rule_eff(to_integer(unsigned(pattern)));

        left_r   <= center_r;
        center_r <= right_r;
        right_r  <= inject;
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

