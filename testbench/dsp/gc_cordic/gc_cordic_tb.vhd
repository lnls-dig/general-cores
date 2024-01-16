-----------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------
--
-- Description : Simple VHDL cordic testbench to hunt for edge cases and fix these.
--
------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;

use work.gc_cordic_pkg.all;

entity gc_cordic_tb is
end gc_cordic_tb;

architecture tb of gc_cordic_tb is

  constant c_CLK_PERIOD : time := 8 ns;
  constant c_T_MAX : time := 10 ms;
  signal s_clk,s_rst,s_sim_end : std_logic := '0';

  constant c_ACCEPTED_ERROR : integer := 450;
  constant c_WIDTH : integer := 14;
  constant c_ITERATIONS : integer := 14;

  signal s_done, s_done_shifted : std_logic := '0';

  signal s_cor_mode : t_CORDIC_MODE;
  signal s_cor_submode : t_CORDIC_SUBMODE;

  type t_CORDIC_INT is record
    x : integer;
    y : integer;
    z : integer;
    mode : t_CORDIC_MODE;
    submode : t_CORDIC_SUBMODE;
    valid : std_logic;
  end record;

  type t_CORDIC_STV is record
    x : std_logic_vector;
    y : std_logic_vector;
    z : std_logic_vector;
    mode : t_CORDIC_MODE;
    submode : t_CORDIC_SUBMODE;
    valid : std_logic;
  end record;
  
  function f_stv2int(inp : t_CORDIC_STV) return t_CORDIC_INT is
    variable v_ret : t_CORDIC_INT;
  begin
    v_ret.x := to_integer(signed(inp.x));
    v_ret.y := to_integer(signed(inp.y));
    v_ret.z := to_integer(signed(inp.z));
    v_ret.mode := inp.mode;
    v_ret.submode := inp.submode;
    v_ret.valid := inp.valid;
    return v_ret;
  end function f_stv2int;

  function f_int2stv(inp : t_CORDIC_INT; nbits : integer) return t_CORDIC_STV is
    variable v_ret : t_CORDIC_STV(x(nbits-1 downto 0), y(nbits-1 downto 0), z(nbits-1 downto 0));
  begin
    if inp.x > 2**(nbits-1)-1 or inp.y > 2**(nbits-1)-1 or inp.z > 2**(nbits-1)-1 then 
      report "ovf " & integer'image(inp.x) & " " & integer'image(inp.y)& " " & integer'image(inp.z);
    elsif inp.x < -2**(nbits-1) or inp.y < -2**(nbits-1) or inp.z < -2**(nbits-1) then 
      report "ovf " & integer'image(inp.x) & " " & integer'image(inp.y)& " " & integer'image(inp.z);
    end if;
    v_ret.x := std_logic_vector(to_signed(inp.x, nbits));
    v_ret.y := std_logic_vector(to_signed(inp.y, nbits));
    v_ret.z := std_logic_vector(to_signed(inp.z, nbits));
    v_ret.mode := inp.mode;
    v_ret.submode := inp.submode;
    v_ret.valid := inp.valid;
    return v_ret;
  end function f_int2stv;

  function f_check_error(res, target, err: integer; overflow_ok : boolean; nbits : integer) return boolean is
    constant c_MAX : integer := 2**(nbits-1)-1;
    constant c_MIN : integer := -2**(nbits-1);
    variable v_int : integer;
  begin
    if overflow_ok then
      v_int := res-target;
      if v_int > c_MAX then
        v_int := v_int + 2*c_MIN;
      elsif v_int < c_MIN then
        v_int := v_int + 2*c_MAX;
      end if;

      if v_int < err then
        return true;
      else
        return false;
      end if;
    else
      if res > target - err and res < target + err then
        return true;
      else
        return false;
      end if;
    end if;
  end function f_check_error;

  procedure f_check_result(i, o : t_CORDIC_INT;
                          max_error: integer;
                          nbits : integer;
                          exp_o : out t_CORDIC_INT;
                          matched : out boolean) is

    variable v_expected_x, v_expected_y, v_expected_z : integer;
    constant c_SCALING : real := 2.0**(nbits-1)-1.0;
    constant c_K : real := real(to_integer(signed(f_compute_an(nbits))))/c_SCALING;
    constant c_K_p : integer :=  integer(c_SCALING * 0.8281593609602);
    variable v_res : boolean;
  begin
    v_res := true;
    if i.mode = c_MODE_ROTATE then
      if i.submode = c_SUBMODE_CIRCULAR then
        v_expected_x := integer(1.0/c_K*(real(i.x)*cos(real(i.z)/c_SCALING*MATH_PI) - real(i.y)*sin(real(i.z)/c_SCALING*MATH_PI)));
        v_expected_y := integer(1.0/c_K*(real(i.y)*cos(real(i.z)/c_SCALING*MATH_PI) + real(i.x)*sin(real(i.z)/c_SCALING*MATH_PI)));
        v_expected_z := 0;
        
        if not (f_check_error(o.z, v_expected_z, max_error, false, nbits) 
            and f_check_error(o.y, v_expected_y, max_error, false, nbits) 
            and f_check_error(o.x, v_expected_x, max_error, false, nbits)) then
            report "Rotate/Circular : o.x = K*(x*cos(z) - y*sin(z)), o.y = K*(y*cos(z)+x*sin(z)) | " &
                   "in["&integer'image(i.x)&" "&integer'image(i.y)&" "&integer'image(i.z)&"] -> " &
                   "out["&integer'image(o.x)&" "&integer'image(o.y)&" "&integer'image(o.z)&"] /= " &
                   "exp["&integer'image(v_expected_x) &", "&integer'image(v_expected_y)&", "&integer'image(v_expected_z)&"]"
            severity error;
            v_res := false;
        end if;

      elsif i.submode = c_SUBMODE_LINEAR then
        v_expected_x := i.x;
        v_expected_y := integer(real(real(i.y)/c_SCALING + real(i.x * i.z)/(c_SCALING*c_SCALING))*c_SCALING);
        v_expected_z := 0;

        if not (f_check_error(o.z, v_expected_z, max_error, false, nbits) 
            and f_check_error(o.y, v_expected_y, max_error, false, nbits) 
            and f_check_error(o.x, v_expected_x, max_error, false, nbits)) then
            report "Rotate/Linear   : o.x = x,  o.y = y + x*z, o.z = 0 | " &
                   "in["&integer'image(i.x)&" "&integer'image(i.y)&" "&integer'image(i.z)&"] -> " &
                   "out["&integer'image(o.x)&" "&integer'image(o.y)&" "&integer'image(o.z)&"] /= " &
                   "exp["&integer'image(v_expected_x) &", "&integer'image(v_expected_y)&", "&integer'image(v_expected_z)&"]"
            severity error;
            v_res := false;
        end if;
        
      elsif i.submode = c_SUBMODE_HYPERBOLIC then
        v_expected_x := c_K_p * (i.x * integer(c_SCALING*cosh(real(i.z))) - i.y * integer(c_SCALING*sinh(real(i.z))));
        assert f_check_error(o.x, v_expected_x, max_error, false, nbits)
        report "Error for o.x on rotate/hyperbolic : expected " & integer'image(v_expected_x) & ", got "& integer'image(o.x)&"."
        severity error;

        v_expected_y := c_K_p * (i.y * integer(c_SCALING*cosh(real(i.z))) + i.x * integer(c_SCALING*sinh(real(i.z))));
        assert f_check_error(o.y, v_expected_y, max_error, false, nbits)
        report "Error for o.y on rotate/hyperbolic : expected " & integer'image(v_expected_y) & ", got "& integer'image(o.y)&"."
        severity error;

        v_expected_z := 0;
        assert f_check_error(o.z, v_expected_z, max_error, false, nbits)
        report "Error for o.z on rotate/hyperbolic : expected " & integer'image(v_expected_z) & ", got "& integer'image(o.z)&"."
        severity error;
      else
        report "Non defined submode" severity error;
      end if;
    elsif i.mode = c_MODE_VECTOR then
      if i.submode = c_SUBMODE_CIRCULAR then
        v_expected_x := integer(1.0/c_K*sqrt(real(i.x)*real(i.x) + real(i.y)*real(i.y)));
        v_expected_y := 0;

        if i.x = 0 then
          if i.x*i.y >= 0 then
            v_expected_z := i.z - integer(0.5*c_SCALING); -- 0.5 * c_SCALING = 90°
          else
            v_expected_z := i.z + integer(0.5*c_SCALING);
          end if;
        else
            -- atan [-pi/2, pi/2] -> [-0.5, 0.5]*c_SCALING
            v_expected_z := i.z + integer(arctan(real(i.y)/real(i.x))*c_SCALING/MATH_PI);
        end if;

        if i.x < 0 then
          v_expected_z := v_expected_z - integer(c_SCALING);
        end if;

        if v_expected_z > integer(c_SCALING) then 
          v_expected_z := v_expected_z - integer(2.0* c_SCALING);
        end if;
        if v_expected_z < -integer(c_SCALING) then 
          v_expected_z := v_expected_z + integer(2.0* c_SCALING);
        end if;
        if v_expected_z > integer(c_SCALING) then 
          v_expected_z := v_expected_z - integer(2.0* c_SCALING);
        end if;
        if v_expected_z < -integer(c_SCALING) then 
          v_expected_z := v_expected_z + integer(2.0* c_SCALING);
        end if;
        

        if not (f_check_error(o.z, v_expected_z, max_error, true, nbits) 
            and f_check_error(o.y, v_expected_y, max_error, false, nbits) 
            and f_check_error(o.x, v_expected_x, max_error, false, nbits)) then
            report "Vector/Circular : o.x = K*sqrt(x^2+y^2),  o.y = 0, o.z = z + atan(y/x) | " &
                   "in["&integer'image(i.x)&" "&integer'image(i.y)&" "&integer'image(i.z)&"] -> " &
                   "out["&integer'image(o.x)&" "&integer'image(o.y)&" "&integer'image(o.z)&"] /= " &
                   "exp["&integer'image(v_expected_x) &", "&integer'image(v_expected_y)&", "&integer'image(v_expected_z)&"]"
            severity error;
            v_res := false;
        end if;

      elsif i.submode = c_SUBMODE_LINEAR then
        v_expected_x := i.x;
        v_expected_y := 0;
        v_expected_z :=  integer((real(i.z) +real(i.y) / real(i.x)*c_SCALING));

        if not (f_check_error(o.z, v_expected_z, max_error, false, nbits) 
            and f_check_error(o.y, v_expected_y, max_error, true, nbits) 
            and f_check_error(o.x, v_expected_x, max_error, false, nbits)) then
            report "Vector/Linear   : o.x = x,  o.y = 0, o.z = z + y/x | " &
                   "in["&integer'image(i.x)&" "&integer'image(i.y)&" "&integer'image(i.z)&"] -> " &
                   "out["&integer'image(o.x)&" "&integer'image(o.y)&" "&integer'image(o.z)&"] /= " &
                   "exp["&integer'image(v_expected_x) &", "&integer'image(v_expected_y)&", "&integer'image(v_expected_z)&"]"
            severity error;
            v_res := false;
        end if;

      elsif i.submode = c_SUBMODE_HYPERBOLIC then
        v_expected_x := integer(1.0/c_K * sqrt(real(i.x)*real(i.x) - real(i.y)*real(i.y))*c_SCALING);
        assert f_check_error(o.x, v_expected_x, max_error, false, nbits)
        report "Error for o.x on vector/hyperbolic : expected " & integer'image(v_expected_x) & ", got "& integer'image(o.x)&"."
        severity error;

        v_expected_y := 0;
        assert f_check_error(o.y, v_expected_y, max_error, false, nbits)
        report "Error for o.y on vector/hyperbolic : expected " & integer'image(v_expected_y) & ", got "& integer'image(o.y)&"."
        severity error;

        v_expected_z := i.z + integer(c_SCALING * arctanh(real(i.y) / real(i.x)));
        assert f_check_error(o.z, v_expected_z, max_error, false, nbits)
        report "Error for o.z on vector/hyperbolic : expected " & integer'image(v_expected_z) & ", got "& integer'image(o.z)&"."
        severity error;
      else
        report "Non defined submode" severity error;
      end if;
    end if;
    
    exp_o := o;
    exp_o.x := v_expected_x;
    exp_o.y := v_expected_y;
    exp_o.z := v_expected_z;

    matched := v_res;
  end procedure f_check_result;
  
  constant c_AN : integer := to_integer(signed(f_compute_an(c_WIDTH)));
  constant c_CORDIC_INT_DEF : t_CORDIC_INT := (x=>0, y=>0, z=>0, mode=>c_MODE_ROTATE, submode=>c_SUBMODE_CIRCULAR, valid => '0');
  signal s_stim, s_res : t_CORDIC_STV(x(c_WIDTH-1 downto 0), y(c_WIDTH-1 downto 0), z(c_WIDTH-1 downto 0));
  signal s_in, s_in_shifted, s_out : t_CORDIC_INT;

  type t_TEST_STIM is array(natural range <>) of t_CORDIC_INT;
  signal s_stim_array, s_res_array : t_TEST_STIM(0 to 15) := (
    -- rot / circ = mag/angle -> cos/sin
    (x=>-c_AN, y=>0, z=>0, mode=>c_MODE_ROTATE, submode=>c_SUBMODE_CIRCULAR, valid => '0'),
    (x=>c_AN, y=>0, z=>4095, mode=>c_MODE_ROTATE, submode=>c_SUBMODE_CIRCULAR, valid => '0'),
    (x=>c_AN, y=>0, z=>8191, mode=>c_MODE_ROTATE, submode=>c_SUBMODE_CIRCULAR, valid => '0'),
    (x=>c_AN, y=>0, z=>-4095, mode=>c_MODE_ROTATE, submode=>c_SUBMODE_CIRCULAR, valid => '0'),
    -- vect / circ = cos/sin -> mag/angle
    (x=>c_AN, y=>0, z=>0, mode=>c_MODE_VECTOR, submode=>c_SUBMODE_CIRCULAR, valid => '0'),
    (x=>0, y=>c_AN, z=>0, mode=>c_MODE_VECTOR, submode=>c_SUBMODE_CIRCULAR, valid => '0'),
    (x=>-c_AN, y=>0, z=>0, mode=>c_MODE_VECTOR, submode=>c_SUBMODE_CIRCULAR, valid => '0'),
    (x=>0, y=>-c_AN, z=>0, mode=>c_MODE_VECTOR, submode=>c_SUBMODE_CIRCULAR, valid => '0'),
    ---- rot / lin = x=x, y=y+x*z
    (x=>10, y=>0, z=>-100, mode=>c_MODE_ROTATE, submode=>c_SUBMODE_LINEAR, valid => '0'),
    (x=>100, y=>0, z=>-10, mode=>c_MODE_ROTATE, submode=>c_SUBMODE_LINEAR, valid => '0'),
    (x=>1000, y=>0, z=>5, mode=>c_MODE_ROTATE, submode=>c_SUBMODE_LINEAR, valid => '0'),
    (x=>-100, y=>0, z=>-5, mode=>c_MODE_ROTATE, submode=>c_SUBMODE_LINEAR, valid => '0'),
    ---- vect / lin = x=x, z=z+y/x
    (x=>-8192, y=>8191, z=>0, mode=>c_MODE_VECTOR, submode=>c_SUBMODE_LINEAR, valid => '0'),
    (x=>8191, y=>-8190, z=>0, mode=>c_MODE_VECTOR, submode=>c_SUBMODE_LINEAR, valid => '0'),
    (x=>8191, y=>0, z=>0, mode=>c_MODE_VECTOR, submode=>c_SUBMODE_LINEAR, valid => '0'),
    (x=>8191, y=>4000, z=>4095, mode=>c_MODE_VECTOR, submode=>c_SUBMODE_LINEAR, valid => '0')
  );
  
begin

  s_stim <= f_int2stv(s_in, c_WIDTH);
  s_out <= f_stv2int(s_res);

  s_clk_proc : process is
  begin
    loop
      s_clk <= '0';
      wait for c_CLK_PERIOD/2;
      s_clk <= '1';
      wait for c_CLK_PERIOD/2;
      
      if s_sim_end = '1' then
        wait;
      end if;
      
      if now > c_T_MAX then
        report "Max simulation time overlapped" severity error;
        wait;
      end if;
    end loop;
  end process s_clk_proc;

  p_main_stim : process is
    variable v_res : boolean;
  begin
    s_rst <= '1';
    wait for 5*c_CLK_PERIOD;
    wait until rising_edge(s_clk);
    s_rst <= '0';
    wait until rising_edge(s_clk);
  

    wait until s_done = '1';

    wait for (c_ITERATIONS+10)* c_CLK_PERIOD;
    
    s_sim_end <= '1';
    report "Simulation got to the end of main_stim process" severity note;
    wait;
  end process p_main_stim;

  p_stim_srg : process
    variable seed1, seed2 : integer := 999;
    variable v_rand : real;

    variable v_mag, v_angle, v_rotate_angle : real;

    variable v_x, v_y, v_z : real;
    constant c_K : real := 1.646760258121;
    constant c_N_TESTS : integer := 10000;
    constant c_RUN_SINGLE : boolean := false;
  begin
    s_in <= c_CORDIC_INT_DEF;
    s_done <= '0'; 
    wait until falling_edge(s_rst);
    wait until rising_edge(s_clk);
    wait until rising_edge(s_clk);

    if c_RUN_SINGLE then

      wait until rising_edge(s_clk);
      s_in.x <= -3150;
      s_in.y <= -3148;
      s_in.z <= 35;
      s_in.mode <= c_MODE_VECTOR;
      s_in.submode <= c_SUBMODE_LINEAR;
      s_in.valid <= '1';
      wait until rising_edge(s_clk);
      s_in.valid <= '0';
      wait until rising_edge(s_clk);

    else

      report "Testing some edgecases";
      for i in 0 to s_stim_array'length-1 loop
        wait until rising_edge(s_clk);
        s_in <= s_stim_array(i);
      end loop;

      report "Testing rotate/circular";
      for i in 0 to c_N_TESTS-1 loop
        uniform(seed1, seed2, v_rand);
        v_mag :=  v_rand/c_K;
        uniform(seed1, seed2, v_rand);
        v_angle :=  (v_rand*2.0-1.0)*MATH_PI;
        uniform(seed1, seed2, v_rand);
        v_rotate_angle :=  (v_rand*2.0-1.0);

        -- x,y,z computed as real numbers
        v_x := v_mag*cos(v_angle);
        v_y := v_mag*sin(v_angle);
        v_z := v_rotate_angle;

        wait until rising_edge(s_clk);
        s_in.mode <= c_MODE_ROTATE;
        s_in.submode <= c_SUBMODE_CIRCULAR;
        s_in.x <= integer(v_x*2.0**(c_WIDTH-1)-1.0);
        s_in.y <= integer(v_y*2.0**(c_WIDTH-1)-1.0);
        s_in.z <= integer(v_z*2.0**(c_WIDTH-1)-1.0);
      end loop;

      report "Testing rotate/linear";
      for i in 0 to c_N_TESTS-1 loop
        -- x,y,z computed as real numbers
        uniform(seed1, seed2, v_rand);
        v_x := (v_rand*2.0-1.0);
        uniform(seed1, seed2, v_rand);
        v_z := (v_rand*2.0-1.0);
        uniform(seed1, seed2, v_rand);
        --v_y := (v_rand*2.0-1.0)*(1.0-abs(v_x*v_z));
        v_y := 0.0;

        wait until rising_edge(s_clk);
        s_in.mode <= c_MODE_ROTATE;
        s_in.submode <= c_SUBMODE_LINEAR;
        s_in.x <= integer(v_x*2.0**(c_WIDTH-1)-1.0);
        s_in.y <= integer(v_y*2.0**(c_WIDTH-1)-1.0);
        s_in.z <= integer(v_z*2.0**(c_WIDTH-1)-1.0);
      end loop;

      report "Testing vector/circular";
      for i in 0 to c_N_TESTS-1 loop
        uniform(seed1, seed2, v_rand);
        v_mag :=  v_rand/c_K;
        uniform(seed1, seed2, v_rand);
        v_angle :=  (v_rand*2.0-1.0)*MATH_PI;
        uniform(seed1, seed2, v_rand);
        v_rotate_angle :=  (v_rand*2.0-1.0);

        -- x,y,z computed as real numbers
        v_x := v_mag*cos(v_angle);
        v_y := v_mag*sin(v_angle);
        v_z := v_rotate_angle;

        wait until rising_edge(s_clk);
        s_in.mode <= c_MODE_VECTOR;
        s_in.submode <= c_SUBMODE_CIRCULAR;
        s_in.x <= integer(v_x*2.0**(c_WIDTH-1)-1.0);
        s_in.y <= integer(v_y*2.0**(c_WIDTH-1)-1.0);
        s_in.z <= integer(v_z*2.0**(c_WIDTH-1)-1.0);
      end loop;
      

      report "Testing vector/linear";
      for i in 0 to c_N_TESTS-1 loop
        -- x,y,z computed as real numbers
        uniform(seed1, seed2, v_rand);
        v_x := (v_rand*2.0-1.0);
        uniform(seed1, seed2, v_rand);
        v_y := (v_rand*2.0-1.0)*v_x;
        uniform(seed1, seed2, v_rand);
        v_z := (v_rand*2.0-1.0)*(1.0-abs(v_y/v_x));

        wait until rising_edge(s_clk);
        s_in.mode <= c_MODE_VECTOR;
        s_in.submode <= c_SUBMODE_LINEAR;
        s_in.x <= integer(v_x*2.0**(c_WIDTH-1)-1.0);
        s_in.y <= integer(v_y*2.0**(c_WIDTH-1)-1.0);
        s_in.z <= integer(v_z*2.0**(c_WIDTH-1)-1.0);
      end loop;

    end if;

    s_done <= '1';
    wait;
  end process p_stim_srg;
  s_in_shifted <= transport s_in after (c_ITERATIONS+1) * c_CLK_PERIOD;
  s_done_shifted <= transport s_done after (c_ITERATIONS+1) * c_CLK_PERIOD;
  
  p_res_readback : process
    variable v_res : boolean;
    variable v_n_err : integer := 0;
    variable v_rotate_circular : integer := 0;
    variable v_rotate_linear : integer := 0;
    variable v_vector_circular : integer := 0;
    variable v_vector_linear : integer := 0;
    variable v_exp_out : t_CORDIC_INT;

    file test_vector      : text open write_mode is "res.txt";
    variable row          : line;

  begin
    wait until falling_edge(s_rst);
    wait for (c_ITERATIONS+4)*c_CLK_PERIOD;
    while s_done_shifted = '0' loop
      wait until rising_edge(s_clk);
      f_check_result(s_in_shifted, s_out, c_ACCEPTED_ERROR, c_WIDTH, v_exp_out,v_res );
      if not v_res then
        v_n_err := v_n_err + 1;
        if s_out.mode = c_MODE_ROTATE then
          if s_out.submode = c_SUBMODE_CIRCULAR then
            v_rotate_circular := v_rotate_circular+1;
          elsif s_out.submode = c_SUBMODE_LINEAR then
            v_rotate_linear := v_rotate_linear+1;
          end if;
        elsif s_out.mode = c_MODE_VECTOR then
          if s_out.submode = c_SUBMODE_CIRCULAR then
            v_vector_circular := v_vector_circular+1;
          elsif s_out.submode = c_SUBMODE_LINEAR then
            v_vector_linear := v_vector_linear+1;
          end if;
        end if;
      end if;

      write(row, integer'image(s_in_shifted.x) & "," & integer'image(s_in_shifted.y) & "," & integer'image(s_in_shifted.z) & "," & 
                 integer'image(s_out.x) & "," & integer'image(s_out.y) & "," & integer'image(s_out.z) & "," & 
                 integer'image(v_exp_out.x) & "," & integer'image(v_exp_out.y) & "," & integer'image(v_exp_out.z) 
                 & "," & to_hstring(s_in_shifted.mode) & "," & to_hstring(s_in_shifted.submode));
      writeline(test_vector, row);
    end loop;
    
    report "Total errors : " & integer'image(v_n_err);
    report "Total rotate/circular errors : " & integer'image(v_rotate_circular);
    report "Total rotate/linear errors : " & integer'image(v_rotate_linear);
    report "Total vector/circular errors : " & integer'image(v_vector_circular);
    report "Total vector/linear errors : " & integer'image(v_vector_linear);
    wait;
  end process p_res_readback;

  cmp_dut : entity work.gc_cordic_top
  generic map
  (
    g_ITERATIONS => c_ITERATIONS,
    g_WIDTH => c_WIDTH
  )
  port map
  (
    clk_i => s_clk,
    rst_i => s_rst,

    mode_i    => s_stim.mode,
    submode_i => s_stim.submode,

    x_i => s_stim.x,
    y_i => s_stim.y,
    z_i => s_stim.z,
    valid_i => s_stim.valid,

    x_o => s_res.x,
    y_o => s_res.y,
    z_o => s_res.z,
    lim_x_o => open,
    lim_y_o => open,
    mode_o => s_res.mode,
    submode_o => s_res.submode
  );

  --cmp_dut : entity work.gc_cordic
  --generic map
  --(
  --  g_N => c_ITERATIONS,
  --  g_M => c_WIDTH
  --)
  --port map
  --(
  --  clk_i => s_clk,
  --  rst_i => s_rst,

  --  lim_x_i => '0',
  --  lim_y_i => '0',
  --  cor_mode_i    => s_stim.mode,
  --  cor_submode_i => s_stim.submode,

  --  x0_i => s_stim.x,
  --  y0_i => s_stim.y,
  --  z0_i => s_stim.z,

  --  xn_o => s_res.x,
  --  yn_o => s_res.y,
  --  zn_o => s_res.z,
  --  lim_x_o => open,
  --  lim_y_o => open
  --);
  
  
  
end tb;