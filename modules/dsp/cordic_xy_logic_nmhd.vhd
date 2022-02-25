library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gc_cordic_pkg.all;

entity cordic_xy_logic_nmhd is
  generic(
    -- Number of XYlogicNHD cells instantiated
    g_N : positive;

    --M = Word-width (maximum = 32)
    g_M : positive;

    --AngleMode = Default angle format S8.7 otherwise FS = 180 deg.
    g_ANGLE_FORMAT : integer;

    g_USE_SATURATED_MATH : boolean
    );
  port (
    clk_i : in std_logic;
    rst_i : in std_logic;

    cor_mode_i    : in t_CORDIC_MODE;
    cor_submode_i : in t_CORDIC_SUBMODE;

    d_i   : in std_logic;
    fi1_i : in std_logic_vector(g_m-1 downto 0);

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

architecture rtl of cordic_xy_logic_nmhd is

  type t_xy_bus is array (0 to g_N-2) of std_logic_vector(g_M-1 downto 0);
  type t_z_bus is array (0 to g_N-2) of std_logic_vector(g_M downto 0);

  signal loc_Rst  : std_logic_vector(g_N-2 downto 0);
  signal loc_LimX : std_logic_vector(g_N-2 downto 0);
  signal loc_LimY : std_logic_vector(g_N-2 downto 0);

  signal loc_X : t_xy_bus;
  signal loc_Y : t_xy_bus;
  signal loc_Z : t_z_bus;


begin

  B_Cell0 : entity work.cordic_xy_logic_hd
    generic map(
      g_M                  => g_M,
      g_J                  => 0,
      g_USE_SATURATED_MATH => g_USE_SATURATED_MATH)
    port map(
      clk_i => clk_i,
      rst_i => rst_i,

      cor_submode_i => cor_submode_i,

      lim_x_i => lim_x_i,
      lim_y_i => lim_y_i,
      d_i     => d_i,
      xi_i    => xi_i,
      yi_i    => yi_i,
      Zi_i    => zi_i,

      fi_i    => fi1_i,
      rst_o   => loc_Rst(0),
      lim_x_o => loc_LimX(0),
      lim_y_o => loc_LimY(0),
      xj_o    => loc_X(0),
      yj_o    => loc_Y(0),
      zj_o    => loc_Z(0));


  B_CellN_1 : entity work.cordic_xy_logic_nhd
    generic map(
      g_M                  => g_M,
      g_J                  => g_N - 1,
      g_I                  => g_N - 1,
      g_ANGLE_FORMAT       => g_ANGLE_FORMAT,
      g_USE_SATURATED_MATH => g_USE_SATURATED_MATH)
    port map(
      clk_i => clk_i,
      rst_i => loc_Rst(g_N-2),

      cor_submode_i => cor_submode_i,
      cor_mode_i    => cor_mode_i,

      lim_x_i => loc_LimX(g_N-2),
      lim_y_i => loc_LimY(g_N-2),
      xi_i    => loc_X(g_N-2),
      yi_i    => loc_Y(g_N-2),
      zi_i    => loc_Z(g_N-2),

      Rst_o   => Rst_o,
      lim_x_o => lim_x_o,
      lim_y_o => lim_y_o,
      xj_o    => xj_o,
      yj_o    => yj_o,
      zj_o    => zj_o);

  GXYlogic : for K in 1 to g_N-2 generate
    B_CellN : entity work.cordic_xy_logic_nhd
      generic map(
        g_M                  => g_M,
        g_J                  => K,
        g_ANGLE_FORMAT       => g_ANGLE_FORMAT,
        g_I                  => K,
        g_USE_SATURATED_MATH => g_USE_SATURATED_MATH)
      port map(
        clk_i         => clk_i,
        rst_i         => loc_Rst(K-1),
        lim_x_i       => loc_LimX(K-1),
        lim_y_i       => loc_LimY(K-1),
        xi_i          => loc_X(K-1),
        yi_i          => loc_Y(K-1),
        zi_i          => loc_Z(K-1),
        cor_submode_i => cor_submode_i,
        cor_mode_i    => cor_mode_i,
        Rst_o         => loc_Rst(K),
        lim_x_o       => loc_LimX(K),
        lim_y_o       => loc_LimY(K),
        xj_o          => loc_X(K),
        yj_o          => loc_Y(K),
        zj_o          => loc_Z(K));
  end generate GXYlogic;

end rtl;






