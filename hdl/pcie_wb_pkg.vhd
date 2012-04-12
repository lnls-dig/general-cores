library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package pcie_wb_pkg is
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
      
      cfg_busdev    : out std_logic_vector(12 downto 0); -- Configured Bus#:Dev#
      
      -- Simplified wishbone output stream
      wb_clk_o      : out std_logic;
      
      rx_wb_stb_o   : out std_logic;
      rx_wb_dat_o   : out std_logic_vector(31 downto 0);
      rx_wb_stall_i : in  std_logic;
      
      tx_wb_stb_i   : in  std_logic;
      tx_wb_dat_i   : in  std_logic_vector(31 downto 0);
      tx_wb_stall_o : out std_logic);
  end component;
end pcie_wb_pkg;
