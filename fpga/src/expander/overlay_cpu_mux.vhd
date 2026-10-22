library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Splits the CPU byte bus.
--   0x0000 .. 0x03FF  register file
--   0x0400 .. 0x23FF  sprite pixel RAM, 2048 words
--   0x2400 .. 0x5C3F  text cells, 3600 words, value in bits 15:0
--   0x5C40 .. 0x9C3F  font rows, 4096 words, value in bits 15:0
-- A word is 4 bytes. The cell or font value is the low half of that word.

entity overlay_cpu_mux is
  generic (
    G_ADDR_WIDTH : positive := 11
  );
  port (
    cpu_clk   : in  std_logic;
    cpu_en    : in  std_logic;
    cpu_we    : in  std_logic_vector(3 downto 0);
    cpu_addr  : in  std_logic_vector(15 downto 0);
    cpu_wdata : in  std_logic_vector(31 downto 0);
    cpu_rdata : out std_logic_vector(31 downto 0);

    reg_en    : out std_logic;
    reg_we    : out std_logic_vector(3 downto 0);
    reg_addr  : out std_logic_vector(12 downto 0);
    reg_wdata : out std_logic_vector(31 downto 0);
    reg_rdata : in  std_logic_vector(31 downto 0);

    bram_en    : out std_logic;
    bram_we    : out std_logic_vector(3 downto 0);
    bram_addr  : out std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
    bram_wdata : out std_logic_vector(31 downto 0);
    bram_rdata : in  std_logic_vector(31 downto 0);

    cell_we   : out std_logic;
    cell_addr : out std_logic_vector(11 downto 0);
    cell_din  : out std_logic_vector(15 downto 0);
    cell_dout : in  std_logic_vector(15 downto 0);
    font_we   : out std_logic;
    font_addr : out std_logic_vector(11 downto 0);
    font_din  : out std_logic_vector(15 downto 0);
    font_dout : in  std_logic_vector(15 downto 0)
  );
end entity overlay_cpu_mux;

architecture rtl of overlay_cpu_mux is

  constant C_REG_END    : integer := 16#400#;
  constant C_SPRITE_LO  : integer := 16#400#;
  constant C_SPRITE_HI  : integer := 16#2400#;
  constant C_CELL_LO    : integer := 16#2400#;
  constant C_CELL_HI    : integer := 16#5C40#;
  constant C_FONT_LO    : integer := 16#5C40#;
  constant C_FONT_HI    : integer := 16#9C40#;

  signal addr_u     : unsigned(15 downto 0);
  signal hit_reg    : std_logic;
  signal hit_sprite : std_logic;
  signal hit_cell   : std_logic;
  signal hit_font   : std_logic;
  signal low_bytes  : std_logic;

begin

  addr_u    <= unsigned(cpu_addr);
  low_bytes <= '1' when (cpu_we(0) = '1') or (cpu_we(1) = '1') else '0';

  hit_reg    <= '1' when addr_u < C_REG_END else '0';
  hit_sprite <= '1' when (addr_u >= C_SPRITE_LO) and (addr_u < C_SPRITE_HI) else '0';
  hit_cell   <= '1' when (addr_u >= C_CELL_LO) and (addr_u < C_CELL_HI) else '0';
  hit_font   <= '1' when (addr_u >= C_FONT_LO) and (addr_u < C_FONT_HI) else '0';

  reg_en    <= cpu_en when hit_reg = '1' else '0';
  reg_we    <= cpu_we when hit_reg = '1' else (others => '0');
  reg_addr  <= cpu_addr(12 downto 0);
  reg_wdata <= cpu_wdata;

  bram_en    <= cpu_en when hit_sprite = '1' else '0';
  bram_we    <= cpu_we when hit_sprite = '1' else (others => '0');
  bram_wdata <= cpu_wdata;
  bram_addr  <= std_logic_vector(resize(
    shift_right(addr_u - to_unsigned(C_SPRITE_LO, 16), 2),
    G_ADDR_WIDTH
  ));

  cell_we   <= '1' when (hit_cell = '1') and (cpu_en = '1') and (low_bytes = '1') else '0';
  cell_din  <= cpu_wdata(15 downto 0);
  cell_addr <= std_logic_vector(resize(
    shift_right(addr_u - to_unsigned(C_CELL_LO, 16), 2),
    12
  ));

  font_we   <= '1' when (hit_font = '1') and (cpu_en = '1') and (low_bytes = '1') else '0';
  font_din  <= cpu_wdata(15 downto 0);
  font_addr <= std_logic_vector(resize(
    shift_right(addr_u - to_unsigned(C_FONT_LO, 16), 2),
    12
  ));

  cpu_rdata <= bram_rdata when hit_sprite = '1' else
               x"0000" & cell_dout when hit_cell = '1' else
               x"0000" & font_dout when hit_font = '1' else
               reg_rdata when hit_reg = '1' else
               (others => '0');

end architecture rtl;
