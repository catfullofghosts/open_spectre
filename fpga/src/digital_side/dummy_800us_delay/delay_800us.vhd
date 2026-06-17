--   ____  _____  ______ _   _         _____ _____  ______ _____ _______ _____  ______
--  / __ \|  __ \|  ____| \ | |       / ____|  __ \|  ____/ ____|__   __|  __ \|  ____|
-- | |  | | |__) | |__  |  \| |      | (___ | |__) | |__ | |       | |  | |__) | |__   
-- | |  | |  ___/|  __| | . ` |       \___ \|  ___/|  __|| |       | |  |  _  /|  __|  
-- | |__| | |    | |____| |\  |       ____) | |    | |___| |____   | |  | | \ \| |____ 
--  \____/|_|    |______|_| \_|      |_____/|_|    |______\_____|  |_|  |_|  \_\______|
--                               ______                                                
--                              |______|                                               
-- Module Name: delay_800us
-- Description: BRAM-backed circular delay line for the digital matrix feedback path.
--              Default depth targets ~800 us when sampled at pix_clk/2 (74.25 MHz).
--              depth = delay_seconds * sample_rate  (e.g. 800e-6 * 74.25e6 = 59_400)
--
-- Additional Comments: https://github.com/cfoge/OPEN_SPECTRE

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity delay_800us is
  generic (
    g_WIDTH : positive := 2;
    g_DEPTH : positive := 59400  -- ~800 us @ 74.25 MHz (148.5 MHz pixel clk / 2)
  );
  port (
    i_rst_sync : in std_logic;
    i_clk      : in std_logic;

    i_wr_en   : in  std_logic;
    i_wr_data : in  std_logic_vector(g_WIDTH - 1 downto 0);
    o_full    : out std_logic;

    i_rd_en   : in  std_logic;
    o_rd_data : out std_logic_vector(g_WIDTH - 1 downto 0);
    o_empty   : out std_logic
  );
end delay_800us;

architecture rtl of delay_800us is

  function f_addr_width (depth : positive) return positive is
    variable bits : natural := 1;
    variable max_addr : natural := 1;
  begin
    while max_addr < depth loop
      bits       := bits + 1;
      max_addr   := max_addr * 2;
    end loop;
    return bits;
  end function f_addr_width;

  constant c_addr_width : positive := f_addr_width(g_DEPTH);

  type t_ram is array (0 to g_DEPTH - 1) of std_logic_vector(g_WIDTH - 1 downto 0);

  signal ram          : t_ram;
  signal ptr          : unsigned(c_addr_width - 1 downto 0) := (others => '0');
  signal rd_data_reg  : std_logic_vector(g_WIDTH - 1 downto 0) := (others => '0');
  signal filled       : unsigned(c_addr_width - 1 downto 0) := (others => '0');

  attribute ram_style : string;
  attribute ram_style of ram : signal is "block";

begin

  p_delay : process (i_clk) is
    variable v_ptr : natural;
  begin
    if rising_edge(i_clk) then
      if i_rst_sync = '1' then
        ptr         <= (others => '0');
        filled      <= (others => '0');
        rd_data_reg <= (others => '0');
      else
        if i_rd_en = '1' then
          v_ptr       := to_integer(ptr);
          rd_data_reg <= ram(v_ptr);
        end if;

        if i_wr_en = '1' then
          v_ptr         := to_integer(ptr);
          ram(v_ptr)    <= i_wr_data;

          if ptr = g_DEPTH - 1 then
            ptr <= (others => '0');
          else
            ptr <= ptr + 1;
          end if;

          if filled < g_DEPTH then
            filled <= filled + 1;
          end if;
        end if;
      end if;
    end if;
  end process p_delay;

  o_rd_data <= rd_data_reg;

  -- Circular delay line: always ready once the line has filled.
  o_full  <= '0';
  o_empty <= '1' when filled < g_DEPTH else '0';

end rtl;
