library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

package pcie_wb_pkg is
  component pcie_wb is
    generic(
      sdb_addr : t_wishbone_address);
    port(
      clk125_i      : in  std_logic; -- 125 MHz, free running
      cal_clk50_i   : in  std_logic; --  50 MHz, shared between all PHYs
      rstn_i        : in  std_logic;
      
      pcie_refclk_i : in  std_logic; -- 100 MHz, must not derive clk125_i or cal_clk50_i
      pcie_rstn_i   : in  std_logic;
      pcie_rx_i     : in  std_logic_vector(3 downto 0);
      pcie_tx_o     : out std_logic_vector(3 downto 0);
      
      wb_clk        : in  std_logic; -- Whatever clock you want these signals on:
      master_o      : out t_wishbone_master_out;
      master_i      : in  t_wishbone_master_in);
  end component;
  
  component pcie_altera is
    port(
      clk125_i      : in  std_logic; -- 125 MHz, free running
      cal_clk50_i   : in  std_logic; --  50 MHz, shared between all PHYs
      rstn_i        : in  std_logic; -- Logical reset
      rstn_o        : out std_logic; -- If PCIe resets
      
      pcie_refclk_i : in  std_logic; -- 100 MHz, must not derive clk125_i or cal_clk50_i
      pcie_rstn_i   : in  std_logic; -- PCIe reset pin
      pcie_rx_i     : in  std_logic_vector(3 downto 0);
      pcie_tx_o     : out std_logic_vector(3 downto 0);
      
      cfg_busdev_o  : out std_logic_vector(12 downto 0); -- Configured Bus#:Dev#
      
      -- Simplified wishbone output stream
      wb_clk_o      : out std_logic;
      
      rx_wb_stb_o   : out std_logic;
      rx_wb_bar_o   : out std_logic_vector(2 downto 0);
      rx_wb_dat_o   : out std_logic_vector(31 downto 0);
      rx_wb_stall_i : in  std_logic;
      
      -- pre-allocate buffer space used for TX
      tx_rdy_o      : out std_logic;
      tx_alloc_i    : in  std_logic; -- may only set '1' if rdy_o = '1'
      
      -- push TX data
      tx_en_i       : in  std_logic; -- may never exceed alloc_i
      tx_dat_i      : in  std_logic_vector(31 downto 0);
      tx_eop_i      : in  std_logic; -- Mark last strobe
      tx_pad_i      : in  std_logic); -- Is the data misaligned?
  end component;
  
  component pcie_tlp is
    port(
      clk_i         : in std_logic;
      rstn_i        : in std_logic;
      
      rx_wb_stb_i   : in  std_logic;
      rx_wb_bar_i   : in  std_logic_vector(2 downto 0);
      rx_wb_dat_i   : in  std_logic_vector(31 downto 0);
      rx_wb_stall_o : out std_logic;
      
      tx_rdy_i      : in  std_logic;
      tx_alloc_o    : out std_logic;
      tx_en_o       : out std_logic;
      tx_dat_o      : out std_logic_vector(31 downto 0);
      tx_eop_o      : out std_logic;
      tx_pad_o      : out std_logic;
      
      cfg_busdev_i  : in  std_logic_vector(12 downto 0);
      
      wb_stb_o      : out std_logic;
      wb_adr_o      : out std_logic_vector(63 downto 0);
      wb_bar_o      : out std_logic_vector(2 downto 0);
      wb_we_o       : out std_logic;
      wb_dat_o      : out std_logic_vector(31 downto 0);
      wb_sel_o      : out std_logic_vector(3 downto 0);
      wb_stall_i    : in  std_logic;
      wb_ack_i      : in  std_logic;
      wb_err_i      : in  std_logic;
      wb_rty_i      : in  std_logic;
      wb_dat_i      : in  std_logic_vector(31 downto 0));
  end component;
end pcie_wb_pkg;
