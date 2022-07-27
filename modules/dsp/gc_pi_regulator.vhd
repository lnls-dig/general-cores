

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

    en_i : in std_logic;

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

  signal xerror      : signed(g_DATA_BITS downto 0);
  signal setpoint    : signed(g_DATA_BITS downto 0);
  signal pmul, imul  : signed(c_MUL_BITS-1 downto 0);
  signal pmul_d      : signed(c_MUL_BITS-1 downto 0);
  signal integ       : signed(g_INTEGRATOR_BITS-1 downto 0);
  signal mults_valid : std_logic;
  signal integ_valid : std_logic;

  procedure f_clamp_add (
    x     :     signed;
    y     :     signed;
    o     : out signed;
    limit : out std_logic) is

    variable sum   : signed(o'length downto 0);

    variable v_min,  v_max : signed(o'length downto 0) := to_signed(0, o'length+1);

  begin
    v_min(v_min'left downto v_min'left-1) := "11";
    v_max(v_max'left-2 downto 0) := (others => '1');

    sum := resize(x+y, sum'length);

    if sum > v_max then
      o     := resize(v_max, o'length);
      limit := '1';
    elsif sum < v_min then
      o     := resize(v_min, o'length);
      limit := '1';
    else
      o     := sum(o'length-1 downto 0);
      limit := '0';
    end if;

  end f_clamp_add;

  signal integ_limit_hit : std_logic;
  signal limit_sum1, limit_sum2 : std_logic;

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

        y_o <= (others => '0');
        y_valid_o <= '0';
        mults_valid <= '0';
        integ_valid <= '0';
        integ <= (others => '0');
        imul <= (others => '0');
        pmul <= (others => '0');
        pmul_d <= (others => '0');
        limit_sum1 <= '0';
        limit_sum2 <= '0';

      else

        mults_valid <= '0';
        integ_valid <= '0';
        y_valid_o <= '0';

        if en_i = '1' then
          if x_valid_i = '1' then
            mults_valid <= '1';
            pmul <= resize(xerror * signed(kp_i), pmul'length);
            imul <= resize(xerror * signed(ki_i), imul'length);
          end if;

          if mults_valid = '1' then
            pmul_d <= pmul;
            integ_valid <= '1';
            if signed(ki_i) = 0 then
              integ <= (others => '0');
            else
              f_clamp_add(integ, imul, v_integ_next, v_integ_limit_hit);
              integ <= v_integ_next;
              limit_sum1 <= v_integ_limit_hit;
            end if;
          end if;
          
          if integ_valid = '1' then
            y_valid_o <= '1';
            f_clamp_add(integ, pmul_d, v_sum_next, v_sum_limit_hit);
            y_o <= std_logic_vector(v_sum_next(g_OUTPUT_BITS + g_GAIN_FRAC_BITS - 1 downto g_GAIN_FRAC_BITS));
            limit_sum2 <= v_sum_limit_hit;
          end if;
        else
          y_o <= (others => '0');
          integ <= (others => '0');
          pmul <= (others => '0');
          imul <= (others => '0');
          pmul_d <= (others => '0');
          limit_sum1 <= '0';
          limit_sum2 <= '0';
        end if;
      end if;
    end if;
  end process;

  lim_o <= limit_sum1 or limit_sum2;

end rtl;