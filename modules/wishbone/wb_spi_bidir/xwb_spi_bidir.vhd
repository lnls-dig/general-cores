library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity xwb_spi_bidir is
  generic(
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD
    );

  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    -- Wishbone
    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;
    desc_o  : out t_wishbone_device_descriptor;

    pad_cs_o       : out std_logic_vector(7 downto 0);
    pad_sclk_o     : out std_logic;
    pad_mosi_o     : out std_logic;
    pad_mosi_i     : in  std_logic;
    pad_mosi_en_o  : out std_logic;
    pad_miso_i     : in  std_logic
);

end xwb_spi_bidir;

architecture rtl of xwb_spi_bidir is

begin

  U_Wrapped_SPI: wb_spi_bidir
    generic map (
      g_interface_mode      => g_interface_mode,
      g_address_granularity => g_address_granularity)
    port map (
      clk_sys_i      => clk_sys_i,
      rst_n_i        => rst_n_i,
      wb_adr_i       => slave_i.adr(5 downto 0),
      wb_dat_i       => slave_i.dat,
      wb_dat_o       => slave_o.dat,
      wb_sel_i       => slave_i.sel,
      wb_stb_i       => slave_i.stb,
      wb_cyc_i       => slave_i.cyc,
      wb_we_i        => slave_i.we,
      wb_ack_o       => slave_o.ack,
      wb_err_o       => slave_o.err,
      wb_int_o       => slave_o.int,
      wb_stall_o     => slave_o.stall,
      pad_cs_o       => pad_cs_o,
      pad_sclk_o     => pad_sclk_o,
      pad_mosi_o     => pad_mosi_o,
      pad_mosi_i     => pad_mosi_i,
      pad_mosi_en_o  => pad_mosi_en_o,
      pad_miso_i     => pad_miso_i);

end rtl;
