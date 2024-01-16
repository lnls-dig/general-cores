--------------------------------------------------------------------------------
-- CERN SY-RF-FB
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   cordic_modulo_360.vhd
--
-- authors:     Gregoire Hagmann <gregoire.hagmann@cern.ch>
--              John Molendijk (CERN)
--
-- description: Cordic first pipe stage, setting initial values depending on the
--              function to be calculated.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2020
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all;
library work;

use work.gc_cordic_pkg.all;

entity cordic_init is
  generic
    (
      g_M            : positive := 16;
      --  Default angle format S8.7 otherwise FS = 180 deg.
      g_ANGLE_FORMAT : integer
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

 

  x0_int <= signed(x0_i);
  y0_int <= signed(y0_i);
  z0_int <= signed(z0_i);

  process (clk_i)
  begin
    if rising_edge(clk_i) then

      x1_o <= std_logic_vector(x1_int);
      y1_o <= std_logic_vector(y1_int);
      z1_o <= std_logic_vector(z1_int);
      d1_o <= d1_int;
      
      if cor_mode_i = c_MODE_VECTOR and cor_submode_i = c_SUBMODE_CIRCULAR then

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
        elsif g_ANGLE_FORMAT = c_ANGLE_FORMAT_S8_7 and
          x0_int < c_DegZeroHD(31 downto 31 - (g_M - 1)) and
          y0_int >= c_DegZeroHD(31 downto 31 - (g_M - 1)) then
          x1_int <= y0_int;
          y1_int <= -x0_int;            -- not (X0) + 1;
          z1_int <= c_DegPlus90HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '0';
        elsif g_ANGLE_FORMAT = c_ANGLE_FORMAT_S8_7 and
          x0_int < c_DegZeroHD(31 downto 31 - (g_M - 1)) and
          y0_int < c_DegZeroHD(31 downto 31 - (g_M - 1)) then
          x1_int <= -y0_int;            -- not (Y0) + 1;
          y1_int <= x0_int;
          z1_int <= c_DegMinus90HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '1';
        elsif g_ANGLE_FORMAT = C_ANGLE_FORMAT_FULL_SCALE_180 and
          x0_int < c_FSDegZeroHD(31 downto 31 - (g_M - 1)) and
          y0_int >= c_FSDegZeroHD(31 downto 31 - (g_M - 1)) then
          x1_int <= y0_int;
          y1_int <= -x0_int;            -- not (X0) + 1;
          z1_int <= c_FSDegPlus90HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '0';
        elsif g_ANGLE_FORMAT = C_ANGLE_FORMAT_FULL_SCALE_180 and
          x0_int < c_FSDegZeroHD(31 downto 31 - (g_M - 1)) and
          y0_int < c_FSDegZeroHD(31 downto 31 - (g_M - 1)) then
          x1_int <= -y0_int;            -- not (Y0) + 1;
          y1_int <= x0_int;
          z1_int <= c_FSDegMinus90HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '1';
        end if;

      elsif cor_mode_i = c_MODE_ROTATE and cor_submode_i = c_SUBMODE_CIRCULAR then

        if g_ANGLE_FORMAT = c_ANGLE_FORMAT_S8_7 and
          z0_int <= c_DegPlus90HD_X(32 downto 32 - g_M) and
          z0_int >= c_DegZeroHD_X(32 downto 32 - g_M) then
          x1_int <= x0_int;
          y1_int <= y0_int;
          z1_int <= z0_int;
          d1_int <= '1';
        elsif g_ANGLE_FORMAT = c_ANGLE_FORMAT_S8_7 and
          z0_int < c_DegZeroHD_X(32 downto 32 - g_M) and
          z0_int >= c_DegMinus90HD_X(32 downto 32 - g_M) then
          x1_int <= x0_int;
          y1_int <= y0_int;
          z1_int <= z0_int;
          d1_int <= '0';
        elsif g_ANGLE_FORMAT = c_ANGLE_FORMAT_S8_7 and
          z0_int < c_DegMinus90HD_X(32 downto 32 - g_M) and
          z0_int >= c_DegMinus180HD_X(32 downto 32 - g_M) then
          x1_int <= y0_int;
          y1_int <= -x0_int;            -- not (X0) + 1;
          z1_int <= c_DegPlus90HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '0';
        elsif g_ANGLE_FORMAT = c_ANGLE_FORMAT_S8_7 and
          z0_int <= c_DegPlus180HD_X(32 downto 32 - g_M) and
          z0_int > c_DegPlus90HD_X(32 downto 32 - g_M) then
          x1_int <= -y0_int;            --not (Y0) + 1;
          y1_int <= x0_int;
          z1_int <= c_DegMinus90HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '1';
        elsif g_ANGLE_FORMAT = c_ANGLE_FORMAT_S8_7 and
          z0_int < c_DegMinus180HD_X(32 downto 32 - g_M) then
          x1_int <= -x0_int;            --not (X0) + 1;
          y1_int <= -y0_int;            --not (Y0) + 1;
          z1_int <= c_DegPlus180HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '0';
        elsif g_ANGLE_FORMAT = c_ANGLE_FORMAT_S8_7 and
          z0_int > c_DegPlus180HD_X(32 downto 32 - g_M) then
          x1_int <= -x0_int;            -- not (X0) + 1;
          y1_int <= -y0_int;            --not (Y0) + 1;
          z1_int <= c_DegMinus180HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '1';
        elsif g_ANGLE_FORMAT = C_ANGLE_FORMAT_FULL_SCALE_180 and
          z0_int <= c_FSDegPlus90HD_X(32 downto 32 - g_M) and
          z0_int >= c_FSDegZeroHD_X(32 downto 32 - g_M) then
          x1_int <= x0_int;
          y1_int <= y0_int;
          z1_int <= z0_int;
          d1_int <= '1';
        elsif g_ANGLE_FORMAT = C_ANGLE_FORMAT_FULL_SCALE_180 and
          z0_int < c_FSDegZeroHD_X(32 downto 32 - g_M) and
          z0_int >= c_FSDegMinus90HD_X(32 downto 32 - g_M) then
          x1_int <= x0_int;
          y1_int <= y0_int;
          z1_int <= z0_int;
          d1_int <= '0';
        elsif g_ANGLE_FORMAT = C_ANGLE_FORMAT_FULL_SCALE_180 and
          z0_int < c_FSDegMinus90HD_X(32 downto 32 - g_M) and
          z0_int >= c_FSDegMinus180HD_X(32 downto 32 - g_M) then
          x1_int <= y0_int;
          y1_int <= -x0_int;            --not (X0) + 1;
          z1_int <= c_FSDegPlus90HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '0';
        elsif g_ANGLE_FORMAT = C_ANGLE_FORMAT_FULL_SCALE_180 and
          z0_int <= c_FSDegPlus180HD_X(32 downto 32 - g_M) and
          z0_int > c_FSDegPlus90HD_X(32 downto 32 - g_M) then
          x1_int <= -y0_int;            --not (Y0) + 1;
          y1_int <= x0_int;
          z1_int <= c_FSDegMinus90HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '1';
        elsif g_ANGLE_FORMAT = C_ANGLE_FORMAT_FULL_SCALE_180 and
          z0_int < c_FSDegMinus180HD_X(32 downto 32 - g_M) then
          x1_int <= -x0_int;            --not (X0) + 1;
          y1_int <= -y0_int;            --not (Y0) + 1;
          z1_int <= c_FSDegPlus180HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '0';
        elsif g_ANGLE_FORMAT = C_ANGLE_FORMAT_FULL_SCALE_180 and
          z0_int > c_FSDegPlus180HD_X(32 downto 32 - g_M) then
          x1_int <= -x0_int;            --not (X0) + 1;
          y1_int <= -y0_int;            --not (Y0) + 1;
          z1_int <= c_FSDegMinus180HD_X(32 downto 32 - g_M) + z0_int;
          d1_int <= '1';
        end if;
      elsif cor_mode_i = c_MODE_VECTOR and cor_submode_i = c_SUBMODE_LINEAR then
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

      elsif cor_mode_i = c_MODE_ROTATE and cor_submode_i = c_SUBMODE_LINEAR then
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
  end process;

end rtl;
