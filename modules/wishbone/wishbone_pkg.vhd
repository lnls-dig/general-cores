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
  type t_wishbone_address_granularity is (BYTE, WORD);

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
    int   : std_logic;
    dat   : t_wishbone_data;
  end record t_wishbone_slave_out;
  subtype t_wishbone_master_in is t_wishbone_slave_out;

  subtype t_wishbone_device_descriptor is std_logic_vector(255 downto 0);



  type t_wishbone_address_array is array(integer range <>) of t_wishbone_address;
  type t_wishbone_master_out_array is array (natural range <>) of t_wishbone_master_out;
  type t_wishbone_slave_out_array is array (natural range <>) of t_wishbone_slave_out;
  type t_wishbone_master_in_array is array (natural range <>) of t_wishbone_master_in;
  type t_wishbone_slave_in_array is array (natural range <>) of t_wishbone_slave_in;


  constant cc_dummy_address : std_logic_vector(c_wishbone_address_width-1 downto 0):=
    (others => 'X');
  constant cc_dummy_data : std_logic_vector(c_wishbone_address_width-1 downto 0) :=
    (others => 'X');
  constant cc_dummy_sel : std_logic_vector(c_wishbone_data_width/8-1 downto 0) :=
    (others => 'X');
  constant cc_dummy_slave_in : t_wishbone_slave_in :=
    ('X', 'X', cc_dummy_address, cc_dummy_sel, 'X', cc_dummy_data);
  constant cc_dummy_slave_out : t_wishbone_slave_out :=
    ('X', 'X', 'X', 'X', 'X', cc_dummy_data);


------------------------------------------------------------------------------
-- Components declaration
-------------------------------------------------------------------------------

  component wb_slave_adapter
    generic (
      g_master_use_struct  : boolean;
      g_master_mode        : t_wishbone_interface_mode;
      g_master_granularity : t_wishbone_address_granularity;
      g_slave_use_struct   : boolean;
      g_slave_mode         : t_wishbone_interface_mode;
      g_slave_granularity  : t_wishbone_address_granularity);
    port (
      clk_sys_i  : in  std_logic;
      rst_n_i    : in  std_logic;
      sl_adr_i   : in  std_logic_vector(c_wishbone_address_width-1 downto 0) := cc_dummy_address;
      sl_dat_i   : in  std_logic_vector(c_wishbone_data_width-1 downto 0)    := cc_dummy_data;
      sl_sel_i   : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0)  := cc_dummy_sel;
      sl_cyc_i   : in  std_logic                                             := '0';
      sl_stb_i   : in  std_logic                                             := '0';
      sl_we_i    : in  std_logic                                             := '0';
      sl_dat_o   : out std_logic_vector(c_wishbone_data_width-1 downto 0);
      sl_err_o   : out std_logic;
      sl_rty_o   : out std_logic;
      sl_ack_o   : out std_logic;
      sl_stall_o : out std_logic;
      sl_int_o   : out std_logic;
      slave_i    : in  t_wishbone_slave_in                                   := cc_dummy_slave_in;
      slave_o    : out t_wishbone_slave_out;
      ma_adr_o   : out std_logic_vector(c_wishbone_address_width-1 downto 0);
      ma_dat_o   : out std_logic_vector(c_wishbone_data_width-1 downto 0);
      ma_sel_o   : out std_logic_vector(c_wishbone_data_width/8-1 downto 0);
      ma_cyc_o   : out std_logic;
      ma_stb_o   : out std_logic;
      ma_we_o    : out std_logic;
      ma_dat_i   : in  std_logic_vector(c_wishbone_data_width-1 downto 0)    := cc_dummy_data;
      ma_err_i   : in  std_logic                                             := '0';
      ma_rty_i   : in  std_logic                                             := '0';
      ma_ack_i   : in  std_logic                                             := '0';
      ma_stall_i : in  std_logic                                             := '0';
      ma_int_i   : in  std_logic                                             := '0';
      master_i   : in  t_wishbone_master_in                                  := cc_dummy_slave_out;
      master_o   : out t_wishbone_master_out);
  end component;

  component wb_async_bridge
    generic (
      g_simulation          : integer;
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD;
      g_cpu_address_width   : integer);
    port (
      rst_n_i     : in    std_logic;
      clk_sys_i   : in    std_logic;
      cpu_cs_n_i  : in    std_logic;
      cpu_wr_n_i  : in    std_logic;
      cpu_rd_n_i  : in    std_logic;
      cpu_bs_n_i  : in    std_logic_vector(3 downto 0);
      cpu_addr_i  : in    std_logic_vector(g_cpu_address_width-1 downto 0);
      cpu_data_b  : inout std_logic_vector(31 downto 0);
      cpu_nwait_o : out   std_logic;
      wb_adr_o    : out   std_logic_vector(c_wishbone_address_width - 1 downto 0);
      wb_dat_o    : out   std_logic_vector(31 downto 0);
      wb_stb_o    : out   std_logic;
      wb_we_o     : out   std_logic;
      wb_sel_o    : out   std_logic_vector(3 downto 0);
      wb_cyc_o    : out   std_logic;
      wb_dat_i    : in    std_logic_vector (c_wishbone_data_width-1 downto 0);
      wb_ack_i    : in    std_logic;
      wb_stall_i  : in    std_logic := '0');
  end component;

  component xwb_async_bridge
    generic (
      g_simulation          : integer;
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD;
      g_cpu_address_width   : integer);
    port (
      rst_n_i     : in    std_logic;
      clk_sys_i   : in    std_logic;
      cpu_cs_n_i  : in    std_logic;
      cpu_wr_n_i  : in    std_logic;
      cpu_rd_n_i  : in    std_logic;
      cpu_bs_n_i  : in    std_logic_vector(3 downto 0);
      cpu_addr_i  : in    std_logic_vector(g_cpu_address_width-1 downto 0);
      cpu_data_b  : inout std_logic_vector(31 downto 0);
      cpu_nwait_o : out   std_logic;
      master_o    : out   t_wishbone_master_out;
      master_i    : in    t_wishbone_master_in);
  end component;

  component xwb_bus_fanout
    generic (
      g_num_outputs          : natural;
      g_bits_per_slave       : integer;
      g_address_granularity  : t_wishbone_address_granularity := WORD;
      g_slave_interface_mode : t_wishbone_interface_mode      := CLASSIC);
    port (
      clk_sys_i : in  std_logic;
      rst_n_i   : in  std_logic;
      slave_i   : in  t_wishbone_slave_in;
      slave_o   : out t_wishbone_slave_out;
      master_i  : in  t_wishbone_master_in_array(0 to g_num_outputs-1);
      master_o  : out t_wishbone_master_out_array(0 to g_num_outputs-1));
  end component;

  component xwb_crossbar
    generic (
      g_num_masters : integer;
      g_num_slaves  : integer;
      g_registered  : boolean);
    port (
      clk_sys_i     : in  std_logic;
      rst_n_i       : in  std_logic;
      slave_i       : in  t_wishbone_slave_in_array(g_num_masters-1 downto 0);
      slave_o       : out t_wishbone_slave_out_array(g_num_masters-1 downto 0);
      master_i      : in  t_wishbone_master_in_array(g_num_slaves-1 downto 0);
      master_o      : out t_wishbone_master_out_array(g_num_slaves-1 downto 0);
      cfg_address_i : in  t_wishbone_address_array(g_num_slaves-1 downto 0);
      cfg_mask_i    : in  t_wishbone_address_array(g_num_slaves-1 downto 0));
  end component;

  component xwb_dpram
    generic (
      g_size                  : natural;
      g_init_file             : string                         := "";
      g_must_have_init_file   : boolean                        := true;
      g_slave1_interface_mode : t_wishbone_interface_mode      := CLASSIC;
      g_slave2_interface_mode : t_wishbone_interface_mode      := CLASSIC;
      g_slave1_granularity    : t_wishbone_address_granularity := WORD;
      g_slave2_granularity    : t_wishbone_address_granularity := WORD);
    port (
      clk_sys_i : in  std_logic;
      rst_n_i   : in  std_logic;
      slave1_i  : in  t_wishbone_slave_in;
      slave1_o  : out t_wishbone_slave_out;
      slave2_i  : in  t_wishbone_slave_in;
      slave2_o  : out t_wishbone_slave_out);
  end component;

  component wb_gpio_port
    generic (
      g_interface_mode         : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity    : t_wishbone_address_granularity := WORD;
      g_num_pins               : natural range 1 to 256;
      g_with_builtin_tristates : boolean                        := false);
    port (
      clk_sys_i  : in    std_logic;
      rst_n_i    : in    std_logic;
      wb_sel_i   : in    std_logic_vector(c_wishbone_data_width/8-1 downto 0);
      wb_cyc_i   : in    std_logic;
      wb_stb_i   : in    std_logic;
      wb_we_i    : in    std_logic;
      wb_adr_i   : in    std_logic_vector(7 downto 0);
      wb_dat_i   : in    std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_dat_o   : out   std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_ack_o   : out   std_logic;
      wb_stall_o : out   std_logic;
      gpio_b     : inout std_logic_vector(g_num_pins-1 downto 0);
      gpio_out_o : out   std_logic_vector(g_num_pins-1 downto 0);
      gpio_in_i  : in    std_logic_vector(g_num_pins-1 downto 0);
      gpio_oen_o : out   std_logic_vector(g_num_pins-1 downto 0));
  end component;

  component xwb_gpio_port
    generic (
      g_interface_mode         : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity    : t_wishbone_address_granularity := WORD;
      g_num_pins               : natural range 1 to 256;
      g_with_builtin_tristates : boolean);
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

  component wb_i2c_master
    generic (
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD);
    port (
      clk_sys_i    : in  std_logic;
      rst_n_i      : in  std_logic;
      wb_adr_i     : in  std_logic_vector(4 downto 0);
      wb_dat_i     : in  std_logic_vector(31 downto 0);
      wb_dat_o     : out std_logic_vector(31 downto 0);
      wb_sel_i     : in  std_logic_vector(3 downto 0);
      wb_stb_i     : in  std_logic;
      wb_cyc_i     : in  std_logic;
      wb_we_i      : in  std_logic;
      wb_ack_o     : out std_logic;
      wb_int_o     : out std_logic;
      wb_stall_o   : out std_logic;
      scl_pad_i    : in  std_logic;
      scl_pad_o    : out std_logic;
      scl_padoen_o : out std_logic;
      sda_pad_i    : in  std_logic;
      sda_pad_o    : out std_logic;
      sda_padoen_o : out std_logic);
  end component;

  component xwb_i2c_master
    generic (
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD);
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

  component xwb_lm32
    generic (
      g_profile : string);
    port (
      clk_sys_i : in  std_logic;
      rst_n_i   : in  std_logic;
      irq_i     : in  std_logic_vector(31 downto 0);
      dwb_o     : out t_wishbone_master_out;
      dwb_i     : in  t_wishbone_master_in;
      iwb_o     : out t_wishbone_master_out;
      iwb_i     : in  t_wishbone_master_in);
  end component;

  component wb_onewire_master
    generic (
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD;
      g_num_ports           : integer;
      g_ow_btp_normal       : string                         := "1.0";
      g_ow_btp_overdrive    : string                         := "5.0");
    port (
      clk_sys_i   : in  std_logic;
      rst_n_i     : in  std_logic;
      wb_cyc_i    : in  std_logic;
      wb_sel_i    : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0);
      wb_stb_i    : in  std_logic;
      wb_we_i     : in  std_logic;
      wb_adr_i    : in  std_logic_vector(2 downto 0);
      wb_dat_i    : in  std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_dat_o    : out std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_ack_o    : out std_logic;
      wb_int_o    : out std_logic;
      wb_stall_o  : out std_logic;
      owr_pwren_o : out std_logic_vector(g_num_ports -1 downto 0);
      owr_en_o    : out std_logic_vector(g_num_ports -1 downto 0);
      owr_i       : in  std_logic_vector(g_num_ports -1 downto 0));
  end component;

  component xwb_onewire_master
    generic (
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD;
      g_num_ports           : integer;
      g_ow_btp_normal       : string                         := "5.0";
      g_ow_btp_overdrive    : string                         := "1.0");
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

  component wb_spi
    generic (
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD);
    port (
      clk_sys_i  : in  std_logic;
      rst_n_i    : in  std_logic;
      wb_adr_i   : in  std_logic_vector(4 downto 0);
      wb_dat_i   : in  std_logic_vector(31 downto 0);
      wb_dat_o   : out std_logic_vector(31 downto 0);
      wb_sel_i   : in  std_logic_vector(3 downto 0);
      wb_stb_i   : in  std_logic;
      wb_cyc_i   : in  std_logic;
      wb_we_i    : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_err_o   : out std_logic;
      wb_int_o   : out std_logic;
      wb_stall_o : out std_logic;
      pad_cs_o   : out std_logic_vector(7 downto 0);
      pad_sclk_o : out std_logic;
      pad_mosi_o : out std_logic;
      pad_miso_i : in  std_logic);
  end component;

  component xwb_spi
    generic (
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD);
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

  component wb_simple_uart
    generic (
      g_with_virtual_uart   : boolean                        := false;
      g_with_physical_uart  : boolean                        := true;
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD);
    port (
      clk_sys_i  : in  std_logic;
      rst_n_i    : in  std_logic;
      wb_adr_i   : in  std_logic_vector(4 downto 0);
      wb_dat_i   : in  std_logic_vector(31 downto 0);
      wb_dat_o   : out std_logic_vector(31 downto 0);
      wb_cyc_i   : in  std_logic;
      wb_sel_i   : in  std_logic_vector(3 downto 0);
      wb_stb_i   : in  std_logic;
      wb_we_i    : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_stall_o : out std_logic;
      uart_rxd_i : in  std_logic := '1';
      uart_txd_o : out std_logic);
  end component;

  component xwb_simple_uart
    generic (
      g_with_virtual_uart   : boolean                        := false;
      g_with_physical_uart  : boolean                        := true;
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD);
    port (
      clk_sys_i  : in  std_logic;
      rst_n_i    : in  std_logic;
      slave_i    : in  t_wishbone_slave_in;
      slave_o    : out t_wishbone_slave_out;
      desc_o     : out t_wishbone_device_descriptor;
      uart_rxd_i : in  std_logic := '1';
      uart_txd_o : out std_logic);
  end component;

  component wb_tics
    generic (
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD;
      g_period              : integer);
    port (
      rst_n_i    : in  std_logic;
      clk_sys_i  : in  std_logic;
      wb_adr_i   : in  std_logic_vector(3 downto 0);
      wb_dat_i   : in  std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_dat_o   : out std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_cyc_i   : in  std_logic;
      wb_sel_i   : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0);
      wb_stb_i   : in  std_logic;
      wb_we_i    : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_stall_o : out std_logic);
  end component;

  component xwb_tics
    generic (
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD;
      g_period              : integer);
    port (
      clk_sys_i : in  std_logic;
      rst_n_i   : in  std_logic;
      slave_i   : in  t_wishbone_slave_in;
      slave_o   : out t_wishbone_slave_out;
      desc_o    : out t_wishbone_device_descriptor);
  end component;

  component wb_vic
    generic (
      g_interface_mode      : t_wishbone_interface_mode;
      g_address_granularity : t_wishbone_address_granularity;
      g_num_interrupts      : natural);
    port (
      clk_sys_i    : in  std_logic;
      rst_n_i      : in  std_logic;
      wb_adr_i     : in  std_logic_vector(c_wishbone_address_width-1 downto 0);
      wb_dat_i     : in  std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_dat_o     : out std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_cyc_i     : in  std_logic;
      wb_sel_i     : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0);
      wb_stb_i     : in  std_logic;
      wb_we_i      : in  std_logic;
      wb_ack_o     : out std_logic;
      wb_stall_o   : out std_logic;
      irqs_i       : in  std_logic_vector(g_num_interrupts-1 downto 0);
      irq_master_o : out std_logic);
  end component;

  component xwb_vic
    generic (
      g_interface_mode      : t_wishbone_interface_mode;
      g_address_granularity : t_wishbone_address_granularity;
      g_num_interrupts      : natural);
    port (
      clk_sys_i    : in  std_logic;
      rst_n_i      : in  std_logic;
      slave_i      : in  t_wishbone_slave_in;
      slave_o      : out t_wishbone_slave_out;
      irqs_i       : in  std_logic_vector(g_num_interrupts-1 downto 0);
      irq_master_o : out std_logic);
  end component;
end wishbone_pkg;
