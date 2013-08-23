library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity wb_spi_bidir is
  generic (
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD
    );
  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    wb_adr_i   : in  std_logic_vector(5 downto 0);
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
    pad_mosi_i : in std_logic;
    pad_mosi_en: out std_logic;
    pad_miso_i : in  std_logic
    );

end wb_spi_bidir;

architecture rtl of wb_spi_bidir is

  component spi_bidir_top
    port (
      wb_clk_i : in  std_logic;
      wb_rst_i : in  std_logic;
      wb_adr_i : in  std_logic_vector(5 downto 0);
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
      mosi_pad_i : in  std_logic;
      mosi_out_en: out std_logic;
      miso_pad_i : in  std_logic);
  end component;

  signal rst : std_logic;

  signal wb_in  : t_wishbone_slave_in;
  signal wb_out : t_wishbone_slave_out;

  signal resized_addr : std_logic_vector(c_wishbone_address_width-1 downto 0);

begin

  resized_addr(5 downto 0)                          <= wb_adr_i;
  resized_addr(c_wishbone_address_width-1 downto 6) <= (others => '0');

  U_Adapter : wb_slave_adapter
    generic map (
      g_master_use_struct  => true,
      g_master_mode        => CLASSIC,
      g_master_granularity => BYTE,
      g_slave_use_struct   => false,
      g_slave_mode         => g_interface_mode,
      g_slave_granularity  => g_address_granularity)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      master_i   => wb_out,
      master_o   => wb_in,
      sl_adr_i   => resized_addr,
      sl_dat_i   => wb_dat_i,
      sl_sel_i   => wb_sel_i,
      sl_cyc_i   => wb_cyc_i,
      sl_stb_i   => wb_stb_i,
      sl_we_i    => wb_we_i,
      sl_dat_o   => wb_dat_o,
      sl_ack_o   => wb_ack_o,
      sl_stall_o => wb_stall_o,
      sl_int_o   => wb_int_o,
      sl_err_o   => wb_err_o);

  rst <= not rst_n_i;

  Wrapped_SPI : spi_bidir_top               -- byte-aligned
    port map (
      wb_clk_i   => clk_sys_i,
      wb_rst_i   => rst,
      wb_adr_i   => wb_in.adr(5 downto 0),
      wb_dat_i   => wb_in.dat,
      wb_dat_o   => wb_out.dat,
      wb_sel_i   => wb_in.sel,
      wb_stb_i   => wb_in.stb,
      wb_cyc_i   => wb_in.cyc,
      wb_we_i    => wb_in.we,
      wb_ack_o   => wb_out.ack,
      wb_err_o   => wb_out.err,
      wb_int_o   => wb_out.int,
      ss_pad_o   => pad_cs_o,
      sclk_pad_o => pad_sclk_o,
      mosi_pad_o => pad_mosi_o, -- mosi is bidir line
      mosi_pad_i => pad_mosi_i,
      mosi_out_en => pad_mosi_en,
      miso_pad_i => pad_miso_i);

end rtl;
