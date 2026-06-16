
--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______ 
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: SQRT by RD Jordan
-- Created: Early 2023
-- Description: 
-- Dependencies: Sqrt function form Stack overflow, used by the shape gen ramp to get a nice curve rather then a sharp triangle
-- Additional Comments: You can view the project here: https://github.com/cfoge/OPEN_SPECTRE-
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity SQRT is
    generic (
        b : natural range 4 to 32 := 19;
        F : natural := 4  -- fractional bits
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        value  : in  std_logic_vector(18 downto 0);
        result : out std_logic_vector(18 downto 0)  -- integer part of sqrt
    );
end SQRT;

architecture Behave of SQRT is
    constant N : natural := 11; -- pipeline depth

    type reg_array is array (0 to N) of unsigned(b+F-1 downto 0);

    signal vop  : reg_array := (others => (others => '0'));
    signal vres : reg_array := (others => (others => '0'));
    signal vone : reg_array := (others => (others => '0'));
    signal value_offset : std_logic_vector(18 downto 0);

begin
    value_offset <= value(15 downto 0) & "000";
    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                vop  <= (others => (others => '0'));
                vres <= (others => (others => '0'));
                vone <= (others => (others => '0'));
                result <= (others => '0');
            else
                -- Stage 0: load new input (shifted left by F)
                vop(0)  <= resize(unsigned(value_offset), b+F) sll F;
                vres(0) <= (others => '0');
                vone(0) <= to_unsigned(2**(b-2), b+F);

                -- Pipeline stages
                for i in 0 to N-1 loop
                    if vone(i) /= 0 then
                        if vop(i) >= vres(i) + vone(i) then
                            vop(i+1)  <= vop(i) - (vres(i) + vone(i));
                            vres(i+1) <= (vres(i) / 2) + vone(i);
                        else
                            vop(i+1)  <= vop(i);
                            vres(i+1) <= vres(i) / 2;
                        end if;
                        vone(i+1) <= vone(i) / 4;
                    else
                        -- Done
                        vop(i+1)  <= vop(i);
                        vres(i+1) <= vres(i);
                        vone(i+1) <= vone(i);
                    end if;
                end loop;

                -- Output: integer part of sqrt
                result <= std_logic_vector(vres(N)(b+F-1 downto F));
            end if;
        end if;
    end process;
end Behave;


--entity SQRT is
--    Generic ( b  : natural range 4 to 32 := 19 ); 
--    Port ( value  : in   STD_LOGIC_VECTOR (18 downto 0);
--           result : out  STD_LOGIC_VECTOR (18 downto 0));
--end SQRT;

--architecture Behave of SQRT is
--begin
--   process (value)
--   variable vop  : unsigned(b-1 downto 0);  
--   variable vres : unsigned(b-1 downto 0);  
--   variable vone : unsigned(b-1 downto 0);  
--   begin
--      vone := to_unsigned(2**(b-2),b);
--      vop  := unsigned(value);
--      vres := (others=>'0'); 
--      while (vone /= 0) loop
--         if (vop >= vres+vone) then
--            vop   := vop - (vres+vone);
--            vres  := vres/2 + vone;
--         else
--            vres  := vres/2;
--         end if;
--         vone := vone/4;
--      end loop;
--      result <= std_logic_vector(vres(result'range));
--   end process;
--end;


--library IEEE;
--use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;

--entity SQRT is
--    Generic ( b  : natural range 4 to 32 := 16 ); 
--    Port ( value  : in   STD_LOGIC_VECTOR (15 downto 0);
--           result : out  STD_LOGIC_VECTOR (7 downto 0));
--end SQRT;

--architecture Behave of SQRT is
--begin
--   process (value)
--   variable vop  : unsigned(b-1 downto 0);  
--   variable vres : unsigned(b-1 downto 0);  
--   variable vone : unsigned(b-1 downto 0);  
--   begin
--      vone := to_unsigned(2**(b-2),b);
--      vop  := unsigned(value);
--      vres := (others=>'0'); 
--      while (vone /= 0) loop
--         if (vop >= vres+vone) then
--            vop   := vop - (vres+vone);
--            vres  := vres/2 + vone;
--         else
--            vres  := vres/2;
--         end if;
--         vone := vone/4;
--      end loop;
--      result <= std_logic_vector(vres(result'range));
--   end process;
--end;

