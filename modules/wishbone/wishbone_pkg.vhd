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



  type t_wishbone_address_array is array(natural range <>) of t_wishbone_address;
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
    ('0', 'X', cc_dummy_address, cc_dummy_sel, 'X', cc_dummy_data);
  constant cc_dummy_master_out : t_wishbone_master_out := cc_dummy_slave_in;
  
  -- Dangerous! Will stall a bus.
  constant cc_dummy_slave_out : t_wishbone_slave_out :=
    ('X', 'X', 'X', 'X', 'X', cc_dummy_data);
  constant cc_dummy_master_in : t_wishbone_master_in := cc_dummy_slave_out;

  -- A generally useful function.
  function f_ceil_log2(x : natural) return natural;
  
------------------------------------------------------------------------------
-- SDWB declaration
------------------------------------------------------------------------------
  constant c_sdwb_device_length : natural := 512; -- bits
  type t_sdwb_device is record
    wbd_begin          : unsigned(63 downto 0);
    wbd_end            : unsigned(63 downto 0);
    sdwb_child         : unsigned(63 downto 0);
    wbd_flags          : std_logic_vector(7 downto 0);
    wbd_width          : std_logic_vector(7 downto 0);
    abi_ver_major      : unsigned(7 downto 0);
    abi_ver_minor      : unsigned(7 downto 0);
    abi_class          : std_logic_vector(31 downto 0);
    dev_vendor         : std_logic_vector(31 downto 0);
    dev_device         : std_logic_vector(31 downto 0);
    dev_version        : std_logic_vector(31 downto 0);
    dev_date           : std_logic_vector(31 downto 0);
    description        : string(1 to 16);
  end record t_sdwb_device;
  type t_sdwb_device_array is array(natural range <>) of t_sdwb_device;
  
  -- Used to configure a device at a certain address
  function f_sdwb_set_address(device : t_sdwb_device; address : t_wishbone_address)
    return t_sdwb_device;

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
      g_registered  : boolean;
      g_address     : t_wishbone_address_array;
      g_mask        : t_wishbone_address_array);
    port (
      clk_sys_i     : in  std_logic;
      rst_n_i       : in  std_logic;
      slave_i       : in  t_wishbone_slave_in_array(g_num_masters-1 downto 0);
      slave_o       : out t_wishbone_slave_out_array(g_num_masters-1 downto 0);
      master_i      : in  t_wishbone_master_in_array(g_num_slaves-1 downto 0);
      master_o      : out t_wishbone_master_out_array(g_num_slaves-1 downto 0));
  end component;

  -- Use the f_xwb_bridge_*_sdwb to bridge a crossbar to another
  function f_xwb_bridge_manual_sdwb( -- take a manual bus size
      g_bus_end     : t_wishbone_address;
      g_sdwb_addr   : t_wishbone_address) return t_sdwb_device;
  function f_xwb_bridge_layout_sdwb( -- determine bus size from layout
      g_wraparound  : boolean := true;
      g_layout      : t_sdwb_device_array;
      g_sdwb_addr   : t_wishbone_address) return t_sdwb_device;
  component xwb_sdwb_crossbar
    generic (
      g_num_masters : integer;
      g_num_slaves  : integer;
      g_registered  : boolean := false;
      g_wraparound  : boolean := true;
      g_layout      : t_sdwb_device_array;
      g_sdwb_addr   : t_wishbone_address);
    port (
      clk_sys_i     : in  std_logic;
      rst_n_i       : in  std_logic;
      slave_i       : in  t_wishbone_slave_in_array(g_num_masters-1 downto 0);
      slave_o       : out t_wishbone_slave_out_array(g_num_masters-1 downto 0);
      master_i      : in  t_wishbone_master_in_array(g_num_slaves-1 downto 0);
      master_o      : out t_wishbone_master_out_array(g_num_slaves-1 downto 0));
  end component;

  component sdwb_rom is
    generic(
      g_layout      : t_sdwb_device_array;
      g_bus_end     : unsigned(63 downto 0));
    port(
      clk_sys_i     : in  std_logic;
      slave_i       : in  t_wishbone_slave_in;
      slave_o       : out t_wishbone_slave_out);
  end component;
  
  component xwb_dma is
    generic(
      -- Value 0 cannot stream
      -- Value 1 only slaves with async ACK can stream
      -- Value 2 only slaves with combined latency <= 2 can stream
      -- Value 3 only slaves with combined latency <= 6 can stream
      -- Value 4 only slaves with combined latency <= 14 can stream
      -- ....
      logRingLen : integer := 4
    );
    port(
      -- Common wishbone signals
      clk_i       : in  std_logic;
      rst_n_i     : in  std_logic;
      -- Slave control port
      slave_i     : in  t_wishbone_slave_in;
      slave_o     : out t_wishbone_slave_out;
      -- Master reader port
      r_master_i  : in  t_wishbone_master_in;
      r_master_o  : out t_wishbone_master_out;
      -- Master writer port
      w_master_i  : in  t_wishbone_master_in;
      w_master_o  : out t_wishbone_master_out;
      -- Pulsed high completion signal
      interrupt_o : out std_logic
    );
  end component;
  
  component xwb_clock_crossing is
    generic(
      sync_depth : natural := 2;
      log2fifo   : natural := 4);
    port(
      -- Common wishbone signals
      rst_n_i      : in  std_logic;
      -- Slave control port
      slave_clk_i  : in  std_logic;
      slave_i      : in  t_wishbone_slave_in;
      slave_o      : out t_wishbone_slave_out;
      -- Master reader port
      master_clk_i : in  std_logic;
      master_i     : in  t_wishbone_master_in;
      master_o     : out t_wishbone_master_out);
  end component;
  
  -- g_size is in words
  function f_xwb_dpram(g_size : natural) return t_sdwb_device;
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

package body wishbone_pkg is
  function f_ceil_log2(x : natural) return natural is
  begin
    if x <= 1
    then return 0;
    else return f_ceil_log2((x+1)/2) +1;
    end if;
  end f_ceil_log2;
  
  -- Used to configure a device at a certain address
  function f_sdwb_set_address(device : t_sdwb_device; address : t_wishbone_address)
    return t_sdwb_device
  is
    variable result : t_sdwb_device;
  begin
    result := device;
    result.wbd_begin := (others => '0');
    
    result.wbd_begin(c_wishbone_address_width-1 downto 0) := unsigned(address);
    result.wbd_end := result.wbd_begin + (device.wbd_end - device.wbd_begin);
    
    -- If it has a child, remap the SDWB record address as well
    if result.wbd_flags(2) = '1' then
      result.sdwb_child := result.wbd_begin + (device.sdwb_child  - device.wbd_begin);
    end if;
    return result;
  end;
  
  function f_xwb_bridge_manual_sdwb(
    g_bus_end     : t_wishbone_address;
    g_sdwb_addr   : t_wishbone_address) return t_sdwb_device
  is
    variable result : t_sdwb_device;
  begin
    result.wbd_begin  := x"0000000000000000";
    result.wbd_end    := x"0000000000000000";
    result.sdwb_child := x"0000000000000000";
    
    result.wbd_end   (c_wishbone_address_width-1 downto 0) := unsigned(g_bus_end);
    result.sdwb_child(c_wishbone_address_width-1 downto 0) := unsigned(g_sdwb_addr);
    
    result.wbd_flags := x"05"; -- present, bigendian, child
    result.wbd_width := std_logic_vector(to_unsigned(c_wishbone_address_width/4 - 1, 8));
    
    result.abi_ver_major := x"01";
    result.abi_ver_minor := x"00";
    result.abi_class     := x"00000002"; -- bridge device
    
    result.dev_vendor  := x"00000651"; -- GSI
    result.dev_device  := x"eef0b198";
    result.dev_version := x"00000001";
    result.dev_date    := x"20120305";
    result.description := "WB4-Bridge-GSI  ";
    
    return result;
  end f_xwb_bridge_manual_sdwb;
  
  function f_xwb_bridge_layout_sdwb(
    g_wraparound  : boolean := true;
    g_layout      : t_sdwb_device_array;
    g_sdwb_addr   : t_wishbone_address) return t_sdwb_device
  is
    alias c_layout : t_sdwb_device_array(g_layout'length-1 downto 0) is g_layout;

    -- How much space does the ROM need?
    constant c_used_entries : natural := c_layout'length + 1;
    constant c_rom_entries  : natural := 2**f_ceil_log2(c_used_entries); -- next power of 2
    constant c_sdwb_bytes   : natural := c_sdwb_device_length / 8;
    constant c_rom_bytes    : natural := c_rom_entries * c_sdwb_bytes;
    
    -- Step 2. Find the size of the bus
    function f_bus_end return unsigned is
      variable result : unsigned(63 downto 0);
    begin
      if not g_wraparound then
        result := (others => '0');
        for i in 0 to c_wishbone_address_width-1 loop
          result(i) := '1';
        end loop;
      else
        -- The ROM will be an addressed slave as well
        result := (others => '0');
        result(c_wishbone_address_width-1 downto 0) := unsigned(g_sdwb_addr);
        result := result + to_unsigned(c_rom_bytes, 64) - 1;
        
        for i in c_layout'range loop
          if c_layout(i).wbd_end > result then
            result := c_layout(i).wbd_end;
          end if;
        end loop;
        -- round result up to a power of two -1
        for i in 62 downto 0 loop
          result(i) := result(i) or result(i+1);
        end loop;
      end if;
      return result;
    end f_bus_end;
    
    constant bus_end : unsigned(63 downto 0) := f_bus_end;
  begin
    return f_xwb_bridge_manual_sdwb(std_logic_vector(f_bus_end(c_wishbone_address_width-1 downto 0)), g_sdwb_addr);
  end f_xwb_bridge_layout_sdwb;
  
  function f_xwb_dpram(g_size : natural) return t_sdwb_device
  is
    variable result : t_sdwb_device;
  begin
    result.wbd_begin  := x"0000000000000000";
    result.sdwb_child := x"0000000000000000";
    
    result.wbd_end    := to_unsigned(g_size*4-1, 64);
    
    result.wbd_flags := x"01"; -- present, bigendian, no-child
    result.wbd_width := std_logic_vector(to_unsigned(c_wishbone_address_width/4 - 1, 8));
    
    result.abi_ver_major := x"01";
    result.abi_ver_minor := x"00";
    result.abi_class     := x"00000002"; -- bridge device
    
    result.dev_vendor  := x"0000CE42"; -- CERN
    result.dev_device  := x"66cfeb52";
    result.dev_version := x"00000001";
    result.dev_date    := x"20120305";
    result.description := "WB4-BlockRAM    ";
    
    return result;
  end f_xwb_dpram;
end wishbone_pkg;
