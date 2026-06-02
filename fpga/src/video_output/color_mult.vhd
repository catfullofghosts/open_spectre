library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity color_mult is
    port (
        dout  : out std_logic_vector(18 downto 0); -- 19-bit output (zero-extended 16-bit product)
        a     : in  std_logic_vector(7 downto 0);  -- 8-bit input
        b     : in  std_logic_vector(7 downto 0);  -- 8-bit input
        ce    : in  std_logic;                     -- clock enable
        clk   : in  std_logic;                     -- clock
        reset : in  std_logic                      -- synchronous reset
    );
end entity;

architecture pipelined of color_mult is
    -- Stage 0: input registers
    signal a_r      : unsigned(7 downto 0) := (others => '0');
    signal b_r      : unsigned(7 downto 0) := (others => '0');

    -- Stage 1: product register (full 16-bit)
    signal prod_r   : unsigned(15 downto 0) := (others => '0');

    -- Stage 2: output register (19-bit zero-extended)
    signal dout_r   : unsigned(18 downto 0) := (others => '0');

    -- Optional valid pipeline if you ever need it externally (kept internal here)
    signal v0, v1, v2 : std_logic := '0';

    -- (Optional, vendor-specific) Hint to use DSP
    -- attribute use_dsp : string;
    -- attribute use_dsp of prod_r : signal is "yes";
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                a_r   <= (others => '0');
                b_r   <= (others => '0');
                prod_r <= (others => '0');
                dout_r <= (others => '0');
                v0 <= '0'; v1 <= '0'; v2 <= '0';
            elsif ce = '1' then
                -- Stage 0: register inputs
                a_r <= unsigned(a);
                b_r <= unsigned(b);
                v0  <= '1';

                -- Stage 1: do the multiply, register product
                prod_r <= a_r * b_r;
                v1     <= v0;

                -- Stage 2: widen to 19 bits (zero-extend) and register output
                dout_r <= resize(prod_r, 19);
                v2     <= v1;
            end if;
        end if;
    end process;

    dout <= std_logic_vector(dout_r);
end architecture;
