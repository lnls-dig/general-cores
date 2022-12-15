
library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
library work;

use work.gc_cordic_pkg.all;

entity cordic_init is
  generic
    (
      g_M          : positive              := 16;
      --  Default angle format S8.7 otherwise FS = 180 deg.
      g_ANGLE_MODE : t_CORDIC_ANGLE_FORMAT := S8_7
      );
  port (
    clk_i         : in  std_logic;
    rst_i         : in  std_logic;
    cor_mode_i    : in  t_CORDIC_MODE;
    cor_submode_i : in  t_CORDIC_SUBMODE;
    x0_i          : in  std_logic_vector(g_M - 1 downto 0);
    y0_i          : in  std_logic_vector(g_M - 1 downto 0);
    z0_i          : in  std_logic_vector(g_M downto 0);
    x1_o          : out std_logic_vector(g_M - 1 downto 0);
    y1_o          : out std_logic_vector(g_M - 1 downto 0);
    z1_o          : out std_logic_vector(g_M downto 0);
    d1_o          : out std_logic
    );

end cordic_init;


architecture rtl of cordic_init is

  signal x0_int, y0_int, x1_int, y1_int : signed (g_M-1 downto 0);
  signal z0_int, z1_int                 : signed (g_M downto 0);
  signal d1_int                         : std_logic;

begin

  process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        x1_int <= x0_int;
        y1_int <= y0_int;
        z1_int <= z0_int;
        d1_int <= '0';
      else
        x1_int <= x0_int;
        y1_int <= y0_int;
        z1_int <= z0_int;
        d1_int <= '1';

        
        if cor_mode_i = VECTOR and cor_submode_i = CIRCULAR then

          if x0_int >= c_DegZeroHD(31 downto 31 - (g_M - 1)) and
            y0_int >= c_DegZeroHD(31 downto 31 - (g_M - 1)) then
            x1_int <= x0_int;
            y1_int <= y0_int;
            z1_int <= z0_int;
            d1_int <= '0';
          elsif x0_int >= c_DegZeroHD(31 downto 31 - (g_M - 1)) and
            y0_int < c_DegZeroHD(31 downto 31 - (g_M - 1)) then
            x1_int <= x0_int;
            y1_int <= y0_int;
            z1_int <= z0_int;
            d1_int <= '1';
          elsif g_ANGLE_MODE = S8_7 and
            x0_int < c_DegZeroHD(31 downto 31 - (g_M - 1)) and
            y0_int >= c_DegZeroHD(31 downto 31 - (g_M - 1)) then
            x1_int <= y0_int;
            y1_int <= -x0_int;          -- not (X0) + 1;
            z1_int <= c_DegPlus90HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '0';
          elsif g_ANGLE_MODE = S8_7 and
            x0_int < c_DegZeroHD(31 downto 31 - (g_M - 1)) and
            y0_int < c_DegZeroHD(31 downto 31 - (g_M - 1)) then
            x1_int <= -y0_int;          -- not (Y0) + 1;
            y1_int <= x0_int;
            z1_int <= c_DegMinus90HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '1';
          elsif g_ANGLE_MODE = FULL_SCALE_180 and
            x0_int < c_FSDegZeroHD(31 downto 31 - (g_M - 1)) and
            y0_int >= c_FSDegZeroHD(31 downto 31 - (g_M - 1)) then
            x1_int <= y0_int;
            y1_int <= -x0_int;          -- not (X0) + 1;
            z1_int <= c_FSDegPlus90HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '0';
          elsif g_ANGLE_MODE = FULL_SCALE_180 and
            x0_int < c_FSDegZeroHD(31 downto 31 - (g_M - 1)) and
            y0_int < c_FSDegZeroHD(31 downto 31 - (g_M - 1)) then
            x1_int <= -y0_int;          -- not (Y0) + 1;
            y1_int <= x0_int;
            z1_int <= c_FSDegMinus90HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '1';
          end if;

        elsif cor_mode_i = ROTATE and cor_submode_i = CIRCULAR then

          if g_ANGLE_MODE = S8_7 and
            z0_int <= c_DegPlus90HD_X(32 downto 32 - g_M) and
            z0_int >= c_DegZeroHD_X(32 downto 32 - g_M) then
            x1_int <= x0_int;
            y1_int <= y0_int;
            z1_int <= z0_int;
            d1_int <= '1';
          elsif g_ANGLE_MODE = S8_7 and
            z0_int < c_DegZeroHD_X(32 downto 32 - g_M) and
            z0_int >= c_DegMinus90HD_X(32 downto 32 - g_M) then
            x1_int <= x0_int;
            y1_int <= y0_int;
            z1_int <= z0_int;
            d1_int <= '0';
          elsif g_ANGLE_MODE = S8_7 and
            z0_int < c_DegMinus90HD_X(32 downto 32 - g_M) and
            z0_int >= c_DegMinus180HD_X(32 downto 32 - g_M) then
            x1_int <= y0_int;
            y1_int <= -x0_int;          -- not (X0) + 1;
            z1_int <= c_DegPlus90HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '0';
          elsif g_ANGLE_MODE = S8_7 and
            z0_int <= c_DegPlus180HD_X(32 downto 32 - g_M) and
            z0_int > c_DegPlus90HD_X(32 downto 32 - g_M) then
            x1_int <= -y0_int;          --not (Y0) + 1;
            y1_int <= x0_int;
            z1_int <= c_DegMinus90HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '1';
          elsif g_ANGLE_MODE = S8_7 and
            z0_int < c_DegMinus180HD_X(32 downto 32 - g_M) then
            x1_int <= -x0_int;          --not (X0) + 1;
            y1_int <= -y0_int;          --not (Y0) + 1;
            z1_int <= c_DegPlus180HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '0';
          elsif g_ANGLE_MODE = S8_7 and
            z0_int > c_DegPlus180HD_X(32 downto 32 - g_M) then
            x1_int <= -x0_int;          -- not (X0) + 1;
            y1_int <= -y0_int;          --not (Y0) + 1;
            z1_int <= c_DegMinus180HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '1';
          elsif g_ANGLE_MODE = FULL_SCALE_180 and
            z0_int <= c_FSDegPlus90HD_X(32 downto 32 - g_M) and
            z0_int >= c_FSDegZeroHD_X(32 downto 32 - g_M) then
            x1_int <= x0_int;
            y1_int <= y0_int;
            z1_int <= z0_int;
            d1_int <= '1';
          elsif g_ANGLE_MODE = FULL_SCALE_180 and
            z0_int < c_FSDegZeroHD_X(32 downto 32 - g_M) and
            z0_int >= c_FSDegMinus90HD_X(32 downto 32 - g_M) then
            x1_int <= x0_int;
            y1_int <= y0_int;
            z1_int <= z0_int;
            d1_int <= '0';
          elsif g_ANGLE_MODE = FULL_SCALE_180 and
            z0_int < c_FSDegMinus90HD_X(32 downto 32 - g_M) and
            z0_int >= c_FSDegMinus180HD_X(32 downto 32 - g_M) then
            x1_int <= y0_int;
            y1_int <= -x0_int;          --not (X0) + 1;
            z1_int <= c_FSDegPlus90HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '0';
          elsif g_ANGLE_MODE = FULL_SCALE_180 and
            z0_int <= c_FSDegPlus180HD_X(32 downto 32 - g_M) and
            z0_int > c_FSDegPlus90HD_X(32 downto 32 - g_M) then
            x1_int <= -y0_int;          --not (Y0) + 1;
            y1_int <= x0_int;
            z1_int <= c_FSDegMinus90HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '1';
          elsif g_ANGLE_MODE = FULL_SCALE_180 and
            z0_int < c_FSDegMinus180HD_X(32 downto 32 - g_M) then
            x1_int <= -x0_int;          --not (X0) + 1;
            y1_int <= -y0_int;          --not (Y0) + 1;
            z1_int <= c_FSDegPlus180HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '0';
          elsif g_ANGLE_MODE = FULL_SCALE_180 and
            z0_int > c_FSDegPlus180HD_X(32 downto 32 - g_M) then
            x1_int <= -x0_int;          --not (X0) + 1;
            y1_int <= -y0_int;          --not (Y0) + 1;
            z1_int <= c_FSDegMinus180HD_X(32 downto 32 - g_M) + z0_int;
            d1_int <= '1';
          end if;
        elsif cor_mode_i = VECTOR and cor_submode_i = LINEAR then
          if y0_int >= c_DegZeroHD(31 downto 31 - (g_M - 1)) then
            x1_int <= x0_int;
            y1_int <= y0_int;
            z1_int <= z0_int;
            d1_int <= '0';
          elsif
            y0_int < c_DegZeroHD(31 downto 31 - (g_M - 1)) then
            x1_int <= x0_int;
            y1_int <= y0_int;
            z1_int <= z0_int;
            d1_int <= '1';
          end if;

        elsif cor_mode_i = ROTATE and cor_submode_i = LINEAR then
          if z0_int >= c_DegZeroHD_X(32 downto 32 - g_M) then
            x1_int <= x0_int;
            y1_int <= y0_int;
            z1_int <= z0_int;
            d1_int <= '1';
          elsif z0_int < c_DegZeroHD_X(32 downto 32 - g_M) then
            x1_int <= x0_int;
            y1_int <= y0_int;
            z1_int <= z0_int;
            d1_int <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

end rtl;
