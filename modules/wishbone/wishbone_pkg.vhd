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

end wishbone_pkg;
