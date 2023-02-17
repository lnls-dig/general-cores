--------------------------------------------------------------------------------
-- CERN SY-RF-FB
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_cordic_top
--
-- authors:     Nathan Pittet (nathan.pittet@solidwatts.ch) based on the work of
--              Gregoire Hagmann <gregoire.hagmann@cern.ch> and 
--              John Molendijk (CERN)
--
-- description: Pipelined cordic. This implementation aims at removing the few 
--              small quirks from the previous one:
--                - 32 bits limitation being one,
--                - non-propagation of the cor_submode and cor_mode signals
--                - only half of the full scale being available
--                - Removing the absolutely useless g_ANGLE_FORMAT = s8.7
--                - Proper behaviour upon reset
--
--              Data is available after g_ITERATIONS+1 clk periods at the output.
--
--
-- functionnality and limitations
-- in the following assume K ~= 1.6467
-- in the following assume FS = 2**(g_WIDTH-1)-1
--
-- rotate / circular
-- inputs limitations : 
--   - sqrt(x*x + y*y) < FS/K
--   - -FS < z < +FS
-- outputs :
--   - x_o = K*FS*(x*cos(z)-y*sin(z)) (-FS <= x_o <= +FS)
--   - y_o = K*FS*(y*cos(z)+y*sin(z)) (-FS <= x_o <= +FS)
--   - z_o = 0
--
-- vector / circular
-- inputs limitations
--   - avoid small x and y values because the error grows quite large
--   - sqrt(x*x + y*y) < FS/K
--   - -FS < z < +FS
-- outputs
--   - x_o = K*sqrt(x*x+y*y) (0 <= x_o <= +FS)
--   - y_o = 0
--   - z_o = z + atan(y/x) (-FS <= z_o <= +FS)
--
-- rotate / linear
-- inputs limitations
--   - don't use this mode. not reliable. overflows happen in the
--     computation using python, no way around it.
-- outputs:
--   - x_o = x
--   - y_o = y + x*z/FS (-FS <= y_o <= +FS)
--   - z_o = 0
--
-- vector / linear
-- input limitations
--   - avoid small x and y (< 10% FS) because the error will grow large
--   - avoid x close to 0 obviously
--   - abs(z) < (1 - y/x)*FS so that the block does not overflows
-- x_o = x
-- y_o = 0
-- z_o = z + y/x*FS (-FS <= z_o <= +FS)
--
-- rotate / hyperbolic
--   untested
-- vector / hyperbolic
--   untested
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

--------------------------------------------------------------------------------
--
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.gc_cordic_pkg.all;

entity gc_cordic_top is
  generic
  (
    -- Word-width
    g_WIDTH : integer := 16;
    -- Number of pipeline stages
    g_ITERATIONS : integer := 16
  );
  port
  (
    clk_i : in std_logic;
    rst_i : in std_logic;

    -- Mode of operation. Two have been tested/are supported:
    -- MODE = ROTATE, SUBMODE = CIRCULAR: mag/phase -> sin/cos
    -- MODE = VECTOR, SUBMODE = CIRCULAR: sin/cos   -> mag/phase
    -- The other mode combinations may work, but have not been tested.
    mode_i : in t_CORDIC_MODE;
    submode_i : in t_CORDIC_SUBMODE;
  

    x_i : in std_logic_vector(g_WIDTH-1 downto 0);
    y_i : in std_logic_vector(g_WIDTH-1 downto 0);
    z_i : in std_logic_vector(g_WIDTH-1 downto 0);
    valid_i : in std_logic;

    lim_x_o : out std_logic; -- '1' when saturation happened. You may not want to 
    lim_y_o : out std_logic; -- trust the result in this case.
    x_o : out std_logic_vector(g_WIDTH-1 downto 0);
    y_o : out std_logic_vector(g_WIDTH-1 downto 0);
    z_o : out std_logic_vector(g_WIDTH-1 downto 0);
    valid_o : out std_logic;
    mode_o : out t_CORDIC_MODE;
    submode_o : out t_CORDIC_SUBMODE

  );
end entity gc_cordic_top;

architecture rtl of gc_cordic_top is
  type t_CORDIC_STV is record
    x : signed(g_WIDTH-1 downto 0);
    y : signed(g_WIDTH-1 downto 0);
    z : signed(g_WIDTH-1 downto 0);
    valid : std_logic;
    lim_x : std_logic;
    lim_y : std_logic;
    mode : t_CORDIC_MODE;
    submode : t_CORDIC_SUBMODE;
  end record;
  constant c_CORDIC_DEFAULT : t_CORDIC_STV := (x => (others => '0'),
                                               y => (others => '0'),
                                               z => (others => '0'), 
                                               valid => '0',
                                               lim_x => '0',
                                               lim_y => '0',
                                               mode => c_MODE_ROTATE,
                                               submode => c_SUBMODE_CIRCULAR);

  type t_CORDIC_ARRAY is array(natural range <>) of t_CORDIC_STV;
  
  signal s_cordic_init : t_CORDIC_STV;
  signal s_stg : t_CORDIC_ARRAY(0 to g_ITERATIONS) := (others => c_CORDIC_DEFAULT);
  signal s_di : std_logic_vector(g_ITERATIONS-1 downto 0) := (others => '0');
  constant c_FS : real := 2.0**(g_WIDTH-1)-1.0;
  
  function f_shift(inp : signed; i : integer) return signed is
    variable v_ret : signed(inp'range);
  begin
    if i >= inp'left then
      v_ret := (others => '0');
    else
      v_ret := resize(inp(inp'length-1 downto i), inp'length);
    end if;
    return v_ret;
  end function f_shift;
    
begin
  
  s_cordic_init <= (x => signed(x_i), y => signed(y_i), z => signed(z_i),  
                    valid => valid_i, lim_x =>'0', lim_y => '0',
                    mode => mode_i, submode => submode_i);

  -- Unfortunately necessary init process:
  -- the cordic algorithm solves an arctangeant, therefore it is required
  -- to 
  p_cordic_init : process(clk_i)
    constant c_FS_P90D : signed(g_WIDTH-1 downto 0) := to_signed(2**(g_WIDTH-2)-1, g_WIDTH);
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        s_stg(0) <= c_CORDIC_DEFAULT;
      else
        if s_cordic_init.mode = c_MODE_ROTATE and s_cordic_init.submode = c_SUBMODE_CIRCULAR then
          -- z < fs/2 and z > -fs/2 (equivalent to ]-90; 90[ )
          if s_cordic_init.z(g_WIDTH-1 downto g_WIDTH-2) = "00" or s_cordic_init.z(g_WIDTH-1 downto g_WIDTH-2) = "11"then
            s_stg(0) <= s_cordic_init;
          -- z > fs/2
          elsif s_cordic_init.z(g_WIDTH-1 downto g_WIDTH-2) = "01" then
            s_stg(0) <= s_cordic_init;
            s_stg(0).x <= -s_cordic_init.y;
            s_stg(0).y <= s_cordic_init.x;
            s_stg(0).z <= s_cordic_init.z - c_FS_P90D;
          -- z < fs/2
          elsif s_cordic_init.z(g_WIDTH-1 downto g_WIDTH-2) = "10" then
            s_stg(0) <= s_cordic_init;
            s_stg(0).x <= s_cordic_init.y;
            s_stg(0).y <= -s_cordic_init.x;
            s_stg(0).z <= s_cordic_init.z + c_FS_P90D;
          end if;

        elsif s_cordic_init.mode = c_MODE_VECTOR and s_cordic_init.submode = c_SUBMODE_CIRCULAR then
          -- x > 0
          if s_cordic_init.x(g_WIDTH-1) = '0' then
            s_stg(0) <= s_cordic_init;
          else
            -- x < 0 and y > 0
            if s_cordic_init.y(g_WIDTH-1) = '0' then
              s_stg(0) <= s_cordic_init;
              s_stg(0).x <= s_cordic_init.y;
              s_stg(0).y <= -s_cordic_init.x;
              s_stg(0).z <= s_cordic_init.z + c_FS_P90D;
            -- x < 0 and y < 0
            else
              s_stg(0) <= s_cordic_init;
              s_stg(0).x <= -s_cordic_init.y;
              s_stg(0).y <= s_cordic_init.x;
              s_stg(0).z <= s_cordic_init.z - c_FS_P90D;
            end if;
          end if;
        else
          s_stg(0) <= s_cordic_init;
        end if;
      end if;
    end if;
  end process p_cordic_init;

  gen_iterations : for i in 0 to g_ITERATIONS-2 generate
    p_iter : process(clk_i)

      constant c_ALPHA_CIRCULAR : signed(g_WIDTH-1 downto 0) := to_signed(integer(arctan(1.0/(2.0**(i)))*c_FS/MATH_PI), g_WIDTH);
      constant c_ALPHA_LINEAR : signed(g_WIDTH-1 downto 0) := to_signed(integer((1.0/(2.0**i)*c_FS)), g_WIDTH);
      constant c_ALPHA_HYPERBOLIC : signed(g_WIDTH-1 downto 0) := to_signed(integer(arctanh(1.0/(2.0**i))*c_FS), g_WIDTH);
      
      variable v_alpha : signed(g_WIDTH-1 downto 0);
      variable v_negate : std_logic; --inverts when '1', equivalent to di=-1
      variable v_x_shifted : signed(g_WIDTH-1 downto 0);
      variable v_y_shifted : signed(g_WIDTH-1 downto 0);
      variable v_x, v_y  : signed(g_WIDTH-1 downto 0);
      variable v_z  : signed(g_WIDTH-1 downto 0);
      variable v_lim_x, v_lim_y, v_lim_z : std_logic;
      
    begin
      if rising_edge(clk_i) then
        if rst_i = '1' then
          s_stg(i+1) <= c_CORDIC_DEFAULT;
          s_di(i) <= '0';
        else
          case s_stg(i).mode is
            when c_MODE_ROTATE => 
              -- di = sign(z) = not z'left. add when z is >= 0, else substract
              v_negate := s_stg(i).z(s_stg(i).z'left); 
            when c_MODE_VECTOR => 
              -- di = -sign(x*y) => + when (+.+) and (-.-), - when (+.-) and (-.+) -> xor
              v_negate := not (s_stg(i).x(g_WIDTH-1) xor s_stg(i).y(g_WIDTH-1));
            when others =>
              report "Wrong mode" severity error;
              v_negate := '0';
          end case;

          case s_stg(i).submode is
            when c_SUBMODE_CIRCULAR =>
              -- Using f_limit_negate to invert the number depending on v_negate (di)
              v_alpha := f_limit_negate(true, c_ALPHA_CIRCULAR, v_negate);
              v_y_shifted := f_limit_negate(true, f_shift(s_stg(i).y, i), v_negate);
            when c_SUBMODE_LINEAR =>
              v_alpha := f_limit_negate(true, c_ALPHA_LINEAR, v_negate);
              v_y_shifted := (others => '0');
            when c_SUBMODE_HYPERBOLIC =>
              v_alpha := f_limit_negate(true, c_ALPHA_HYPERBOLIC, v_negate);
              v_y_shifted := f_limit_negate(true, f_shift(s_stg(i).y, i), v_negate);
            when others => 
              report "Wrong submode" severity error;
          end case;

          v_x_shifted := f_limit_negate(true, f_shift(s_stg(i).x, i), v_negate);

          s_di(i) <= v_negate;

          -- we always want to limit substract on x and y
          f_limit_subtract(true, s_stg(i).x, v_y_shifted, v_x, v_lim_x);
          f_limit_add     (true, s_stg(i).y, v_x_shifted, v_y, v_lim_y);
          -- On vector/circular, the output z is an angle. We want it to freely overflow, because [-FS:+FS] -> [-180°:+180°]
          f_limit_subtract(s_stg(i).mode /= c_MODE_VECTOR and s_stg(i).submode /= c_SUBMODE_CIRCULAR, s_stg(i).z, v_alpha, v_z, v_lim_z);

          s_stg(i+1).valid <= s_stg(i).valid;
          s_stg(i+1).x <= v_x;
          s_stg(i+1).y <= v_y;
          s_stg(i+1).z <= v_z;
          s_stg(i+1).lim_x <= v_lim_x;
          s_stg(i+1).lim_y <= v_lim_y;
          s_stg(i+1).mode <= s_stg(i).mode;
          s_stg(i+1).submode <= s_stg(i).submode;
          
        end if;
      end if;
    end process p_iter;
  end generate gen_iterations;
  
  x_o <= std_logic_vector(s_stg(g_ITERATIONS-1).x);
  y_o <= std_logic_vector(s_stg(g_ITERATIONS-1).y);
  z_o <= std_logic_vector(s_stg(g_ITERATIONS-1).z);
  lim_x_o <= s_stg(g_ITERATIONS-1).lim_x;
  lim_y_o <= s_stg(g_ITERATIONS-1).lim_y;
  mode_o <= s_stg(g_ITERATIONS-1).mode;
  submode_o <= s_stg(g_ITERATIONS-1).submode;

end architecture rtl;