library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;
use work.sim_wishbone.all;

entity tb_spi is
end tb_spi;

architecture behav of tb_spi is
  signal clk_sys  : std_logic := '0';
  signal rst_n    : std_logic;
  signal wb_in    : t_wishbone_slave_in;
  signal wb_out   : t_wishbone_slave_out;
  signal int      : std_logic;
  signal pad_cs   : std_logic_vector(4-1 downto 0);
  signal pad_sclk : std_logic;
  signal pad_mosi : std_logic;
  signal pad_miso : std_logic;
begin
  xwb_spi_1: entity work.xwb_spi
    generic map (
      g_interface_mode      => CLASSIC,
      g_address_granularity => BYTE,
      g_divider_len         => 8,
      g_max_char_len        => 128,
      g_num_slaves          => 4)
    port map (
      clk_sys_i  => clk_sys,
      rst_n_i    => rst_n,
      slave_i    => wb_in,
      slave_o    => wb_out,
      desc_o     => open,
      int_o      => int,
      pad_cs_o   => pad_cs,
      pad_sclk_o => pad_sclk,
      pad_mosi_o => pad_mosi,
      pad_miso_i => pad_miso);

  clk_sys <= not clk_sys after 5 ns;
  rst_n <= '0', '1' after 20 ns;

  pad_miso <= pad_mosi;

  process
    variable v : std_logic_vector(31 downto 0);
  begin
    init(wb_in);

    wait until rst_n = '1';
    wait until rising_edge(clk_sys);

    --  Set divider to 2
    write32(clk_sys, wb_in, wb_out, x"0000_0014", x"0000_0002");

    --  Set control
    write32(clk_sys, wb_in, wb_out, x"0000_0010", x"0000_2408");

    --  Set data
    write32(clk_sys, wb_in, wb_out, x"0000_0000", x"0000_008d");

    --  Set CS
    write32(clk_sys, wb_in, wb_out, x"0000_0018", x"0000_0001");

    --  Go
    write32(clk_sys, wb_in, wb_out, x"0000_0010", x"0000_2508");

    loop
      read32(clk_sys, wb_in, wb_out, x"0000_0010", v);
      exit when v (8) = '0';
    end loop;
    wait;
  end process;
end behav;
