library ieee;
use ieee.std_logic_1164.all;

use work.genram_pkg.all;

entity cheby_dpssram is

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

end cheby_dpssram;

architecture structural of cheby_dpssram is

  function f_std_logic_to_boolean (l : std_logic) return boolean is
  begin
    if l = '0' then
      return False;
    else
      return True;
    end if;
  end function f_std_logic_to_boolean;

  function f_log2_size (A : natural) return natural is
  begin
    for I in 1 to 64 loop -- works for up to 64 bits
      if ((2 ** I) > A) then
        return (I - 1);
      end if;
    end loop;
    return (63);
  end function f_log2_size;

begin

  cmp_generic_dpram : generic_dpram
    generic map (
      g_DATA_WIDTH        => g_DATA_WIDTH,
      g_SIZE              => g_SIZE,
      g_WITH_BYTE_ENABLE  => f_std_logic_to_boolean(g_USE_BWSEL),
      g_DUAL_CLOCK        => f_std_logic_to_boolean(g_DUAL_CLOCK)
    )
    port map (
      rst_n_i             => '1',
      clka_i              => clk_a_i,
      bwea_i              => bwsel_a_i,
      wea_i               => wr_a_i,
      aa_i                => addr_a_i,
      da_i                => data_a_i,
      qa_o                => data_a_o,
      clkb_i              => clk_b_i,
      bweb_i              => bwsel_b_i,
      web_i               => wr_b_i,
      ab_i                => addr_b_i,
      db_i                => data_b_i,
      qb_o                => data_b_o
    );

end structural;
