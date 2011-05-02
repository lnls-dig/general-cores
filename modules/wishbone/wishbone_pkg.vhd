library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

package wishbone_pkg is

-- number of wishbone masters provided by CPU->WB bridge
--  constant c_wishbone_num_masters : integer := 12;
-- CPU address bus width
  constant c_cpu_addr_width      : integer := 19;
-- WB address bus width. Must be log2(c_wishbone_num_masters) smaller than
-- c_cpu_addr_width as the most significant bits select the master port (peripheral)
  constant c_wishbone_addr_width : integer := 14;


  component wb_cpu_bridge
    generic (
      g_simulation :integer := 0;
      g_wishbone_num_masters : integer);
    port (
      sys_rst_n_i : in    std_logic;
      cpu_clk_i   : in    std_logic;
      cpu_cs_n_i  : in    std_logic;
      cpu_wr_n_i  : in    std_logic;
      cpu_rd_n_i  : in    std_logic;
      cpu_bs_n_i  : in    std_logic_vector(3 downto 0);
      cpu_addr_i  : in    std_logic_vector(c_cpu_addr_width-1 downto 0);
      cpu_data_b  : inout std_logic_vector(31 downto 0);
      cpu_nwait_o : out   std_logic;
      wb_clk_i    : in    std_logic;
      wb_addr_o   : out   std_logic_vector(c_wishbone_addr_width - 1 downto 0);
      wb_data_o   : out   std_logic_vector(31 downto 0);
      wb_stb_o    : out   std_logic;
      wb_we_o     : out   std_logic;
      wb_sel_o    : out   std_logic_vector(3 downto 0);
      wb_cyc_o    : out   std_logic_vector (g_wishbone_num_masters - 1 downto 0);
      wb_data_i   : in    std_logic_vector (32 * g_wishbone_num_masters-1 downto 0);
      wb_ack_i    : in    std_logic_vector(g_wishbone_num_masters-1 downto 0));
  end component;

  component wb_gpio_port
    generic (
      g_num_pins : natural);
    port (
      sys_rst_n_i : in    std_logic;
      wb_clk_i    : in    std_logic;
      wb_sel_i    : in    std_logic;
      wb_cyc_i    : in    std_logic;
      wb_stb_i    : in    std_logic;
      wb_we_i     : in    std_logic;
      wb_addr_i   : in    std_logic_vector(2 downto 0);
      wb_data_i   : in    std_logic_vector(31 downto 0);
      wb_data_o   : out   std_logic_vector(31 downto 0);
      wb_ack_o    : out   std_logic;
      gpio_b      : inout std_logic_vector(g_num_pins-1 downto 0));
  end component;

  component wb_spi_master
    port (
      refclk2_i   : in  std_logic;
      sys_rst_n_i : in  std_logic;
      wb_sel_i    : in  std_logic;
      wb_cyc_i    : in  std_logic;
      wb_stb_i    : in  std_logic;
      wb_we_i     : in  std_logic;
      wb_addr_i   : in  std_logic_vector(c_wishbone_addr_width-1 downto 0);
      wb_data_i   : in  std_logic_vector(31 downto 0);
      wb_data_o   : out std_logic_vector(31 downto 0);
      wb_ack_o    : out std_logic;
      spi_mosi_o  : out std_logic;
      spi_miso_i  : in  std_logic;
      spi_cs_o    : out std_logic;
      spi_sck_o   : out std_logic);
  end component;

  component wb_vic
    generic (
      g_num_interrupts : natural);
    port (
      rst_n_i      : in  std_logic;
      wb_clk_i     : in  std_logic;
      wb_addr_i    : in  std_logic_vector(5 downto 0);
      wb_data_i    : in  std_logic_vector(31 downto 0);
      wb_data_o    : out std_logic_vector(31 downto 0);
      wb_cyc_i     : in  std_logic;
      wb_sel_i     : in  std_logic_vector(3 downto 0);
      wb_stb_i     : in  std_logic;
      wb_we_i      : in  std_logic;
      wb_ack_o     : out std_logic;
      irqs_i       : in  std_logic_vector(g_num_interrupts-1 downto 0);
      irq_master_o : out std_logic);
  end component;

end wishbone_pkg;
