--------------------------------------------------------------------------------
-- CERN SY-RF-FB
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_cordic_pkg
--
-- authors:     Gregoire Hagmann <gregoire.hagmann@cern.ch>
--              John Molendijk (CERN)
--
-- description: Fully pipelined multifunction CORDIC code.
--
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
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package gc_cordic_pkg is

  subtype t_CORDIC_MODE is std_logic_vector(0 downto 0);
  subtype t_CORDIC_SUBMODE is std_logic_vector(1 downto 0);

  constant c_ANGLE_FORMAT_S8_7           : integer := 0;
  constant c_ANGLE_FORMAT_FULL_SCALE_180 : integer := 1;

  constant c_MODE_VECTOR : t_CORDIC_MODE := "0";
  constant c_MODE_ROTATE : t_CORDIC_MODE := "1";

  constant c_SUBMODE_CIRCULAR   : t_CORDIC_SUBMODE := "00";
  constant c_SUBMODE_LINEAR     : t_CORDIC_SUBMODE := "01";
  constant c_SUBMODE_HYPERBOLIC : t_CORDIC_SUBMODE := "11";

-- Used by CORDIC algo and init
-- Constant GHHfFReg    : Std_logic_vector(19 downto 1) := X"0000"&"000";
  constant c_DegPlus90    : signed(15 downto 0) := X"2D00";
  constant c_DegMinus90   : signed(15 downto 0) := X"D300";
  constant c_DegPlus180c  : signed(15 downto 0) := X"5A00";
  constant c_DegMinus180c : signed(15 downto 0) := X"A600";
-- Modulo 360 d constants
  constant c_DegPlus90_X  : signed(16 downto 0) := '0'&X"2D00";  --  +90 d
  constant c_DegMinus90_X : signed(16 downto 0) := '1'&X"D300";  --  -90 d
  constant c_DegPlus180   : signed(16 downto 0) := '0'&X"5A00";  -- +180 d
  constant c_DegMinus180  : signed(16 downto 0) := '1'&X"A600";  -- -180 d
  constant c_DegPlus360   : signed(16 downto 0) := '0'&X"B400";  -- +360 d
  constant c_DegMinus360  : signed(16 downto 0) := '1'&X"4C00";  -- -360 d
  constant c_DegZero      : signed(16 downto 0) := '0'&X"0000";  -- +000 d

-- Angle Constants for FS Angle format
  constant c_FSDegPlus90    : signed(15 downto 0) := X"4000";
  constant c_FSDegMinus90   : signed(15 downto 0) := X"C000";
  constant c_FSDegPlus180c  : signed(15 downto 0) := X"7FFF";
  constant c_FSDegMinus180c : signed(15 downto 0) := X"8000";
-- Modulo 360 d constants FS Angle format
  constant c_FSDegPlus90_X  : signed(16 downto 0) := '0'&X"4000";  --  +90 d
  constant c_FSDegMinus90_X : signed(16 downto 0) := '1'&X"C000";  --  -90 d
  constant c_FSDegPlus180   : signed(16 downto 0) := '0'&X"8000";  -- +180 d
  constant c_FSDegMinus180  : signed(16 downto 0) := '1'&X"8000";  -- -180 d
  constant c_FSDegPlus360   : signed(16 downto 0) := '0'&X"FFFF";  -- +360 d
  constant c_FSDegMinus360  : signed(16 downto 0) := '1'&X"0000";  -- -360 d
  constant c_FSDegZero      : signed(16 downto 0) := '0'&X"0000";  -- +000 d

--Constants for the generic HD module 360

  constant c_DegPlus90HD_X   : signed(32 downto 0) := '0'&X"2D000000";  -- +90 d
  constant c_DegMinus90HD_X  : signed(32 downto 0) := '1'&X"D3000000";  -- -90 d
  constant c_DegPlus180HD_X  : signed(32 downto 0) := '0'&X"5A000000";  -- +180 d
  constant c_DegMinus180HD_X : signed(32 downto 0) := '1'&X"A6000000";  -- -180 d
  constant c_DegPlus360HD_X  : signed(32 downto 0) := '0'&X"B4000000";  -- +360 d
  constant c_DegMinus360HD_X : signed(32 downto 0) := '1'&X"4C000000";  -- -360 d
  constant c_DegZeroHD_X     : signed(32 downto 0) := '0'&X"00000000";  -- +000 d

--Constants for the HD CorDic implementation
  constant c_DegPlus90HD   : signed(31 downto 0) := X"2D000000";
  constant c_DegMinus90HD  : signed(31 downto 0) := X"D3000000";
  constant c_DegPlus180HD  : signed(31 downto 0) := X"5A000000";
  constant c_DegMinus180HD : signed(31 downto 0) := X"A6000000";
  constant c_DegZeroHD     : signed(31 downto 0) := X"00000000";

--Constants for the generic HD module 360 FS Angle Format

  constant c_FSDegPlus90HD_X   : signed(32 downto 0) := '0'&X"40000000";  -- +90 d
  constant c_FSDegMinus90HD_X  : signed(32 downto 0) := '1'&X"C0000000";  -- -90 d
  constant c_FSDegPlus180HD_X  : signed(32 downto 0) := '0'&X"80000000";  -- +180 d
  constant c_FSDegMinus180HD_X : signed(32 downto 0) := '1'&X"80000000";  -- -180 d
  constant c_FSDegPlus360HD_X  : signed(32 downto 0) := '0'&X"ffffffff";  -- +360 d
  constant c_FSDegMinus360HD_X : signed(32 downto 0) := '1'&X"00000000";  -- -360 d
  constant c_FSDegZeroHD_X     : signed(32 downto 0) := '0'&X"00000000";  -- +000 d

--Constants for the HD CorDic implementation FS Angle Format
  constant c_FSDegPlus90HD   : signed(31 downto 0) := X"40000000";
  constant c_FSDegMinus90HD  : signed(31 downto 0) := X"C0000000";
  constant c_FSDegPlus180HD  : signed(31 downto 0) := X"7fffffff";
  constant c_FSDegMinus180HD : signed(31 downto 0) := X"80000000";
  constant c_FSDegZeroHD     : signed(31 downto 0) := X"00000000";

  function f_compute_an(nbits : integer) return std_logic_vector;

-- Cordic Sequencer Iteration Constants
  constant c_CirIter   : std_logic_vector(4 downto 0) := '0'&X"D";
  constant c_LinIter   : std_logic_vector(4 downto 0) := '0'&X"F";
-- Cordic Sequencer Iteration Constants for FS Angle format
  constant c_FSCirIter : std_logic_vector(4 downto 0) := '0'&X"F";

-- Unity Vector Length (0x7FFF) divided by An (=1.647)
-- This constant can be used to initialize X0 prior to a rotation by Z0
-- By initializing Y0 to 0x0000 we obtain Xn = cos(Z0) and Yn = sin(Z0)
-- (Xn,Yn) being a unit vector with angle Z0.
  constant c_UnByAn : std_logic_vector(15 downto 0) := X"4DB7";  --!! We may change this to 4DBA after verifications.

--AnHD = 1.6467602581210656483661780066297
--CorDicHD
  constant c_UnByAnHD : std_logic_vector(31 downto 0) := X"4DBA76D4";


  procedure f_limit_subtract
    (use_limiter :     boolean;
     a, b        : in  signed;
     o           : out signed;
     lim         : out std_logic);

  procedure f_limit_add
    (use_limiter :     boolean;
     a, b        : in  signed;
     o           : out signed;
     lim         : out std_logic);

  function f_limit_negate(
    use_limiter :    boolean;
    x           : in signed;
    neg         : in std_logic) return signed;

  function f_phi_lookup (
    stage        : integer;
    submode      : t_CORDIC_SUBMODE;
    angle_format : integer
    )
    return signed;

  function f_pick (cond     : boolean;
                   if_true  : signed;
                   if_false : signed) return signed;

end package;

package body gc_cordic_pkg is

  function f_compute_an(nbits : integer) return std_logic_vector is
    variable v_an : real := 1.0;
    variable v_ret : std_logic_vector(nbits-1 downto 0);
  begin
    for i in 0 to nbits-1 loop
      v_an := v_an * sqrt(1.0+2.0**(-2*i));
    end loop;
    v_ret := std_logic_vector(to_signed(integer((1.0/v_an)*(2.0**(nbits-1))), nbits));
    return v_ret;
  end function f_compute_an;


  procedure f_limit_subtract
    (use_limiter :     boolean;
     a, b        : in  signed;
     o           : out signed;
     lim         : out std_logic) is
    constant c_max_val : signed(o'range)           := ('0', others => '1');
    constant c_min_val : signed(o'range)           := ('1', others => '0');
    variable l_sum     : signed(O'length downto 0) := (others      => '0');
  begin
    l_sum := a(a'left)&a - b;

    if not use_limiter then
      o   := l_sum(o'range);
      lim := '0';
    -- value above maximum
    elsif l_sum(o'length) = '0' and l_sum(o'length-1) = '1' then
      o   := c_max_val;
      lim := '1';
    -- value below minimum
    elsif l_sum(o'length) = '1' and l_sum(o'length-1) = '0' then
      o   := c_min_val;
      lim := '1';
    else
      o   := l_sum(o'range);
      lim := '0';
    end if;
  end procedure;

  procedure f_limit_add
    (
      use_limiter :     boolean;
      a, b        : in  signed;
      o           : out signed;
      lim         : out std_logic) is
    constant c_max_val : signed(o'range)           := ('0', others => '1');
    constant c_min_val : signed(o'range)           := ('1', others => '0');
    variable l_sum     : signed(o'length downto 0) := (others      => '0');
  begin
    l_sum := a(a'left)&a + b;

    if not use_limiter then
      o   := l_sum(o'range);
      lim := '0';
    -- value above maximum
    elsif l_sum(o'length) = '0' and l_sum(o'length-1) = '1' then
      o   := c_max_val;
      lim := '1';
    -- value below minimum
    elsif l_sum(o'length) = '1' and l_sum(o'length-1) = '0' then
      o   := c_min_val;
      lim := '1';
    else
      o   := l_sum(o'range);
      lim := '0';
    end if;
  end procedure;

  function f_limit_negate(
    use_limiter :    boolean;
    x           : in signed;
    neg         : in std_logic) return signed is
    constant c_max_val : signed(x'range) := ('0', others => '1');
    constant c_min_val : signed(x'range) := ('1', others => '0');
  begin
    if neg = '1' then
      if x = c_min_val and use_limiter then
        return c_max_val;
      else
        return not x(x'length-1 downto 0)+1;
      end if;
    else
      return x;
    end if;
  end f_limit_negate;



  function f_phi_lookup (
    stage        : integer;
    submode      : t_CORDIC_SUBMODE;
    angle_format : integer
    ) return signed is

    type t_LUT is array(integer range<>) of signed(31 downto 0);

    constant c_LUT_LIN : t_LUT(0 to 31) := (
      X"7fffffff",
      X"40000000",
      X"20000000",
      X"10000000",
      X"08000000",
      X"04000000",
      X"02000000",
      X"01000000",
      X"00800000",
      X"00400000",
      X"00200000",
      X"00100000",
      X"00080000",
      X"00040000",
      X"00020000",
      X"00010000",
      X"00008000",
      X"00004000",
      X"00002000",
      X"00001000",
      X"00000800",
      X"00000400",
      X"00000200",
      X"00000100",
      X"00000080",
      X"00000040",
      X"00000020",
      X"00000010",
      X"00000008",
      X"00000004",
      X"00000002",
      X"00000001"
      );

    constant c_LUT_CIRC_A0 : t_LUT(0 to 31) := (
      X"16800000",
      X"0D485398",
      X"0704A3A0",
      X"03900089",
      X"01C9C553",
      X"00E51BCA",
      X"0072950D",
      X"00394B6B",
      X"001CA5D2",
      X"000E52EC",
      X"00072976",
      X"000394BB",
      X"0001CA5D",
      X"0000E52E",
      X"00007297",
      X"0000394B",
      X"00001CA5",
      X"00000E52",
      X"00000729",
      X"00000394",
      X"000001CA",
      X"000000E5",
      X"00000072",
      X"00000039",
      X"0000001C",
      X"0000000E",
      X"00000007",
      X"00000003",
      X"00000001",
      X"00000000",
      X"00000000",
      X"00000000"
      );

    constant c_LUT_CIRC_A1 : t_LUT(0 to 31) := (
      X"20000000",
      X"12E4051E",
      X"09FB385B",
      X"051111D4",
      X"028B0D43",
      X"0145D7E1",
      X"00A2F61E",
      X"00517C55",
      X"0028BE53",
      X"00145F2F",
      X"000A2F98",
      X"000517CC",
      X"00028BE6",
      X"000145F3",
      X"0000A2FA",
      X"0000517D",
      X"000028BE",
      X"0000145F",
      X"00000A30",
      X"00000518",
      X"0000028C",
      X"00000146",
      X"000000A3",
      X"00000051",
      X"00000029",
      X"00000014",
      X"0000000A",
      X"00000005",
      X"00000003",
      X"00000001",
      X"00000001",
      X"00000000"
      );

  begin

    if submode = c_SUBMODE_CIRCULAR then
      if angle_format = c_ANGLE_FORMAT_S8_7 then
        return c_LUT_CIRC_A0(stage);
      else
        return c_LUT_CIRC_A1(stage);
      end if;
    else
      return c_LUT_LIN(stage);
    end if;

  end f_phi_lookup;



  function f_pick (cond     : boolean;
                   if_true  : signed;
                   if_false : signed)return signed is
  begin
    if cond then
      return if_true;
    else
      return if_false;
    end if;
  end f_pick;

end package body;
