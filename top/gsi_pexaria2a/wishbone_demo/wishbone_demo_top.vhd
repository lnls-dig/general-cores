library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.pcie_wb_pkg.all;
use work.gencores_pkg.all;

entity wishbone_demo_top is
  port(
    -----------------------------------------
    -- Clocking pins
    -----------------------------------------
    clk125_i : in std_logic;

    -----------------------------------------
    -- PCI express pins
    -----------------------------------------
    pcie_refclk_i : in  std_logic;
    pcie_rstn_i   : in  std_logic;
    pcie_rx_i     : in  std_logic_vector(3 downto 0);
    pcie_tx_o     : out std_logic_vector(3 downto 0);
      
    -----------------------------------------------------------------------
    -- User LEDs
    -----------------------------------------------------------------------
    leds_o			: out std_logic_vector(7 downto 0));
end wishbone_demo_top;

architecture rtl of wishbone_demo_top is

  component sys_pll -- Altera megafunction
    port(
      inclk0 : in  std_logic;
      areset : in  std_logic;
      c0     : out std_logic;
      c1     : out std_logic;
      locked : out std_logic);
  end component;

  constant c_xwb_gpio32_sdb : t_sdb_device := (
    abi_class     => x"0000", -- undocumented device
    abi_ver_major => x"01",
    abi_ver_minor => x"00",
    wbd_endian    => c_sdb_endian_big,
    wbd_width     => x"7", -- 8/16/32-bit port granularity
    sdb_component => (
    addr_first    => x"0000000000000000",
    addr_last     => x"0000000000000007", -- Two 4 byte registers
    product => (
    vendor_id     => x"0000000000000651", -- GSI
    device_id     => x"35aa6b95",
    version       => x"00000001",
    date          => x"20120305",
    name          => "GSI_GPIO_32        ")));
    
  -- Top crossbar layout
  constant c_slaves : natural := 3;
  constant c_masters : natural := 5;
  constant c_dpram_size : natural := 16384; -- in 32-bit words (64KB)
  constant c_layout : t_sdb_record_array(c_slaves-1 downto 0) :=
   (0 => f_sdb_embed_device(f_xwb_dpram(c_dpram_size), x"00000000"),
    1 => f_sdb_embed_device(c_xwb_gpio32_sdb,          x"00100400"),
    2 => f_sdb_embed_device(c_xwb_dma_sdb,             x"00100500"));
  constant c_sdb_address : t_wishbone_address := x"00100000";

  signal cbar_slave_i  : t_wishbone_slave_in_array (c_masters-1 downto 0);
  signal cbar_slave_o  : t_wishbone_slave_out_array(c_masters-1 downto 0);
  signal cbar_master_i : t_wishbone_master_in_array(c_slaves-1 downto 0);
  signal cbar_master_o : t_wishbone_master_out_array(c_slaves-1 downto 0);

  signal clk_sys, clk_cal : std_logic;
  signal lm32_interrupt : std_logic_vector(31 downto 0);
  signal lm32_rstn : std_logic;
  
  signal locked : std_logic;
  signal clk_sys_rstn : std_logic;
  signal reset_clks : std_logic_vector(0 downto 0);
  signal reset_rstn : std_logic_vector(0 downto 0);
  
  signal gpio_slave_o : t_wishbone_slave_out;
  signal gpio_slave_i : t_wishbone_slave_in;
  
  signal r_leds : std_logic_vector(7 downto 0);
  signal r_reset : std_logic;
begin
  -- Obtain core clocking
  sys_pll_inst : sys_pll -- Altera megafunction
    port map (
      inclk0 => clk125_i,    -- 125Mhz oscillator from board
      areset => '0',
      c0     => clk_sys,     -- 130MHz system clk (to test clock crossing from clk125_i)
      c1     => clk_cal,     -- 50Mhz calibration clock for Altera reconfig cores
      locked => locked);     -- '1' when the PLL has locked
  
  reset : gc_reset
    port map(
      free_clk_i => clk125_i,
      locked_i   => locked,
      clks_i     => reset_clks,
      rstn_o     => reset_rstn);
  reset_clks(0) <= clk_sys;
  clk_sys_rstn <= reset_rstn(0);
  
  -- The top-most Wishbone B.4 crossbar
  interconnect : xwb_sdb_crossbar
   generic map(
     g_num_masters => c_masters,
     g_num_slaves  => c_slaves,
     g_registered  => true,
     g_wraparound  => false, -- Should be true for nested buses
     g_layout      => c_layout,
     g_sdb_addr    => c_sdb_address)
   port map(
     clk_sys_i     => clk_sys,
     rst_n_i       => clk_sys_rstn,
     -- Master connections (INTERCON is a slave)
     slave_i       => cbar_slave_i,
     slave_o       => cbar_slave_o,
     -- Slave connections (INTERCON is a master)
     master_i      => cbar_master_i,
     master_o      => cbar_master_o);
  
  -- Master 0 is the PCIe bridge
  PCIe : pcie_wb
    generic map(
      sdb_addr => c_sdb_address)
    port map(
      clk125_i      => clk125_i,      -- Free running clock
      cal_clk50_i   => clk_cal,       -- Transceiver global calibration clock
      pcie_refclk_i => pcie_refclk_i, -- External PCIe 100MHz bus clock
      pcie_rstn_i   => pcie_rstn_i,   -- External PCIe system reset pin
      pcie_rx_i     => pcie_rx_i,
      pcie_tx_o     => pcie_tx_o,
      wb_clk        => clk_sys,       -- Desired clock for the WB bus
      wb_rstn_i     => clk_sys_rstn,
      master_o      => cbar_slave_i(0),
      master_i      => cbar_slave_o(0));
  
  -- The LM32 is master 1+2
  lm32_rstn <= clk_sys_rstn and not r_reset;
  LM32 : xwb_lm32
    generic map(
      g_profile => "medium_icache_debug") -- Including JTAG and I-cache (no divide)
    port map(
      clk_sys_i => clk_sys,
      rst_n_i   => lm32_rstn,
      irq_i     => lm32_interrupt,
      dwb_o     => cbar_slave_i(1), -- Data bus
      dwb_i     => cbar_slave_o(1),
      iwb_o     => cbar_slave_i(2), -- Instruction bus
      iwb_i     => cbar_slave_o(2));
  
  -- The other 31 interrupt pins are unconnected
  lm32_interrupt(31 downto 1) <= (others => '0');
  
  -- A DMA controller is master 3+4, slave 2, and interrupt 0
  dma : xwb_dma
    port map(
      clk_i       => clk_sys,
      rst_n_i     => clk_sys_rstn,
      slave_i     => cbar_master_o(2),
      slave_o     => cbar_master_i(2),
      r_master_i  => cbar_slave_o(3),
      r_master_o  => cbar_slave_i(3),
      w_master_i  => cbar_slave_o(4),
      w_master_o  => cbar_slave_i(4),
      interrupt_o => lm32_interrupt(0));
  
  -- Slave 0 is the RAM
  ram : xwb_dpram
    generic map(
      g_size                  => c_dpram_size,
      g_slave1_interface_mode => PIPELINED, -- Why isn't this the default?!
      g_slave2_interface_mode => PIPELINED,
      g_slave1_granularity    => BYTE,
      g_slave2_granularity    => WORD)
    port map(
      clk_sys_i => clk_sys,
      rst_n_i   => clk_sys_rstn,
      -- First port connected to the crossbar
      slave1_i  => cbar_master_o(0),
      slave1_o  => cbar_master_i(0),
      -- Second port disconnected
      slave2_i  => cc_dummy_slave_in, -- CYC always low
      slave2_o  => open);
  
  -- Slave 1 is the example LED driver
  gpio_slave_i <= cbar_master_o(1);
  cbar_master_i(1) <= gpio_slave_o;
  leds_o <= not r_leds;
  
  -- There is a tool called 'wbgen2' which can autogenerate a Wishbone
  -- interface and C header file, but this is a simple example.
  gpio : process(clk_sys)
  begin
    if rising_edge(clk_sys) then
      -- It is vitally important that for each occurance of
      --   (cyc and stb and not stall) there is (ack or rty or err)
      --   sometime later on the bus.
      --
      -- This is an easy solution for a device that never stalls:
      gpio_slave_o.ack <= gpio_slave_i.cyc and gpio_slave_i.stb;
      
      -- Detect a write to the register byte
      if gpio_slave_i.cyc = '1' and gpio_slave_i.stb = '1' and
         gpio_slave_i.we = '1' and gpio_slave_i.sel(0) = '1' then
	-- Register 0x0 = LEDs, 0x4 = CPU reset
	if gpio_slave_i.adr(2) = '0' then
          r_leds <= gpio_slave_i.dat(7 downto 0);
	else
	  r_reset <= gpio_slave_i.dat(0);
	end if;
      end if;
      
      if gpio_slave_i.adr(2) = '0' then
        gpio_slave_o.dat(31 downto 8) <= (others => '0');
        gpio_slave_o.dat(7 downto 0) <= r_leds;
      else
        gpio_slave_o.dat(31 downto 2) <= (others => '0');
        gpio_slave_o.dat(0) <= r_reset;
      end if;
    end if;
  end process;
  gpio_slave_o.int <= '0'; -- In my opinion, this should not be in the structure,
                           -- but it is in there. Bother Thomasz to remove it.
  gpio_slave_o.err <= '0';
  gpio_slave_o.rty <= '0';
  gpio_slave_o.stall <= '0'; -- This simple example is always ready
end rtl;
