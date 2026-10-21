library ieee;
use ieee.std_logic_1164.all;

-- 8-bit RGB mix of two pixels.
-- alpha 0 = video A, 4095 = video B.
-- out = A + (B - A) * alpha / 4096, per channel.
--
-- The blend itself is three AlphaBlend modules, one per colour, with the
-- 8-bit channel parked in the top of the 12-bit port. Alpha 0 and 4095
-- bypass that blend so a hard wipe is the exact source pixel. The bypass
-- shift register matches AlphaBlend, whose result is 4 clocks after it
-- samples the pixel.

entity video_ab_mix is
  port (
    clk     : in  std_logic;
    video_a : in  std_logic_vector(23 downto 0);
    video_b : in  std_logic_vector(23 downto 0);
    alpha   : in  std_logic_vector(11 downto 0);
    video_o : out std_logic_vector(23 downto 0)
  );
end entity video_ab_mix;

architecture rtl of video_ab_mix is

  signal ar, ag, ab : std_logic_vector(11 downto 0);
  signal br, bg, bb : std_logic_vector(11 downto 0);
  signal yr, yg, yb : std_logic_vector(11 downto 0);
  signal blended    : std_logic_vector(23 downto 0);

  signal a0, a1, a2, a3, a4 : std_logic_vector(23 downto 0) := (others => '0');
  signal b0, b1, b2, b3, b4 : std_logic_vector(23 downto 0) := (others => '0');
  signal p0, p1, p2, p3, p4 : std_logic_vector(11 downto 0) := (others => '0');

begin

  p_align : process (clk) is
  begin
    if rising_edge(clk) then
      a0 <= video_a;
      a1 <= a0;
      a2 <= a1;
      a3 <= a2;
      a4 <= a3;

      b0 <= video_b;
      b1 <= b0;
      b2 <= b1;
      b3 <= b2;
      b4 <= b3;

      p0 <= alpha;
      p1 <= p0;
      p2 <= p1;
      p3 <= p2;
      p4 <= p3;
    end if;
  end process p_align;

  ar <= video_a(7 downto 0)   & "0000";
  ag <= video_a(15 downto 8)  & "0000";
  ab <= video_a(23 downto 16) & "0000";
  br <= video_b(7 downto 0)   & "0000";
  bg <= video_b(15 downto 8)  & "0000";
  bb <= video_b(23 downto 16) & "0000";

  blend_r : entity work.AlphaBlend
    generic map (G_SIGNED => false)
    port map (clk => clk, signal1 => ar, signal2 => br, alpha => alpha, result => yr);

  blend_g : entity work.AlphaBlend
    generic map (G_SIGNED => false)
    port map (clk => clk, signal1 => ag, signal2 => bg, alpha => alpha, result => yg);

  blend_b : entity work.AlphaBlend
    generic map (G_SIGNED => false)
    port map (clk => clk, signal1 => ab, signal2 => bb, alpha => alpha, result => yb);

  blended <= yb(11 downto 4) & yg(11 downto 4) & yr(11 downto 4);

  video_o <= a4 when p4 = x"000" else
             b4 when p4 = x"FFF" else
             blended;

end architecture rtl;
