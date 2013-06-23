library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity lm32_test_system is
  
  port (
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    gpio_b    : inout std_logic_vector(31 downto 0);
    onewire_b : inout std_logic;
    txd_o     : out   std_logic;
    rxd_i     : in    std_logic
    );

end lm32_test_system;

architecture rtl of lm32_test_system is  
  constant c_cnx_slave_ports  : integer := 2;
  constant c_cnx_master_ports : integer := 3;

  constant c_peripherals : integer := 3;


  signal cnx_slave_in  : t_wishbone_slave_in_array(c_cnx_slave_ports-1 downto 0);
  signal cnx_slave_out : t_wishbone_slave_out_array(c_cnx_slave_ports-1 downto 0);

  signal cnx_master_in  : t_wishbone_master_in_array(c_cnx_master_ports-1 downto 0);
  signal cnx_master_out : t_wishbone_master_out_array(c_cnx_master_ports-1 downto 0);

  signal periph_out : t_wishbone_master_out_array(0 to c_peripherals-1);
  signal periph_in  : t_wishbone_master_in_array(0 to c_peripherals-1);


  constant c_cfg_base_addr : t_wishbone_address_array(c_cnx_master_ports-1 downto 0) :=
    (0 => x"00880000",                  -- 64KB of fpga memory
     1 => x"10880000",                  -- The second port to the same memory
     2 => x"20000000");                 -- Peripherals

  constant c_cfg_base_mask : t_wishbone_address_array(c_cnx_master_ports-1 downto 0) :=
    (0 => x"ffff0000",
     1 => x"ffff0000",
     2 => x"f0000000");

  signal owr_en_slv, owr_in_slv : std_logic_vector(0 downto 0);
  
begin  -- rtl

  U_CPU : xwb_lm32
    generic map (
      g_profile => "medium",
      g_reset_vector => x"00880000")
    port map (
      clk_sys_i => clk_sys_i,
      rst_n_i   => rst_n_i,
      irq_i     => x"00000000",
      dwb_o     => cnx_slave_in(0),
      dwb_i     => cnx_slave_out(0),
      iwb_o     => cnx_slave_in(1),
      iwb_i     => cnx_slave_out(1));

  U_Intercon : xwb_crossbar
    generic map (
      g_num_masters => c_cnx_slave_ports,
      g_num_slaves  => c_cnx_master_ports,
      g_registered  => true,
      g_address => c_cfg_base_addr,
      g_mask => c_cfg_base_mask)
    port map (
      clk_sys_i     => clk_sys_i,
      rst_n_i       => rst_n_i,
      slave_i       => cnx_slave_in,
      slave_o       => cnx_slave_out,
      master_i      => cnx_master_in,
      master_o      => cnx_master_out);

  U_DPRAM : xwb_dpram
    generic map (
      g_size                  => 16384, -- must agree with sw/target/lm32/ram.ld:LENGTH / 4
      g_init_file             => "sw/main.ram",
      g_must_have_init_file   => true,
      g_slave1_interface_mode => PIPELINED,
      g_slave2_interface_mode => PIPELINED,
      g_slave1_granularity    => BYTE,
      g_slave2_granularity    => BYTE)
    port map (
      clk_sys_i => clk_sys_i,
      rst_n_i   => rst_n_i,
      slave1_i  => cnx_master_out(0),
      slave1_o  => cnx_master_in(0),
      slave2_i  => cnx_master_out(1),
      slave2_o  => cnx_master_in(1));

  --U_peripheral_Fanout : xwb_bus_fanout
  --  generic map (
  --    g_num_outputs          => c_peripherals,
  --    g_bits_per_slave       => 8,
  --    g_address_granularity  => BYTE,
  --    g_slave_interface_mode => PIPELINED)
  --  port map (
  --    clk_sys_i => clk_sys_i,
  --    rst_n_i   => rst_n_i,
  --    slave_i   => cnx_master_out(2),
  --    slave_o   => cnx_master_in(2),
  --    master_i  => periph_in,
  --    master_o  => periph_out);

  --U_GPIO : xwb_gpio_port
  --  generic map (
  --    g_interface_mode         => CLASSIC,
  --    g_address_granularity    => BYTE,
  --    g_num_pins               => 32,
  --    g_with_builtin_tristates => true)
  --  port map (
  --    clk_sys_i => clk_sys_i,
  --    rst_n_i   => rst_n_i,
  --    slave_i   => periph_out(0),
  --    slave_o   => periph_in(0),
  --    gpio_b    => gpio_b,
  --    gpio_in_i => x"00000000"
  --    );

  U_UART : xwb_simple_uart
    generic map (
      g_interface_mode      => PIPELINED,
      g_address_granularity => BYTE)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      slave_i    => cnx_master_out(2),
      slave_o    => cnx_master_in(2),
      uart_rxd_i => rxd_i,
      uart_txd_o => txd_o);

  --U_OneWire : xwb_onewire_master
  --  generic map (
  --    g_interface_mode      => CLASSIC,
  --    g_address_granularity => BYTE,
  --    g_num_ports           => 1)
  --  port map (
  --    clk_sys_i => clk_sys_i,
  --    rst_n_i   => rst_n_i,
  --    slave_i   => periph_out(2),
  --    slave_o   => periph_in(2),
  --    owr_en_o  => owr_en_slv,
  --    owr_i     => owr_in_slv);

  --onewire_b <= '0' when owr_en_slv(0) = '1' else 'Z';
  --owr_in_slv(0) <= onewire_b;
end rtl;
