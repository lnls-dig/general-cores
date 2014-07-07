library ieee;
use ieee.std_logic_1164.all;

library work;
use work.wishbone_pkg.all;

package altera_flash_pkg is

  component flash_top is
    generic(
      -- Sadly, all of this shit must be tuned by hand
      g_family                 : string;
      g_port_width             : natural := 1;
      g_addr_width             : natural := 24;
      g_dummy_time             : natural := 8;
      g_input_latch_edge       : std_logic;
      g_output_latch_edge      : std_logic;
      g_input_to_output_cycles : natural);
    port(
      -- Wishbone interface
      clk_i     : in  std_logic;
      rstn_i    : in  std_logic;
      slave_i   : in  t_wishbone_slave_in;
      slave_o   : out t_wishbone_slave_out;
      -- Clock lines for flash chip (might need phase offsets)
      clk_ext_i : in  std_logic;  -- fed off-chip
      clk_out_i : in  std_logic;  -- output registers latch to this
      clk_in_i  : in  std_logic); -- input  registers latch to this
  end component;

end altera_flash_pkg;
