library ieee;
use ieee.std_logic_1164.all;

package cheby_pkg is

  component cheby_dpssram
    generic (
      g_DATA_WIDTH  : natural := 32;
      g_SIZE        : natural := 1024;
      g_ADDR_WIDTH  : natural := 10;
      g_DUAL_CLOCK  : std_logic := '1';
      g_USE_BWSEL   : std_logic := '1'
    );
    port (
      clk_a_i       : in std_logic;
      bwsel_a_i     : in std_logic_vector((G_DATA_WIDTH+7)/8-1 downto 0);
      wr_a_i        : in std_logic;
      rd_a_i        : in std_logic;
      addr_a_i      : in std_logic_vector(G_ADDR_WIDTH-1 downto 0);
      data_a_i      : in std_logic_vector(g_DATA_WIDTH-1 downto 0);
      data_a_o      : out std_logic_vector(G_DATA_WIDTH-1 downto 0);
      clk_b_i       : in std_logic;
      bwsel_b_i     : in std_logic_vector((G_DATA_WIDTH+7)/8-1 downto 0);
      wr_b_i        : in std_logic;
      rd_b_i        : in std_logic;
      addr_b_i      : in std_logic_vector(G_ADDR_WIDTH-1 downto 0);
      data_b_i      : in std_logic_vector(G_DATA_WIDTH-1 downto 0);
      data_b_o      : out std_logic_vector(G_DATA_WIDTH-1 downto 0)
    );
  end component;

end cheby_pkg;
