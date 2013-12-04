library ieee;
use ieee.std_logic_1164.all;

library work;
use work.wishbone_pkg.all;

package altera_networks_pkg is

  component single_region is
    port(
      inclk  : in  std_logic;
      outclk : out std_logic);
  end component;

  component dual_region is
    port(
      inclk  : in  std_logic;
      outclk : out std_logic);
  end component;

  component global_region is
    port(
      inclk  : in  std_logic;
      outclk : out std_logic);
  end component;

end altera_networks_pkg;
