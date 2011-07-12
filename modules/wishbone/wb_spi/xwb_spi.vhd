library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity xwb_spi is
  generic(
    g_interface_mode : t_wishbone_interface_mode := CLASSIC
    );

  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    -- Wishbone
    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;
    desc_o  : out t_wishbone_device_descriptor;

    pad_cs_o   : out std_logic_vector(7 downto 0);
    pad_sclk_o : out std_logic;
    pad_mosi_o : out std_logic;
    pad_miso_i : in  std_logic
    );

end xwb_spi;

architecture rtl of xwb_spi is

  component spi_top
    port (
      wb_clk_i : in  std_logic;
      wb_rst_i : in  std_logic;
      wb_adr_i : in  std_logic_vector(4 downto 0);
      wb_dat_i : in  std_logic_vector(31 downto 0);
      wb_dat_o : out std_logic_vector(31 downto 0);
      wb_sel_i : in  std_logic_vector(3 downto 0);
      wb_stb_i : in  std_logic;
      wb_cyc_i : in  std_logic;
      wb_we_i  : in  std_logic;
      wb_ack_o : out std_logic;
      wb_err_o : out std_logic;
      wb_int_o : out std_logic;

      ss_pad_o   : out std_logic_vector(7 downto 0);
      sclk_pad_o : out std_logic;
      mosi_pad_o : out std_logic;
      miso_pad_i : in  std_logic);
  end component;

  signal wb_rst    : std_logic;
  signal core_addr : std_logic_vector(4 downto 0);
  
begin  -- rtl

  gen_test_mode : if(g_interface_mode /= CLASSIC) generate
    assert false report "xwb_spi: this module can only work with CLASSIC wishbone interface" severity failure;
  end generate gen_test_mode;

  wb_rst <= not rst_n_i;

  core_addr <= slave_i.adr(2 downto 0) & "00";

  Wrapped_SPI : spi_top
    port map (
      wb_clk_i   => clk_sys_i,
      wb_rst_i   => wb_rst,
      wb_adr_i   => core_addr,
      wb_dat_i   => slave_i.dat(31 downto 0),
      wb_dat_o   => slave_o.dat(31 downto 0),
      wb_sel_i   => slave_i.sel(3 downto 0),
      wb_stb_i   => slave_i.stb,
      wb_cyc_i   => slave_i.cyc,
      wb_we_i    => slave_i.we,
      wb_ack_o   => slave_o.ack,
      wb_err_o   => slave_o.err,
      wb_int_o   => slave_o.int,
      ss_pad_o   => pad_cs_o,
      sclk_pad_o => pad_sclk_o,
      mosi_pad_o => pad_mosi_o,
      miso_pad_i => pad_miso_i);

  slave_o.rty   <= '0';
  slave_o.stall <= '0';

end rtl;
