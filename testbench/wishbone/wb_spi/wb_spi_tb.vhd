library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;
use work.sim_wishbone.all;

entity wb_spi_tb is
end wb_spi_tb;

architecture behav of wb_spi_tb is
  procedure spi_test_case (signal clk_sys : std_logic;
                           signal wb_in:  out  t_wishbone_slave_in;
                           signal wb_out: in   t_wishbone_slave_out;
                           control_val_lsb : in std_logic_vector (7 downto 0);
                           test_case_name : in String ) is

      variable v : std_logic_vector(31 downto 0);
  begin
    --  Set divider to 2
    write32(clk_sys, wb_in, wb_out, x"0000_0014", x"0000_0002");

    --  Set control
    write32(clk_sys, wb_in, wb_out, x"0000_0010", x"0000_24" & control_val_lsb);

    --  Set data
    write32(clk_sys, wb_in, wb_out, x"0000_0000", x"0000_008d");

    --  Set CS
    write32(clk_sys, wb_in, wb_out, x"0000_0018", x"0000_0001");

    -- Verify control
    read32(clk_sys, wb_in, wb_out, x"0000_0010", v);
    assert v(7 downto 0) = control_val_lsb
    report "(Test case: " & test_case_name & ") Control LSB returned unexpected value 0x" &
           to_hstring(v(7 downto 0)) & ", expecting 0x" & to_hstring(control_val_lsb);

    --  Go
    write32(clk_sys, wb_in, wb_out, x"0000_0010", x"0000_25" & control_val_lsb);

    loop
      read32(clk_sys, wb_in, wb_out, x"0000_0010", v);
      exit when v (8) = '0';
    end loop;
  end spi_test_case;

  signal clk_sys  : std_logic := '0';
  signal rst_n    : std_logic;
  signal wb_in    : t_wishbone_slave_in;
  signal wb_out   : t_wishbone_slave_out;
  signal int      : std_logic;
  signal pad_cs   : std_logic_vector(8-1 downto 0);
  signal pad_sclk : std_logic;
  signal pad_mosi : std_logic;
  signal pad_miso : std_logic;

  signal stop : boolean := False;
begin
  xwb_spi_1: entity work.xwb_spi
    generic map (
      g_interface_mode      => CLASSIC,
      g_address_granularity => BYTE,
      g_divider_len         => 8,
      g_max_char_len        => 128,
      g_num_slaves          => 8)
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

  clk_sys <= not clk_sys after 5 ns when not stop else '0';
  rst_n <= '0', '1' after 20 ns;

  pad_miso <= pad_mosi;

  process
    variable v : std_logic_vector(31 downto 0);
  begin
    init(wb_in);

    wait until rst_n = '1';
    wait until rising_edge(clk_sys);

    spi_test_case(clk_sys, wb_in, wb_out, x"28", "Case 1"); -- len = 40 chars, ok
    spi_test_case(clk_sys, wb_in, wb_out, x"23", "Case 2"); -- len = 35 chars, ok
    spi_test_case(clk_sys, wb_in, wb_out, x"28", "Case 3"); -- len = 40 chars, **BUG** 0x29 gets written instead?, 41 chars transmitted

    report "done - success";
    stop <= true;
    wait;
  end process;
end behav;
