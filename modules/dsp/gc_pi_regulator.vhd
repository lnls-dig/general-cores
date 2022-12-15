

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--use work.gencores_pkg.all;
use work.gc_cordic_pkg.all;

entity gc_pi_regulator is
  generic (
    g_DATA_BITS      : positive := 24;
    g_OUT_BITS       : positive := 16;
    g_OUT_SHIFT      : integer  := 12;
    g_SETPOINT_SHIFT : integer  := 8;
    g_MUL_MIN        : signed;
    g_MUL_MAX        : signed
    );

  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    enable_i     : in std_logic;
    integ_tick_i : in std_logic := '1';
    setpoint_i   : in std_logic_vector(15 downto 0);

    x_i   : in  std_logic_vector(g_DATA_BITS-1 downto 0);
    y_o   : out std_logic_vector(g_OUT_BITS-1 downto 0);
    p_y_o : out std_logic_vector(g_OUT_BITS-1 downto 0);
    i_y_o : out std_logic_vector(g_OUT_BITS-1 downto 0);

    p_gain_i : in std_logic_vector(15 downto 0);
    i_gain_i : in std_logic_vector(15 downto 0);

    p_lim_o : out std_logic;
    i_lim_o : out std_logic;
    lim_o   : out std_logic
    );
end gc_pi_regulator;

architecture rtl of gc_pi_regulator is

  constant c_MUL_BITS : integer := g_DATA_BITS + g_OUT_BITS;

  constant c_OUT_MAX : signed(g_OUT_BITS -1 downto 0) := to_signed(2**g_OUT_BITS-1, g_OUT_BITS);
  constant c_OUT_MIN : signed(g_OUT_BITS -1 downto 0) := to_signed(-2**g_OUT_BITS, g_OUT_BITS);

  signal xerror              : signed(g_DATA_BITS-1 downto 0);
  signal setpoint            : signed(g_DATA_BITS -1 downto 0);
  signal xsw                 : signed(g_DATA_BITS-1 downto 0);
  signal imul, pmul, iloop_d : signed(c_MUL_BITS-1 downto 0);
  signal integ               : signed(c_MUL_BITS-1 downto 0);

  signal sum : signed(g_OUT_BITS+1 downto 0);


  signal itrunc, ptrunc : signed(g_OUT_BITS-1 downto 0);

  procedure f_clamp (x :     signed; minval : signed; maxval : signed;
                     y : out signed; limit : out std_logic) is
  begin

    if(x > maxval) then
      y     := maxval;
      limit := '1';
    elsif (x < minval) then
      y     := minval;
      limit := '1';
    else
      y     := x;
      limit := '0';
    end if;

  end f_clamp;


begin

  setpoint <= resize (signed(setpoint_i) & to_signed(0, g_SETPOINT_SHIFT), setpoint'length);
  xsw      <= signed(x_i) when enable_i = '1' else (others => '0');
  xerror   <= xsw - resize(signed(setpoint_i), xerror'length);

  p_the_pi : process(clk_i)
    variable iloop      : signed(c_MUL_BITS-1 downto 0);
    variable ploop      : signed(c_MUL_BITS-1 downto 0);
    variable ilim, plim : std_logic;
  begin
    if rising_edge(clk_i) then
      imul <= xerror * signed(i_gain_i);
      pmul <= xerror * signed(p_gain_i);
      f_limit_add(imul, integ, iloop, ilim);

      if signed(i_gain_i) = 0 or rst_i = '1' then
        integ <= (others => '0');
      elsif integ_tick_i = '1' then
        integ <= integ + iloop;
      end if;

      i_lim_o <= ilim;

      f_clamp(pmul, g_MUL_MIN, g_MUL_MAX, ploop, plim);

      ptrunc <= ploop(g_OUT_BITS + g_OUT_SHIFT - 1 downto g_OUT_SHIFT);
      itrunc <= iloop(g_OUT_BITS + g_OUT_SHIFT - 1 downto g_OUT_SHIFT);

      p_lim_o <= plim;
      sum     <= itrunc + ptrunc + signed(setpoint_i);

      if sum > c_OUT_MAX then
        y_o   <= std_logic_vector(c_OUT_MAX);
        lim_o <= '1';
      elsif sum < c_OUT_MIN then
        y_o   <= std_logic_vector(c_OUT_MIN);
        lim_o <= '1';
      else
        y_o   <= std_logic_vector(resize(sum, g_OUT_BITS));
        lim_o <= '0';
      end if;
    end if;
  end process;

  p_y_o <= std_logic_vector(ptrunc);
  i_y_o <= std_logic_vector(itrunc);


end rtl;

