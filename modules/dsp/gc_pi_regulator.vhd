

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--use work.gencores_pkg.all;
use work.gc_cordic_pkg.all;

entity gc_pi_regulator is
  generic (
    g_DATA_BITS       : positive := 24;
    g_GAIN_BITS       : integer  := 16;
    g_GAIN_FRAC_BITS  : integer  := 10;
    g_INTEGRATOR_BITS : integer  := 32;
    g_OUTPUT_BITS     : positive := 16
    );

  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    setpoint_i : in std_logic_vector(g_DATA_BITS-1 downto 0);

    x_valid_i : in std_logic;
    x_i       : in std_logic_vector(g_DATA_BITS-1 downto 0);

    y_valid_o : out std_logic;
    y_o       : out std_logic_vector(g_OUTPUT_BITS-1 downto 0);

    kp_i : in std_logic_vector(g_GAIN_BITS-1 downto 0);
    ki_i : in std_logic_vector(g_GAIN_BITS-1 downto 0);

    lim_o : out std_logic
    );
end gc_pi_regulator;

architecture rtl of gc_pi_regulator is

  constant c_MUL_BITS : integer := g_DATA_BITS + g_GAIN_BITS + 1;

  constant c_INTEG_MIN : signed(g_INTEGRATOR_BITS-1 downto 0) := to_signed(2**g_INTEGRATOR_BITS-1, g_INTEGRATOR_BITS);
  constant c_INTEG_MAX : signed(g_INTEGRATOR_BITS-1 downto 0) := to_signed(-2**g_INTEGRATOR_BITS, g_INTEGRATOR_BITS);

  signal xerror     : signed(g_DATA_BITS downto 0);
  signal setpoint   : signed(g_DATA_BITS downto 0);
  signal pmul, imul : signed(c_MUL_BITS-1 downto 0);
  signal integ      : signed(g_INTEGRATOR_BITS-1 downto 0);
  signal sum        : signed(g_INTEGRATOR_BITS downto 0);

  procedure f_clamp_add (
    x     :     signed;
    y     :     signed;
    o     : out signed;
    limit : out std_logic) is

    variable sum   : signed(o'length downto 0);

    constant c_min : signed(o'length downto 0) :=
      to_signed( - (2**(o'length-1)), o'length+1 );

    constant c_max : signed(o'length downto 0) :=
      to_signed( (2**(o'length-1)) - 1, o'length+1 );

  begin

    sum := resize(x+y, sum'length);

    if(sum > c_max) then
      o     := resize(c_max, o'length);
      limit := '1';
    elsif (sum < c_min) then
      o     := resize(c_min, o'length);
      limit := '1';
    else
      o     := sum(o'length-1 downto 0);
      limit := '0';
    end if;

  end f_clamp_add;

  function f_sra(x : signed; shift : integer; out_bits : integer) return signed is
    variable ret : signed(out_bits-1 downto 0);
  begin
    ret := resize(x(x'length-1 downto shift), out_bits);
    return ret;
  end f_sra;

  signal integ_limit_hit : std_logic;

begin

  setpoint <= resize (signed(setpoint_i), setpoint'length);
  xerror   <= setpoint - resize(signed(x_i), setpoint'length);

  p_the_pi : process(clk_i)
    variable v_integ_next      : signed(g_INTEGRATOR_BITS-1 downto 0);
    variable v_integ_limit_hit : std_logic;
    variable v_sum_next        : signed(g_INTEGRATOR_BITS downto 0);
    variable v_sum_limit_hit   : std_logic;
  begin

    if rising_edge(clk_i) then
      if rst_i = '1' then
        y_o       <= (others => '0');
        y_valid_o <= '0';
        integ     <= (others => '0');
        imul <= (others => '0');
        pmul <= (others => '0');
      else
        if signed(ki_i) = 0 then
          integ <= (others => '0');
        elsif x_valid_i = '1' then
          pmul <= resize(xerror * signed(kp_i), pmul'length);
          imul <= resize(xerror * signed(ki_i), imul'length);

          f_clamp_add(integ, imul, v_integ_next, v_integ_limit_hit);
          integ <= v_integ_next;
          
          f_clamp_add(integ, pmul, v_sum_next, v_sum_limit_hit);
          y_o <= std_logic_vector(v_sum_next(g_OUTPUT_BITS + g_GAIN_FRAC_BITS - 1 downto g_GAIN_FRAC_BITS));
          sum <= v_sum_next;
        end if;
      end if;
    end if;
  end process;



end rtl;

