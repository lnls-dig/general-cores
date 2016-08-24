--------------------------------------------------------------------------------
--  Modifications:
--      2016-08-24: by Jan Pospisil (j.pospisil@cern.ch)
--          * added assignments to (new) unspecified WB signals
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity xwb_i2c_master is
  generic(
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD;
    g_num_interfaces      : integer := 1);
  port (
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;
    desc_o  : out t_wishbone_device_descriptor;

    scl_pad_i    : in  std_logic_vector(g_num_interfaces-1 downto 0);  -- i2c clock line input
    scl_pad_o    : out std_logic_vector(g_num_interfaces-1 downto 0);  -- i2c clock line output
    scl_padoen_o : out std_logic_vector(g_num_interfaces-1 downto 0);  -- i2c clock line output enable, active low
    sda_pad_i    : in  std_logic_vector(g_num_interfaces-1 downto 0);  -- i2c data line input
    sda_pad_o    : out std_logic_vector(g_num_interfaces-1 downto 0);  -- i2c data line output
    sda_padoen_o : out std_logic_vector(g_num_interfaces-1 downto 0)   -- i2c data line output enable, active low
    );
end xwb_i2c_master;

architecture rtl of xwb_i2c_master is

  component wb_i2c_master
    generic (
      g_interface_mode      : t_wishbone_interface_mode;
      g_address_granularity : t_wishbone_address_granularity;
      g_num_interfaces      : integer := 1);
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
      scl_pad_i    : in  std_logic_vector(g_num_interfaces-1 downto 0);
      scl_pad_o    : out std_logic_vector(g_num_interfaces-1 downto 0);
      scl_padoen_o : out std_logic_vector(g_num_interfaces-1 downto 0);
      sda_pad_i    : in  std_logic_vector(g_num_interfaces-1 downto 0);
      sda_pad_o    : out std_logic_vector(g_num_interfaces-1 downto 0);
      sda_padoen_o : out std_logic_vector(g_num_interfaces-1 downto 0));
  end component;

begin  -- rtl


  U_Wrapped_I2C : wb_i2c_master
    generic map (
      g_interface_mode      => g_interface_mode,
      g_address_granularity => g_address_granularity,
      g_num_interfaces      => g_num_interfaces)
    port map (
      clk_sys_i    => clk_sys_i,
      rst_n_i      => rst_n_i,
      wb_adr_i     => slave_i.adr(4 downto 0),
      wb_dat_i     => slave_i.dat,
      wb_dat_o     => slave_o.dat,
      wb_sel_i     => slave_i.sel,
      wb_stb_i     => slave_i.stb,
      wb_cyc_i     => slave_i.cyc,
      wb_we_i      => slave_i.we,
      wb_ack_o     => slave_o.ack,
      wb_int_o     => slave_o.int,
      wb_stall_o   => slave_o.stall,
      scl_pad_i    => scl_pad_i,
      scl_pad_o    => scl_pad_o,
      scl_padoen_o => scl_padoen_o,
      sda_pad_i    => sda_pad_i,
      sda_pad_o    => sda_pad_o,
      sda_padoen_o => sda_padoen_o);
  
  slave_o.err <= '0';
  slave_o.rty <= '0';
end rtl;

