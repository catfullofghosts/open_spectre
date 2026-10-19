library ieee;
use ieee.std_logic_1164.all;

-- One register on the regional pixel clock (axi_dynclk PXL_CLK_O, the BUFR).
-- Inputs are produced on the global pixel clock (PXL_CLK_G_O). Outputs feed rgb2dvi.
entity video_bufr_reg is
  port (
    pxl_clk : in std_logic;
    -- Same net as rgb2dvi aRst_n: MMCM LOCKED, active-low reset while unlocked.
    rst_n   : in std_logic := '1';

    video_in       : in std_logic_vector(23 downto 0);
    h_sync         : in std_logic;
    v_sync         : in std_logic;
    start_of_frame : in std_logic;

    vid_pData  : out std_logic_vector(23 downto 0);
    vid_pHSync : out std_logic;
    vid_pVSync : out std_logic;
    vid_pVDE   : out std_logic
  );
end entity video_bufr_reg;

architecture rtl of video_bufr_reg is
begin

  process (pxl_clk, rst_n)
  begin
    if rst_n = '0' then
      vid_pData  <= (others => '0');
      vid_pHSync <= '0';
      vid_pVSync <= '0';
      vid_pVDE   <= '0';
    elsif rising_edge(pxl_clk) then
      vid_pData  <= video_in;
      vid_pHSync <= h_sync;
      vid_pVSync <= v_sync;
      vid_pVDE   <= start_of_frame;
    end if;
  end process;

end architecture rtl;
