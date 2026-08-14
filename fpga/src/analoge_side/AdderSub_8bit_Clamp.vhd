library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity AdderSub_8bit_Clamp is
  Port ( 
    clk      : in std_logic;
    A        : in  STD_LOGIC_VECTOR(7 downto 0); -- unsigned
    B        : in  STD_LOGIC_VECTOR(7 downto 0); -- signed
    Sum      : out STD_LOGIC_VECTOR(7 downto 0);
    Overflow : out STD_LOGIC
  );
end AdderSub_8bit_Clamp;

architecture Behavioral of AdderSub_8bit_Clamp is
  signal A_u    : UNSIGNED(7 downto 0);
  signal B_s    : SIGNED(7 downto 0);
  signal Result : SIGNED(8 downto 0); -- 13-bit result to hold signed sum
  signal Clamped: UNSIGNED(7 downto 0);
begin

  A_u <= UNSIGNED(A);
  B_s <= SIGNED(B);

  -- Perform addition/subtraction with extended precision
  -- Convert unsigned A to signed by prepending '0', then add signed B
  Result <= SIGNED('0' & A_u) + RESIZE(B_s, 9);

  process(clk)
  begin
    if rising_edge(clk) then
      -- Check if result is negative (signed comparison)
      if Result < 0 then
        Clamped <= (others => '0');
        Overflow <= '1';
      -- Check if result exceeds max 8-bit value (256 = 0xFF)
      elsif Result > 2047 then
        Clamped <= to_unsigned(2047, 8);  -- Max 8-bit value
        Overflow <= '1';
      else
        -- Result is in valid range, extract lower 8 bits (but value will be <= 256)
        Clamped <= UNSIGNED(Result(7 downto 0));
        Overflow <= '0';
      end if;
    end if;
  end process;
  
    process(clk)
    begin
        if rising_edge(clk) then
            Sum <= STD_LOGIC_VECTOR(Clamped);
        end if;
    end process;

end Behavioral;
