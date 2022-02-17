library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gc_cordic_pkg.all;

entity cordic_xy_logic_nhd is
  generic(
    g_M : positive := 16;
    g_J : integer := 0;
    g_I : integer := 0;
    g_ANGLE_FORMAT : integer
    );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    cor_submode_i : in t_CORDIC_SUBMODE;
    cor_mode_i : in t_CORDIC_MODE;

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

architecture rtl of cordic_xy_logic_nhd is

  function f_shift(
    vin : signed;
    m   : integer;
    j   : integer) return signed is
  begin
    if j <= m - 2 then
      return resize(vin(m-1 downto j), m);
    else
      return to_signed(0, m);
    end if;
  end f_shift;

  signal xi_shifted : signed(g_M -1 downto 0);
  signal yi_shifted : signed(g_M -1 downto 0);
  signal fi : signed(g_M-1 downto 0);
  signal di_int : std_logic;
  signal rst_l, rst_d : std_logic;
  signal xi_muxed_s : signed(g_M-1 downto 0);
  signal yi_muxed_s : signed(g_M-1 downto 0);

begin

  fi <= f_phi_lookup( g_I, cor_submode_i, g_ANGLE_FORMAT )(31 downto 31-(g_M-1) );
  
  xi_shifted <= f_shift(signed(xi_i), g_M, g_J);
  yi_shifted <= f_shift(signed(yi_i), g_M, g_J);

  p_gen_di: process(cor_mode_i, yi_i, zi_i)
  begin
    if cor_mode_i = c_MODE_VECTOR then
      di_int <= yi_i(g_M-1);
    else
      di_int <= not zi_i(g_M);
    end if;
  end process;

  p_reset : process(clk_i)
  begin
    if rising_edge(clk_i) then
      rst_d <= rst_i;
    end if;
  end process;

  rst_l <= rst_d or rst_i;
  rst_o <= rst_l;
  
  p_pipe: process(clk_i)

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
          when c_SUBMODE_LINEAR =>
            -- scntrl = 1, updmode = 0
            yi_muxed := (others => '0');

          when c_SUBMODE_CIRCULAR =>
          -- scntrl = 1, updmode = 1
            yi_muxed := f_limit_negate(yi_shifted, not di_int);

          when c_SUBMODE_HYPERBOLIC =>
          -- scntrl = 0, updmode = 1
            yi_muxed := f_limit_negate(yi_shifted, di_int);

          when others =>
            yi_muxed := (others => '0');
            
        end case;

        xi_muxed := f_limit_negate(xi_shifted, not di_int);
        xi_muxed_s <= xi_muxed;
        yi_muxed_s <= yi_muxed;
        
        f_limit_subtract(signed(xi_i), yi_muxed, xj_comb, xj_limit);
        f_limit_add(signed(yi_i), xi_muxed, yj_comb, yj_limit);

        fi_inv := f_limit_negate( signed(fi), not di_int );
        
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
