library ieee;
use ieee.STD_LOGIC_1164.all;

use work.gencores_pkg.all;

entity wb_onewire_master is

  generic(
    g_num_ports        : integer := 1;
    g_ow_btp_normal    : string  := "5.0";
    g_ow_btp_overdrive : string  := "1.0"
    );  

  port (
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    wb_cyc_i : in std_logic;
    wb_sel_i : in std_logic_vector(3 downto 0);
    wb_stb_i : in std_logic;
    wb_we_i  : in std_logic;
    wb_adr_i : in std_logic_vector(1 downto 0);
    wb_dat_i : in std_logic_vector(31 downto 0);
    wb_dat_o : out std_logic_vector(31 downto 0);
    wb_ack_o : out std_logic;
    wb_int_o: out std_logic;

    owr_pwren_o : out std_logic_vector(g_num_ports -1 downto 0);
    owr_en_o    : out std_logic_vector(g_num_ports -1 downto 0);
    owr_i       : in  std_logic_vector(g_num_ports -1 downto 0)
    );

end wb_onewire_master;


architecture rtl of wb_onewire_master is

  component sockit_owm
    generic(
      BTP_N : string;
      BTP_O : string;
      OWN   : integer);

    port(
      clk     : in  std_logic;
      rst     : in  std_logic;
      bus_ren : in  std_logic;
      bus_wen : in  std_logic;
      bus_adr : in  std_logic_vector(0 downto 0);
      bus_wdt : in  std_logic_vector(31 downto 0);
      bus_rdt : out std_logic_vector(31 downto 0);
      bus_irq : out std_logic;
      owr_p   : out std_logic_vector(OWN-1 downto 0);
      owr_e   : out std_logic_vector(OWN-1 downto 0);
      owr_i   : in  std_logic_vector(OWN-1 downto 0)
      );
  end component;

  signal bus_wen : std_logic;
  signal bus_ren : std_logic;
  signal rst     : std_logic;
begin  -- rtl

  bus_wen <= wb_cyc_i and wb_stb_i and wb_we_i;
  bus_ren <= wb_cyc_i and wb_stb_i and not wb_we_i;

  wb_ack_o <= wb_stb_i and wb_cyc_i;
  rst      <= not rst_n_i;

  Wrapped_1wire : sockit_owm
    generic map (
      BTP_N => g_ow_btp_normal,
      BTP_O => g_ow_btp_overdrive,
      OWN   => g_num_ports)
    port map (
      clk     => clk_sys_i,
      rst     => rst,
      bus_ren => bus_ren,
      bus_wen => bus_wen,
      bus_adr => wb_adr_i(0 downto 0),
      bus_wdt => wb_dat_i,
      bus_rdt => wb_dat_o,
      bus_irq => wb_int_o,
      owr_p   => owr_pwren_o,
      owr_e   => owr_en_o,
      owr_i   => owr_i);
end rtl;

