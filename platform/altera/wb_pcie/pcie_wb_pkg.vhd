library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

package pcie_wb_pkg is

  constant c_pcie_msi : t_sdb_msi := (
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7", -- 8/16/32-bit port granularity
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"000000000000ffff",
    product => (
    vendor_id     => x"0000000000000651", -- GSI
    device_id     => x"8a670e73",
    version       => x"00000001",
    date          => x"20131213",
    name          => "Altera-PCIe-MSI-Tgt")));

  component pcie_wb is
    generic(
      g_family   : string := "Arria II";
      g_fast_ack : boolean := true;
      sdb_addr   : t_wishbone_address);
    port(
      clk125_i      : in  std_logic; -- 125 MHz, free running (unused by Arria V)
      cal_clk50_i   : in  std_logic; --  50 MHz, shared between all PHYs (100MHz for Arria V)
      
      -- Physical PCIe pins
      pcie_refclk_i : in  std_logic; -- 100 MHz, must not derive clk125_i or cal_clk50_i
      pcie_rstn_i   : in  std_logic; -- Asynchronous "clear sticky" PCIe pin
      pcie_rx_i     : in  std_logic_vector(3 downto 0);
      pcie_tx_o     : out std_logic_vector(3 downto 0);
      
      -- Commands from PC to FPGA
      master_clk_i  : in  std_logic;
      master_rstn_i : in  std_logic;
      master_o      : out t_wishbone_master_out;
      master_i      : in  t_wishbone_master_in;
      
      -- Command to PC from FPGA
      slave_clk_i   : in  std_logic := '0';
      slave_rstn_i  : in  std_logic := '1';
      slave_i       : in  t_wishbone_slave_in := cc_dummy_slave_in;
      slave_o       : out t_wishbone_slave_out);
  end component;
  
  component pcie_altera is
    generic(
      g_family      : string := "Arria II");
    port(
      clk125_i      : in  std_logic; -- 125 MHz, free running
      cal_clk50_i   : in  std_logic; --  50 MHz, shared between all PHYs
      async_rstn    : in  std_logic;
      
      pcie_refclk_i : in  std_logic; -- 100 MHz, must not derive clk125_i or cal_clk50_i
      pcie_rstn_i   : in  std_logic; -- PCIe reset pin
      pcie_rx_i     : in  std_logic_vector(3 downto 0);
      pcie_tx_o     : out std_logic_vector(3 downto 0);
      
      cfg_busdev_o  : out std_logic_vector(12 downto 0); -- Configured Bus#:Dev#
      
      app_msi_req   : in  std_logic; -- Generate an MSI interrupt
      app_int_sts   : in  std_logic; -- Generate a legacy interrupt
      
      -- Simplified wishbone output stream
      wb_clk_o      : out std_logic;
      wb_rstn_i     : in  std_logic;
      
      rx_wb_stb_o   : out std_logic;
      rx_wb_dat_o   : out std_logic_vector(63 downto 0);
      rx_wb_stall_i : in  std_logic;
      rx_bar_o      : out std_logic_vector(2 downto 0);
      
      -- pre-allocate buffer space used for TX
      tx_rdy_o      : out std_logic;
      tx_alloc_i    : in  std_logic; -- may only set '1' if rdy_o = '1'
      
      -- push TX data
      tx_wb_stb_i   : in  std_logic; -- may never exceed alloc_i
      tx_wb_dat_i   : in  std_logic_vector(63 downto 0);
      tx_eop_i      : in  std_logic); -- Mark last strobe in packet (altera needs this)
  end component;
  
  component pcie_64to32 is
    port(
      clk_i            : in  std_logic;
      rstn_i           : in  std_logic;
      -- The 64-bit source
      master64_stb_i   : in  std_logic;
      master64_dat_i   : in  std_logic_vector(63 downto 0);
      master64_stall_o : out std_logic;
      -- The 32-bit sink
      slave32_stb_o    : out std_logic;
      slave32_dat_o    : out std_logic_vector(31 downto 0);
      slave32_stall_i  : in  std_logic);
  end component;
  
  component pcie_32to64 is
    port(
      clk_i            : in  std_logic;
      rstn_i           : in  std_logic;
      -- The 32-bit source
      master32_stb_i   : in  std_logic;
      master32_dat_i   : in  std_logic_vector(31 downto 0);
      master32_stall_o : out std_logic;
      -- The 64-bit sink
      slave64_stb_o    : out std_logic;
      slave64_dat_o    : out std_logic_vector(63 downto 0);
      slave64_stall_i  : in  std_logic);
  end component;
  
  component pcie_tlp is
    port(
      clk_i         : in std_logic;
      rstn_i        : in std_logic;
      
      rx_wb_stb_i   : in  std_logic;
      rx_wb_dat_i   : in  std_logic_vector(31 downto 0);
      rx_wb_stall_o : out std_logic;
      rx_bar_i      : in  std_logic_vector(2 downto 0);
      
      tx_rdy_i      : in  std_logic;
      tx_alloc_o    : out std_logic;
      
      tx_wb_stb_o   : out std_logic;
      tx_wb_dat_o   : out std_logic_vector(31 downto 0);
      tx_eop_o      : out std_logic;
      
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
