library ieee;
use ieee.std_logic_1164.all;
use work.wishbone_pkg.all;

entity xwb_async_bridge is
  generic (
    g_simulation          : integer := 0;
    g_interface_mode      : t_wishbone_interface_mode;
    g_address_granularity : t_wishbone_address_granularity;
    g_cpu_address_width: integer := 32);
  port(
    rst_n_i   : in std_logic;           -- global reset
    clk_sys_i : in std_logic;           -- system clock

-------------------------------------------------------------------------------
-- Atmel EBI bus
-------------------------------------------------------------------------------

    cpu_cs_n_i : in std_logic;
-- async write, active LOW
    cpu_wr_n_i : in std_logic;
-- async read, active LOW
    cpu_rd_n_i : in std_logic;
-- byte select, active  LOW (not used due to weird CPU pin layout - NBS2 line is
-- shared with 100 Mbps Ethernet PHY)
    cpu_bs_n_i : in std_logic_vector(3 downto 0);

-- address input
    cpu_addr_i : in std_logic_vector(g_cpu_address_width-1 downto 0);

-- data bus (bidirectional)
    cpu_data_b : inout std_logic_vector(31 downto 0);

-- async wait, active LOW
    cpu_nwait_o : out std_logic;

-------------------------------------------------------------------------------
-- Wishbone master I/F 
-------------------------------------------------------------------------------
    master_o : out t_wishbone_master_out;
    master_i : in  t_wishbone_master_in
    );

end xwb_async_bridge;

architecture wrapper of xwb_async_bridge is

begin

  U_Wrapped_Bridge : wb_async_bridge
    generic map (
      g_simulation          => g_simulation,
      g_interface_mode      => g_interface_mode,
      g_address_granularity => g_address_granularity,
      g_cpu_address_width => g_cpu_address_width)
    port map (
      rst_n_i     => rst_n_i,
      clk_sys_i   => clk_sys_i,
      cpu_cs_n_i  => cpu_cs_n_i,
      cpu_wr_n_i  => cpu_wr_n_i,
      cpu_rd_n_i  => cpu_rd_n_i,
      cpu_bs_n_i  => cpu_bs_n_i,
      cpu_addr_i  => cpu_addr_i,
      cpu_data_b  => cpu_data_b,
      cpu_nwait_o => cpu_nwait_o,
      wb_adr_o    => master_o.adr,
      wb_dat_o    => master_o.dat,
      wb_stb_o    => master_o.stb,
      wb_we_o     => master_o.we,
      wb_sel_o    => master_o.sel,
      wb_cyc_o    => master_o.cyc,
      wb_dat_i    => master_i.dat,
      wb_ack_i    => master_i.ack);

end wrapper;
