library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.pcie_wb_pkg.all;

entity pcie_wb is
  port(
    clk125_i      : in  std_logic; -- 125 MHz, free running
--    cal_clk50_i   : in  std_logic; --  50 MHz, shared between all PHYs
--    rstn_i        : in  std_logic;
    
    pcie_refclk_i : in  std_logic; -- 100 MHz, must not derive clk125_i or cal_clk50_i
    pcie_rstn_i   : in  std_logic;
    pcie_rx_i     : in  std_logic_vector(3 downto 0);
    pcie_tx_o     : out std_logic_vector(3 downto 0);
    
    led_o         : out std_logic_vector(0 to 7));
end pcie_wb;

architecture rtl of pcie_wb is
  component altera_pcie_pll is
    port(
      areset : in  std_logic := '0';
      inclk0 : in  std_logic := '0';
      c0     : out std_logic;
      locked : out std_logic);
  end component;
  
  component pow_reset is
    port (
      clk    : in     std_logic;        -- 125Mhz
      nreset : buffer std_logic
   );
  end component;
  
  signal cal_blk_clk, wb_clk : std_logic; -- Should be input in final version
  
  signal count : unsigned(26 downto 0) := to_unsigned(0, 27);
  signal led_r : std_logic := '0';
  signal locked, pow_rstn, phy_rstn, rstn, stall : std_logic;
  
  constant stall_pattern : std_logic_vector(15 downto 0) := "1111010110111100";
  signal stall_idx : unsigned(3 downto 0);
  
  signal rx_wb_stb, rx_wb_stall : std_logic;
  signal rx_wb_dat : std_logic_vector(31 downto 0);
begin

  reset : pow_reset
    port map (
      clk    => clk125_i,
      nreset => pow_rstn
    );

  pll : altera_pcie_pll
    port map(
      areset => '0',
      inclk0 => clk125_i,
      c0     => cal_blk_clk,
      locked => locked);
      
  phy_rstn <= pow_rstn and locked;
  
  pcie_phy : pcie_altera port map(
    clk125_i      => clk125_i,
    cal_clk50_i   => cal_blk_clk,
    rstn_i        => phy_rstn,
    rstn_o        => rstn,
    pcie_refclk_i => pcie_refclk_i,
    pcie_rstn_i   => pcie_rstn_i,
    pcie_rx_i     => pcie_rx_i,
    pcie_tx_o     => pcie_tx_o,
    wb_clk_o      => wb_clk,
    rx_wb_stb_o   => rx_wb_stb,
    rx_wb_dat_o   => rx_wb_dat,
    rx_wb_stall_i => rx_wb_stall,
    -- No TX... yet.
    tx_wb_stb_i   => '0',
    tx_wb_dat_i   => (others => '0'),
    tx_wb_stall_o => open);
  
  pcie_logic : pcie_tlp port map(
    clk_i         => wb_clk,
    rstn_i        => rstn,
    
    rx_wb_stb_i   => rx_wb_stb,
    rx_wb_bar_i   => '0',
    rx_wb_dat_i   => rx_wb_dat,
    rx_wb_stall_o => rx_wb_stall,
    
    wb_stb_o      => open,
    wb_adr_o      => open,
    wb_we_o       => open,
    wb_dat_o      => open,
    wb_sel_o      => open,
    wb_stall_i    => stall);
  
  blink : process(wb_clk)
  begin
    if rising_edge(wb_clk) then
      count <= count + to_unsigned(1, count'length);
      if count = 0 then
        led_r <= not led_r;
      end if;
      
      stall <= stall_pattern(to_integer(stall_idx));
      stall_idx <= stall_idx + 1;
    end if;
  end process;
  
  led_o(0) <= led_r;
  led_o(1 to 7) <= (others => '1');
end rtl;
