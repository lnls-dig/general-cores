library ieee;
use ieee.std_logic_1164.All;
use ieee.numeric_std.All;

package gc_dsp_pkg is

  constant c_MAX_COEF_BITS : integer := 32;
  constant c_FIR_MAX_COEFS : integer := 128;
  
  type t_FIR_COEF_ARRAY is array(c_FIR_MAX_COEFS-1 downto 0) of signed(c_MAX_COEF_BITS-1 downto 0);

end package;
