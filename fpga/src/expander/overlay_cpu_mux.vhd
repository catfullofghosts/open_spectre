library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Demuxes the shared AXI-BRAM / regs bus between the register file and the overlay
-- frame buffer.  Byte addresses below G_BYTE_BASE go to the register file; addresses
-- at/above G_BYTE_BASE map to overlay BRAM words.

entity overlay_cpu_mux is
  generic (
    G_BYTE_BASE  : std_logic_vector(12 downto 0) := std_logic_vector(to_unsigned(16#400#, 13));
    G_ADDR_WIDTH : positive := 11
  );
  port (
    cpu_clk   : in  std_logic;
    cpu_en    : in  std_logic;
    cpu_we    : in  std_logic_vector(3 downto 0);
    cpu_addr  : in  std_logic_vector(12 downto 0);
    cpu_wdata : in  std_logic_vector(31 downto 0);
    cpu_rdata : out std_logic_vector(31 downto 0);

    reg_en      : out std_logic;
    reg_we      : out std_logic_vector(3 downto 0);
    reg_addr    : out std_logic_vector(12 downto 0);
    reg_wdata   : out std_logic_vector(31 downto 0);
    reg_rdata   : in  std_logic_vector(31 downto 0);

    bram_en     : out std_logic;
    bram_we     : out std_logic_vector(3 downto 0);
    bram_addr   : out std_logic_vector(G_ADDR_WIDTH - 1 downto 0);
    bram_wdata  : out std_logic_vector(31 downto 0);
    bram_rdata  : in  std_logic_vector(31 downto 0)
  );
end entity overlay_cpu_mux;

architecture rtl of overlay_cpu_mux is

  signal hit_bram : std_logic;

begin

  hit_bram <= '1' when unsigned(cpu_addr) >= unsigned(G_BYTE_BASE) else '0';

  reg_en    <= cpu_en when hit_bram = '0' else '0';
  reg_we    <= cpu_we when hit_bram = '0' else (others => '0');
  reg_addr  <= cpu_addr;
  reg_wdata <= cpu_wdata;

  bram_en    <= cpu_en when hit_bram = '1' else '0';
  bram_we    <= cpu_we when hit_bram = '1' else (others => '0');
  bram_wdata <= cpu_wdata;
  bram_addr  <= std_logic_vector(
    resize(
      (unsigned(cpu_addr) - unsigned(G_BYTE_BASE)) srl 2,
      G_ADDR_WIDTH
    )
  );

  cpu_rdata <= bram_rdata when hit_bram = '1' else reg_rdata;

end architecture rtl;
