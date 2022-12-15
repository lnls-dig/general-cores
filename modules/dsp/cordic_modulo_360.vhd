-- Angle normalization (Mod-360 degree)

-- If the angle_i argument is greater or smaller than +/-180deg.
-- the system subtracts or adds 360 degrees such that the result
-- lies again within the +/-180 degree range.
-- The number of g_M is by default 16 and can be max. 32 bit number.
-- Within the 32-bit range the number will correctly fit within a sign,
-- 8b Mantissa & 23b Fractional part. Changing the value g_M will only affect
-- to the fractional bits. This option can be selected with the g_ANGLE_MODE to
-- S8_7.

-- On the other hand, when the generic value g_ANGLE_MODE is set to FULL_SCALE the
-- modulo360 block can be used with an angle format maximum of Q1.31 with a sign
-- extension. This format gives a normalized signed representation with fixed
-- fractional bits according to the value of g_M. Changing the value of g_M will
-- affect to the amount of fractional bits. Full-scale format 180 degrees is
-- acquired in this way.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gc_cordic_pkg.all;

entity cordic_modulo_360 is
  generic(
    g_M          : positive := 16;
    g_ANGLE_MODE : t_CORDIC_ANGLE_FORMAT
    );
  port (
    cor_submode_i : in t_CORDIC_SUBMODE;

    angle_i : in  std_logic_vector(g_M downto 0);
    angle_o : out std_logic_vector(g_M-1 downto 0);
    lim_o   : out std_logic
    );

end entity;

architecture rtl of cordic_modulo_360 is



  signal gt, lt : std_logic;

  constant c_M180D : signed(g_M downto 0) :=
    f_pick(g_ANGLE_MODE = S8_7, c_DegMinus180HD_X(32 downto 32 - g_M), c_FSDegMinus180HD_X(32 downto 32-g_M));

  constant c_P180D : signed(g_M downto 0) :=
    f_pick(g_ANGLE_MODE = S8_7, c_DegPlus180HD_X(32 downto 32 - g_M), c_FSDegPlus180HD_X(32 downto 32-g_M));


  constant c_OFFS_ZERO : signed(g_M downto 0) :=
    f_pick(g_ANGLE_MODE = S8_7, c_DegZeroHD_X(32 downto 32 - g_M), c_FSDegZeroHD_X(32 downto 32 - g_M));

  constant c_OFFS_P360D : signed(g_M downto 0) :=
    f_pick(g_ANGLE_MODE = S8_7, c_DegPlus360HD_X(32 downto 32 - g_M), c_FSDegPlus360HD_X(32 downto 32 - g_M));

  constant c_OFFS_N360D : signed(g_M downto 0) :=
    f_pick(g_ANGLE_MODE = S8_7, c_DegMinus360HD_X(32 downto 32 - g_M), c_FSDegMinus360HD_X(32 downto 32 - g_M));


begin

  process(angle_i)
  begin
    if signed(angle_i) < c_M180D then
      lt <= '1';
    else
      lt <= '0';
    end if;

    if signed(angle_i) > c_P180D then
      gt <= '1';
    else
      gt <= '0';
    end if;
  end process;

  process(lt, gt, angle_i, cor_submode_i)
    variable angle_out : signed(g_M downto 0);
    variable lim_out   : std_logic;
  begin
    if cor_submode_i = CIRCULAR then
      if(lt = '1' and gt = '0') then
        f_limit_add(signed(angle_i), c_OFFS_P360D, angle_out, lim_out);
      elsif (lt = '0' and gt = '1') then
        f_limit_add(signed(angle_i), c_OFFS_N360D, angle_out, lim_out);
      else
        f_limit_add(signed(angle_i), c_OFFS_ZERO, angle_out, lim_out);
      end if;
    else
      f_limit_add(signed(angle_i), to_signed(0, g_M), angle_out, lim_out);
    end if;

    angle_o <= std_logic_vector(angle_out(g_M-1 downto 0));
    lim_o   <= lim_out;

  end process;


end rtl;

