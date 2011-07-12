library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity wb_spi is

  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    wb_adr_i : in  std_logic_vector(2 downto 0);
    wb_dat_i : in  std_logic_vector(31 downto 0);
    wb_dat_o : out std_logic_vector(31 downto 0);
    wb_sel_i : in  std_logic_vector(3 downto 0);
    wb_stb_i : in  std_logic;
    wb_cyc_i : in  std_logic;
    wb_we_i  : in  std_logic;
    wb_ack_o : out std_logic;
    wb_err_o : out std_logic;
    wb_int_o : out std_logic;

    pad_cs_o   : out std_logic_vector(7 downto 0);
    pad_sclk_o : out std_logic;
    pad_mosi_o : out std_logic;
    pad_miso_i : in  std_logic
    );

end wb_spi;

architecture rtl of wb_spi is

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

  signal wb_rst : std_logic;
  signal core_addr : std_logic_vector(4 downto 0);
begin  -- rtl

  wb_rst <= not rst_n_i;

  core_addr <= wb_adr_i & "00";
  
  Wrapped_SPI : spi_top
    port map (
      wb_clk_i   => clk_sys_i,
      wb_rst_i   => wb_rst,
      wb_adr_i   => core_addr,
      wb_dat_i   => wb_dat_i,
      wb_dat_o   => wb_dat_o,
      wb_sel_i   => wb_sel_i,
      wb_stb_i   => wb_stb_i,
      wb_cyc_i   => wb_cyc_i,
      wb_we_i    => wb_we_i,
      wb_ack_o   => wb_ack_o,
      wb_err_o   => wb_err_o,
      wb_int_o   => wb_int_o,
      ss_pad_o   => pad_cs_o,
      sclk_pad_o => pad_sclk_o,
      mosi_pad_o => pad_mosi_o,
      miso_pad_i => pad_miso_i);

end rtl;
