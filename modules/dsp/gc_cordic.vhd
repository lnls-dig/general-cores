library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gc_cordic_pkg.all;

entity gc_cordic is
  generic(
    -- Number of XYlogicNHD cells instantiated
    g_N : positive := 12;

    --M = Word-width (maximum = 32)
    g_M : positive := 16;

    --AngleMode = Default angle format S8.7 otherwise FS = 180 deg.
    g_ANGLE_MODE : t_CORDIC_ANGLE_FORMAT := S8_7
    );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    cor_mode_i    : in t_CORDIC_MODE;
    cor_submode_i : in t_CORDIC_SUBMODE;

    lim_x_i : in std_logic;
    lim_y_i : in std_logic;

    x0_i : in std_logic_vector(g_M-1 downto 0);
    y0_i : in std_logic_vector(g_M-1 downto 0);
    z0_i : in std_logic_vector(g_M-1 downto 0);

    xn_o : out std_logic_vector(g_M-1 downto 0);
    yn_o : out std_logic_vector(g_M-1 downto 0);
    zn_o : out std_logic_vector(g_M-1 downto 0);

    lim_x_o : out std_logic;
    lim_y_o : out std_logic;

    rst_o : out std_logic
    );

end entity;

architecture rtl of gc_cordic is
  signal r_lim_x, r_lim_y : std_logic;
  signal z0_int           : std_logic_vector(g_M downto 0);
  signal x1, y1           : std_logic_vector(g_M-1 downto 0);
  signal z1               : std_logic_vector(g_M downto 0);
  signal d1               : std_logic;
  signal fi1              : std_logic_vector(31 downto 0);
  signal zj_int : std_logic_vector(g_M downto 0);
  signal rst_o_int, rst_o_int_d : std_logic;

begin

  fi1    <= std_logic_vector(f_phi_lookup(0, cor_submode_i, g_ANGLE_MODE));
  z0_int <= std_logic_vector(resize (signed(z0_i), g_M + 1));

  p_latch_lims : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        r_lim_x <= '0';
        r_lim_y <= '0';
      else
        r_lim_x <= lim_x_i;
        r_lim_y <= lim_y_i;
      end if;
    end if;
  end process;

  U_Cordic_Init : entity work.cordic_init
    generic map (
      g_M          => g_M,
      g_ANGLE_MODE => g_ANGLE_MODE)
    port map (
      clk_i         => clk_i,
      rst_i         => rst_i,
      cor_mode_i    => cor_mode_i,
      cor_submode_i => cor_submode_i,
      x0_i          => x0_i,
      y0_i          => y0_i,
      z0_i          => z0_int,
      x1_o          => x1,
      y1_o          => y1,
      z1_o          => z1,
      d1_o          => d1);

  U_Cordic_Core: entity work.cordic_xy_logic_nmhd
    generic map (
      g_N          => g_N-1,
      g_M          => g_M,
      g_ANGLE_MODE => g_ANGLE_MODE)
    port map (
      clk_i         => clk_i,
      rst_i         => rst_i,
      cor_mode_i    => cor_mode_i,
      cor_submode_i => cor_submode_i,
      d_i           => d1,
      fi1_i         => fi1(31 downto 31 - g_M - 1),
      lim_x_i       => r_lim_x,
      lim_y_i       => r_lim_y,
      xi_i          => x1,
      yi_i          => y1,
      zi_i          => z1,
      xj_o          => xn_o,
      yj_o          => yn_o,
      zj_o          => zj_int,
      lim_x_o       => lim_x_o,
      lim_y_o       => lim_y_o,
      rst_o         => rst_o_int);

  U_Fixup_Angle : entity work.cordic_modulo_360
    generic map (
      g_M          => g_M,
      g_ANGLE_MODE => g_ANGLE_MODE)
    port map (
      cor_submode_i => cor_submode_i,
      angle_i       => zj_int,
      angle_o       => zn_o,
      lim_o         => open);

  p_delay_reset : process(clk_i)
  begin
    if rising_edge(clk_i) then
      rst_o_int_d <= rst_o_int;
    end if;
  end process;

  rst_o <= rst_o_int_d or rst_o_int;
  
end rtl;
