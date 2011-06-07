library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity xwb_gpio_port is
  generic(
    g_interface_mode         : t_wishbone_interface_mode := CLASSIC;
    g_num_pins               : natural                   := 8;
    g_with_builtin_tristates : boolean                   := false
    );

  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    -- Wishbone
    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;
    desc_o  : out t_wishbone_device_descriptor;

    gpio_b : inout std_logic_vector(g_num_pins-1 downto 0);

    gpio_out_o : out std_logic_vector(g_num_pins-1 downto 0);
    gpio_in_i  : in  std_logic_vector(g_num_pins-1 downto 0);
    gpio_oen_o : out std_logic_vector(g_num_pins-1 downto 0)

    );

end xwb_gpio_port;

architecture rtl of xwb_gpio_port is

  component wb_gpio_port
    generic (
      g_num_pins               : natural;
      g_with_builtin_tristates : boolean);
    port (
      clk_sys_i  : in    std_logic;
      rst_n_i    : in    std_logic;
      wb_sel_i   : in    std_logic;
      wb_cyc_i   : in    std_logic;
      wb_stb_i   : in    std_logic;
      wb_we_i    : in    std_logic;
      wb_adr_i   : in    std_logic_vector(2 downto 0);
      wb_dat_i   : in    std_logic_vector(31 downto 0);
      wb_dat_o   : out   std_logic_vector(31 downto 0);
      wb_ack_o   : out   std_logic;
      gpio_b     : inout std_logic_vector(g_num_pins-1 downto 0);
      gpio_out_o : out   std_logic_vector(g_num_pins-1 downto 0);
      gpio_in_i  : in    std_logic_vector(g_num_pins-1 downto 0);
      gpio_oen_o : out   std_logic_vector(g_num_pins-1 downto 0));
  end component;

begin  -- rtl

  gen_test_mode : if(g_interface_mode /= CLASSIC) generate
    report "xwb_gpio_port: this module can only work with CLASSIC wishbone interface" severity failure;
  end generate gen_test_mode;

  Wrapped_GPIO : wb_gpio_port
    generic map (
      g_num_pins               => g_num_pins,
      g_with_builtin_tristates => g_with_builtin_tristates)
    port map (
      clk_sys_i => clk_sys_i,
      rst_n_i   => rst_n_i,
      wb_sel_i  => slave_i.sel,
      wb_cyc_i  => slave_i.cyc,
      wb_stb_i  => slave_i.stb,
      wb_we_i   => slave_i.we,
      wb_adr_i  => slave_i.adr(2 downto 0),
      wb_dat_i  => slave_i.dat(31 downto 0),
      wb_dat_o  => slave_o.dat(31 downto 0),
      wb_ack_o  => slave_o.ack,

      gpio_b     => gpio_b,
      gpio_out_o => gpio_out_o,
      gpio_in_i  => gpio_in_i,
      gpio_oen_o => gpio_oen_o);

  slave_o.stall <= '0';
  slave_o.err   <= '0';
  slave_o.int   <= '0';
  slave_o.rty   <= '0';
  
end rtl;
