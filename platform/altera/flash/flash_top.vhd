library ieee;
use ieee.std_logic_1164.all;

library work;
use work.wishbone_pkg.all;

entity flash_top is
  generic(
    g_family                 : string;
    g_port_width             : natural := 1;
    g_addr_width             : natural := 24;
    g_dummy_time             : natural := 8;
    g_input_latch_edge       : std_logic;
    g_output_latch_edge      : std_logic;
    g_input_to_output_cycles : natural);
  port(
    -- Wishbone interface
    clk_i   : in  std_logic;
    rstn_i  : in  std_logic;
    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;
    -- Clock lines for flash chip
    clk_ext_i : in  std_logic;
    clk_out_i : in  std_logic;
    clk_in_i  : in  std_logic);
end flash_top;

architecture rtl of flash_top is

  component altera_spi is
    generic(
      g_family     : string  := "none";
      g_port_width : natural := 1);
    port(
      dclk_i : in  std_logic;
      ncs_i  : in  std_logic;
      oe_i   : in  std_logic_vector(g_port_width-1 downto 0);
      asdo_i : in  std_logic_vector(g_port_width-1 downto 0);
      data_o : out std_logic_vector(g_port_width-1 downto 0));
  end component;
  
  signal flash_ncs  : std_logic;
  signal flash_oe   : std_logic_vector(g_port_width-1 downto 0);
  signal flash_asdo : std_logic_vector(g_port_width-1 downto 0);
  signal flash_data : std_logic_vector(g_port_width-1 downto 0);
  
begin

  wb : wb_spi_flash
    generic map(
      g_port_width             => g_port_width,
      g_addr_width             => g_addr_width,
      g_idle_time              => 3,
      g_dummy_time             => g_dummy_time,
      g_input_latch_edge       => g_input_latch_edge,
      g_output_latch_edge      => g_output_latch_edge,
      g_input_to_output_cycles => g_input_to_output_cycles)
    port map(
      clk_i              => clk_i,
      rstn_i             => rstn_i,
      slave_i            => slave_i,
      slave_o            => slave_o,
      clk_out_i          => clk_out_i,
      clk_in_i           => clk_in_i,
      ncs_o              => flash_ncs,
      oe_o               => flash_oe,
      asdi_o             => flash_asdo,
      data_i             => flash_data,
      external_request_i => '0',
      external_granted_o => open);
  
  spi : altera_spi
    generic map(
      g_family     => g_family,
      g_port_width => g_port_width)
    port map(
      dclk_i => clk_ext_i,
      ncs_i  => flash_ncs,
      oe_i   => flash_oe,
      asdo_i => flash_asdo,
      data_o => flash_data);
  
end rtl;
