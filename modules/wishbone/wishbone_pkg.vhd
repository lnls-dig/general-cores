library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

package wishbone_pkg is

  constant c_wishbone_address_width : integer := 32;
  constant c_wishbone_data_width    : integer := 32;

  subtype t_wishbone_address is
    std_logic_vector(c_wishbone_address_width-1 downto 0);
  subtype t_wishbone_data is
    std_logic_vector(c_wishbone_data_width-1 downto 0);
  subtype t_wishbone_byte_select is
    std_logic_vector((c_wishbone_address_width/8)-1 downto 0);
  subtype t_wishbone_cycle_type is
    std_logic_vector(2 downto 0);
  subtype t_wishbone_burst_type is
    std_logic_vector(1 downto 0);

  type t_wishbone_interface_mode is (CLASSIC, PIPELINED);

  type t_wishbone_master_out is record
    cyc : std_logic;
    stb : std_logic;
    adr : t_wishbone_address;
    sel : t_wishbone_byte_select;
    we  : std_logic;
    dat : t_wishbone_data;
  end record t_wishbone_master_out;

  subtype t_wishbone_slave_in is t_wishbone_master_out;

  type t_wishbone_slave_out is record
    ack   : std_logic;
    err   : std_logic;
    rty   : std_logic;
    stall : std_logic;
    int: std_logic;
    dat   : t_wishbone_data;
  end record t_wishbone_slave_out;
  subtype t_wishbone_master_in is t_wishbone_slave_out;

  subtype t_wishbone_device_descriptor is std_logic_vector(255 downto 0);

 

  type t_wishbone_master_out_array is array (natural range <>) of t_wishbone_master_out;
  type t_wishbone_slave_out_array  is array (natural range <>) of t_wishbone_slave_out;
  type t_wishbone_master_in_array is array (natural range <>) of t_wishbone_master_in;
  type t_wishbone_slave_in_array  is array (natural range <>) of t_wishbone_slave_in;

------------------------------------------------------------------------------
-- Components declaration
-------------------------------------------------------------------------------
  

  component xwb_i2c_master
    generic (
      g_interface_mode : t_wishbone_interface_mode := CLASSIC);
    port (
      clk_sys_i    : in  std_logic;
      rst_n_i      : in  std_logic;
      slave_i      : in  t_wishbone_slave_in;
      slave_o      : out t_wishbone_slave_out;
      desc_o       : out t_wishbone_device_descriptor;
      scl_pad_i    : in  std_logic;
      scl_pad_o    : out std_logic;
      scl_padoen_o : out std_logic;
      sda_pad_i    : in  std_logic;
      sda_pad_o    : out std_logic;
      sda_padoen_o : out std_logic);
  end component;

  component xwb_spi
    generic (
      g_interface_mode : t_wishbone_interface_mode := CLASSIC);
    port (
      clk_sys_i  : in  std_logic;
      rst_n_i    : in  std_logic;
      slave_i    : in  t_wishbone_slave_in;
      slave_o    : out t_wishbone_slave_out;
      desc_o     : out t_wishbone_device_descriptor;
      pad_cs_o   : out std_logic_vector(7 downto 0);
      pad_sclk_o : out std_logic;
      pad_mosi_o : out std_logic;
      pad_miso_i : in  std_logic);
  end component;

  component xwb_onewire_master
    generic (
      g_interface_mode   : t_wishbone_interface_mode := CLASSIC;
      g_num_ports        : integer := 1;
      g_ow_btp_normal    : string := "5.0";
      g_ow_btp_overdrive : string := "1.0");
    port (
      clk_sys_i   : in  std_logic;
      rst_n_i     : in  std_logic;
      slave_i     : in  t_wishbone_slave_in;
      slave_o     : out t_wishbone_slave_out;
      desc_o      : out t_wishbone_device_descriptor;
      owr_pwren_o : out std_logic_vector(g_num_ports -1 downto 0);
      owr_en_o    : out std_logic_vector(g_num_ports -1 downto 0);
      owr_i       : in  std_logic_vector(g_num_ports -1 downto 0));
  end component;

  component xwb_bus_fanout
    generic (
      g_num_outputs    : natural;
      g_bits_per_slave : integer := 14);
    port (
      clk_sys_i : in  std_logic;
      rst_n_i   : in  std_logic;
      slave_i   : in  t_wishbone_slave_in;
      slave_o   : out t_wishbone_slave_out;
      master_i  : in  t_wishbone_master_in_array(0 to g_num_outputs-1);
      master_o  : out t_wishbone_master_out_array(0 to g_num_outputs-1));
  end component;

  component xwb_gpio_port
    generic (
      g_interface_mode         : t_wishbone_interface_mode := CLASSIC;
      g_num_pins               : natural := 32;
      g_with_builtin_tristates : boolean := false);
    port (
      clk_sys_i  : in    std_logic;
      rst_n_i    : in    std_logic;
      slave_i    : in    t_wishbone_slave_in;
      slave_o    : out   t_wishbone_slave_out;
      desc_o     : out   t_wishbone_device_descriptor;
      gpio_b     : inout std_logic_vector(g_num_pins-1 downto 0);
      gpio_out_o : out   std_logic_vector(g_num_pins-1 downto 0);
      gpio_in_i  : in    std_logic_vector(g_num_pins-1 downto 0);
      gpio_oen_o : out   std_logic_vector(g_num_pins-1 downto 0));
  end component;
  
end wishbone_pkg;
