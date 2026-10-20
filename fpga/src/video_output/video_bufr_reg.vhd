library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Move one pixel (and its sync) from the global fabric clock (PXL_CLK_G_O)
-- onto the regional HDMI pixel clock (PXL_CLK_O, the BUFR).
--
-- A single flip-flop here samples a bus that changes every fabric clock on an
-- unrelated edge. A static splash still looks like a logo. The Spectron image
-- changes every pixel and comes out black or torn. This FIFO hands whole
-- pixels across, so a patched luma field stays a picture.
entity video_bufr_reg is
  port (
    src_clk : in std_logic;
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

  constant C_AW : natural := 4; -- 16 words, pointers are 5 bits

  type t_mem is array (0 to 15) of std_logic_vector(26 downto 0);
  signal mem : t_mem := (others => (others => '0'));
  attribute ram_style : string;
  attribute ram_style of mem : signal is "distributed";

  signal src_rst_sr : std_logic_vector(1 downto 0) := "11";
  signal pxl_rst_sr : std_logic_vector(1 downto 0) := "11";

  signal wr_bin  : unsigned(C_AW downto 0) := (others => '0');
  signal wr_gray : unsigned(C_AW downto 0) := (others => '0');
  signal rd_bin  : unsigned(C_AW downto 0) := (others => '0');
  signal rd_gray : unsigned(C_AW downto 0) := (others => '0');

  signal rd_gray_meta : unsigned(C_AW downto 0) := (others => '0');
  signal rd_gray_sync : unsigned(C_AW downto 0) := (others => '0');
  signal wr_gray_meta : unsigned(C_AW downto 0) := (others => '0');
  signal wr_gray_sync : unsigned(C_AW downto 0) := (others => '0');

  signal rd_word : std_logic_vector(26 downto 0) := (others => '0');
  signal primed  : std_logic := '0';

  function f_gray (b : unsigned(C_AW downto 0)) return unsigned is
  begin
    return b xor shift_right(b, 1);
  end function f_gray;

  function f_bin (g : unsigned(C_AW downto 0)) return unsigned is
    variable b : unsigned(C_AW downto 0);
  begin
    b(C_AW) := g(C_AW);
    for i in C_AW - 1 downto 0 loop
      b(i) := b(i + 1) xor g(i);
    end loop;
    return b;
  end function f_bin;

begin

  p_src_rst : process (src_clk, rst_n) is
  begin
    if rst_n = '0' then
      src_rst_sr <= "11";
    elsif rising_edge(src_clk) then
      src_rst_sr <= src_rst_sr(0) & '0';
    end if;
  end process p_src_rst;

  p_pxl_rst : process (pxl_clk, rst_n) is
  begin
    if rst_n = '0' then
      pxl_rst_sr <= "11";
    elsif rising_edge(pxl_clk) then
      pxl_rst_sr <= pxl_rst_sr(0) & '0';
    end if;
  end process p_pxl_rst;

  p_wr : process (src_clk) is
    variable v_next : unsigned(C_AW downto 0);
    variable v_rd   : unsigned(C_AW downto 0);
    variable v_full : std_logic;
  begin
    if rising_edge(src_clk) then
      rd_gray_meta <= rd_gray;
      rd_gray_sync <= rd_gray_meta;

      if src_rst_sr(1) = '1' then
        wr_bin  <= (others => '0');
        wr_gray <= (others => '0');
      else
        v_rd   := f_bin(rd_gray_sync);
        v_next := wr_bin + 1;
        -- Full: next slot would overwrite the word the reader has not taken.
        if v_next(C_AW) /= v_rd(C_AW)
           and v_next(C_AW - 1 downto 0) = v_rd(C_AW - 1 downto 0) then
          v_full := '1';
        else
          v_full := '0';
        end if;

        if v_full = '0' then
          mem(to_integer(wr_bin(C_AW - 1 downto 0))) <=
            start_of_frame & v_sync & h_sync & video_in;
          wr_bin  <= v_next;
          wr_gray <= f_gray(v_next);
        end if;
      end if;
    end if;
  end process p_wr;

  p_rd : process (pxl_clk) is
    variable v_wr    : unsigned(C_AW downto 0);
    variable v_fill  : unsigned(C_AW downto 0);
    variable v_empty : std_logic;
  begin
    if rising_edge(pxl_clk) then
      wr_gray_meta <= wr_gray;
      wr_gray_sync <= wr_gray_meta;

      if pxl_rst_sr(1) = '1' then
        rd_bin  <= (others => '0');
        rd_gray <= (others => '0');
        primed  <= '0';
        rd_word <= (others => '0');
      else
        v_wr   := f_bin(wr_gray_sync);
        v_fill := v_wr - rd_bin;
        if wr_gray_sync = rd_gray then
          v_empty := '1';
        else
          v_empty := '0';
        end if;

        -- Wait until 8 words are in, then read one per HDMI clock.
        -- On underflow, hold the last pixel instead of blanking.
        if primed = '0' then
          if v_fill(C_AW - 1) = '1' then
            primed <= '1';
          end if;
        elsif v_empty = '0' then
          rd_word <= mem(to_integer(rd_bin(C_AW - 1 downto 0)));
          rd_bin  <= rd_bin + 1;
          rd_gray <= f_gray(rd_bin + 1);
        end if;
      end if;
    end if;
  end process p_rd;

  vid_pData  <= rd_word(23 downto 0);
  vid_pHSync <= rd_word(24);
  vid_pVSync <= rd_word(25);
  vid_pVDE   <= rd_word(26);

end architecture rtl;
