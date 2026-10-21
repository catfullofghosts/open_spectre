library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Turns a wipe coordinate into a 12-bit mix alpha.
-- alpha 0 = full A, 4095 = full B.
--
-- softness 0 is a hard cut at `pos` (coord < pos is B).
-- softness > 0 ramps across that many pixels, centred on `pos`.
-- mix_mode ignores the coordinate and uses pos as the alpha (clamped to 4095).
-- invert swaps A and B.
--
-- The 1/softness scale is a reciprocal, refreshed in the background when
-- softness changes (about 25 clocks). Until it lands, the edge stays hard.
-- Latency is 3 clocks.

entity wipe_soft_edge is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    coord    : in  std_logic_vector(12 downto 0);
    pos      : in  std_logic_vector(12 downto 0);
    soft     : in  std_logic_vector(11 downto 0);
    mix_mode : in  std_logic;
    invert   : in  std_logic;
    alpha    : out std_logic_vector(11 downto 0)
  );
end entity wipe_soft_edge;

architecture rtl of wipe_soft_edge is

  signal recip     : unsigned(24 downto 0) := (others => '0');
  signal div_busy  : std_logic := '0';
  signal div_bit   : integer range 0 to 24 := 0;
  signal div_rem   : unsigned(24 downto 0) := (others => '0');
  signal div_quot  : unsigned(24 downto 0) := (others => '0');
  signal div_soft  : unsigned(11 downto 0) := (others => '0');
  signal soft_done : unsigned(11 downto 0) := (others => '0');

  signal s1_span   : unsigned(11 downto 0) := (others => '0');
  signal s1_mix_a  : unsigned(11 downto 0) := (others => '0');
  signal s1_hard_a : unsigned(11 downto 0) := (others => '0');
  signal s1_mix    : std_logic := '0';
  signal s1_hard   : std_logic := '0';
  signal s1_full   : std_logic := '0';
  signal s1_zero   : std_logic := '0';
  signal s1_inv    : std_logic := '0';

  signal s2_prod   : unsigned(36 downto 0) := (others => '0');
  signal s2_mix_a  : unsigned(11 downto 0) := (others => '0');
  signal s2_hard_a : unsigned(11 downto 0) := (others => '0');
  signal s2_mix    : std_logic := '0';
  signal s2_hard   : std_logic := '0';
  signal s2_full   : std_logic := '0';
  signal s2_zero   : std_logic := '0';
  signal s2_inv    : std_logic := '0';

  function f_apply_inv (a : unsigned(11 downto 0); inv : std_logic) return unsigned is
  begin
    if inv = '1' then
      return to_unsigned(4095, 12) - a;
    else
      return a;
    end if;
  end function f_apply_inv;

begin

  -- recip = floor(2^24 / softness). Pixel ramp uses (span * recip) >> 12.
  p_recip : process (clk) is
    variable rem_v  : unsigned(24 downto 0);
    variable quot_v : unsigned(24 downto 0);
    variable nbit   : std_logic;
    variable soft_u : unsigned(11 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        recip     <= (others => '0');
        div_busy  <= '0';
        div_bit   <= 0;
        div_rem   <= (others => '0');
        div_quot  <= (others => '0');
        div_soft  <= (others => '0');
        soft_done <= (others => '0');
      else
        soft_u := unsigned(soft);
        if div_busy = '0' then
          if soft_u /= soft_done then
            soft_done <= soft_u;
            if soft_u = 0 then
              recip <= (others => '0');
            else
              div_busy <= '1';
              div_soft <= soft_u;
              div_rem  <= (others => '0');
              div_quot <= (others => '0');
              div_bit  <= 24;
            end if;
          end if;
        elsif soft_u /= div_soft then
          div_soft <= soft_u;
          div_rem  <= (others => '0');
          div_quot <= (others => '0');
          div_bit  <= 24;
          if soft_u = 0 then
            div_busy  <= '0';
            recip    <= (others => '0');
            soft_done <= (others => '0');
          end if;
        else
          if div_bit = 24 then
            nbit := '1';
          else
            nbit := '0';
          end if;
          rem_v  := div_rem(23 downto 0) & nbit;
          quot_v := div_quot(23 downto 0) & '0';
          if rem_v >= resize(div_soft, 25) then
            rem_v    := rem_v - resize(div_soft, 25);
            quot_v(0) := '1';
          end if;
          if div_bit = 0 then
            recip    <= quot_v;
            div_busy <= '0';
          else
            div_rem  <= rem_v;
            div_quot <= quot_v;
            div_bit  <= div_bit - 1;
          end if;
        end if;
      end if;
    end if;
  end process p_recip;

  p_edge : process (clk) is
    variable sum_v  : unsigned(13 downto 0);
    variable diff_v : signed(14 downto 0);
    variable soft_u : unsigned(11 downto 0);
    variable pos_u  : unsigned(12 downto 0);
    variable co_u   : unsigned(12 downto 0);
    variable mag    : unsigned(12 downto 0);
    variable out_a  : unsigned(11 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        s1_span   <= (others => '0');
        s1_mix_a  <= (others => '0');
        s1_hard_a <= (others => '0');
        s1_mix    <= '0';
        s1_hard   <= '1';
        s1_full   <= '0';
        s1_zero   <= '1';
        s1_inv    <= '0';
        s2_prod   <= (others => '0');
        s2_mix_a  <= (others => '0');
        s2_hard_a <= (others => '0');
        s2_mix    <= '0';
        s2_hard   <= '1';
        s2_full   <= '0';
        s2_zero   <= '1';
        s2_inv    <= '0';
        alpha     <= (others => '0');
      else
        soft_u := unsigned(soft);
        pos_u  := unsigned(pos);
        co_u   := unsigned(coord);

        if pos_u > 4095 then
          s1_mix_a <= to_unsigned(4095, 12);
        else
          s1_mix_a <= pos_u(11 downto 0);
        end if;

        if co_u < pos_u then
          s1_hard_a <= to_unsigned(4095, 12);
        else
          s1_hard_a <= (others => '0');
        end if;

        s1_mix  <= mix_mode;
        s1_inv  <= invert;
        s1_hard <= '0';
        s1_full <= '0';
        s1_zero <= '0';
        s1_span <= (others => '0');

        if (mix_mode = '1') or (soft_u = 0) or (recip = 0) then
          s1_hard <= '1';
        else
          sum_v  := resize(pos_u, 14) + resize(soft_u(11 downto 1), 14);
          diff_v := signed(resize(sum_v, 15)) - signed(resize(co_u, 15));
          if diff_v <= 0 then
            s1_zero <= '1';
          elsif diff_v >= signed(resize(soft_u, 15)) then
            s1_full <= '1';
          else
            s1_span <= unsigned(diff_v(11 downto 0));
          end if;
        end if;

        s2_prod   <= s1_span * recip;
        s2_mix_a  <= s1_mix_a;
        s2_hard_a <= s1_hard_a;
        s2_mix    <= s1_mix;
        s2_hard   <= s1_hard;
        s2_full   <= s1_full;
        s2_zero   <= s1_zero;
        s2_inv    <= s1_inv;

        mag := s2_prod(24 downto 12);
        if s2_mix = '1' then
          out_a := s2_mix_a;
        elsif (s2_hard = '1') then
          out_a := s2_hard_a;
        elsif s2_zero = '1' then
          out_a := (others => '0');
        elsif (s2_full = '1') or (mag > 4095) then
          out_a := to_unsigned(4095, 12);
        else
          out_a := mag(11 downto 0);
        end if;
        alpha <= std_logic_vector(f_apply_inv(out_a, s2_inv));
      end if;
    end if;
  end process p_edge;

end architecture rtl;
