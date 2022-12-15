library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gc_cordic_pkg.all;

entity cordic_xy_logic_hd is
  generic(
    g_M : positive := 16;
    g_J : integer := 0
    );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    cor_submode_i : in t_CORDIC_SUBMODE;

    d_i   : in std_logic;
    fi_i : in std_logic_vector(g_m-1 downto 0);

    lim_x_i : in std_logic;
    lim_y_i : in std_logic;


    xi_i : in std_logic_vector(g_M-1 downto 0);
    yi_i : in std_logic_vector(g_M-1 downto 0);
    zi_i : in std_logic_vector(g_M downto 0);

    xj_o : out std_logic_vector(g_M-1 downto 0);
    yj_o : out std_logic_vector(g_M-1 downto 0);
    zj_o : out std_logic_vector(g_M downto 0);

    lim_x_o : out std_logic;
    lim_y_o : out std_logic;

    rst_o : out std_logic
    );

end entity;

architecture rtl of cordic_xy_logic_hd is

  function f_shift(
    vin : signed;
    m   : integer;
    j   : integer) return signed is
  begin
    if j < m - 2 then
      return resize(vin(m-1 downto j), m);
    else
      return to_signed(0, m);
    end if;
  end f_shift;

  signal xi_shifted : signed(g_M -1 downto 0);
  signal yi_shifted : signed(g_M -1 downto 0);

  signal rst_l, rst_d : std_logic;
  
begin

  xi_shifted <= f_shift(signed(xi_i), g_M, g_J);
  yi_shifted <= f_shift(signed(yi_i), g_M, g_J);

  p_reset : process(clk_i)
  begin
    if rising_edge(clk_i) then
      rst_d <= rst_i;
    end if;
  end process;

  rst_l <= rst_d or rst_i;

  process(clk_i)

    variable xi_muxed : signed(g_M-1 downto 0);
    variable yi_muxed : signed(g_M-1 downto 0);
    variable fi_inv : signed(g_M-1 downto 0);

    variable xj_comb : signed(g_M-1 downto 0);
    variable yj_comb : signed(g_M-1 downto 0);
    variable zj_comb : signed(g_M downto 0);
    
    variable xj_limit : std_logic;
    variable yj_limit : std_logic;


  begin
    if rising_edge(clk_i) then

      if rst_l = '1' then
        xj_o <= (others => '0');
        yj_o <= (others => '0');
        zj_o <= (others => '0');

        lim_x_o <= '0';
        lim_y_o <= '0';
      else


        case cor_submode_i is
          when LINEAR =>
            -- scntrl = 1, updmode = 0
            yi_muxed := (others => '0');

          -- scntrl = 1, updmode = 1
          when CIRCULAR =>
            yi_muxed := f_limit_negate(yi_shifted, not d_i);

          -- scntrl = 0, updmode = 1
          when HYPERBOLIC =>
            yi_muxed := f_limit_negate(yi_shifted, d_i);
        end case;

        xi_muxed := f_limit_negate(xi_shifted, not d_i);

        f_limit_subtract(signed(xi_i), yi_muxed, xj_comb, xj_limit);
        f_limit_add(signed(yi_i), xi_muxed, yj_comb, yj_limit);

        fi_inv := f_limit_negate( signed(fi_i), not d_i );
        
        zj_comb := signed(zi_i) - fi_inv;
        
        xj_o <= std_logic_vector(xj_comb);
        yj_o <= std_logic_vector(yj_comb);
        zj_o <= std_logic_vector(zj_comb);
        lim_x_o <= lim_x_i or xj_limit;
        lim_y_o <= lim_y_i or yj_limit;

      end if;
    end if;

  end process;





end rtl;
