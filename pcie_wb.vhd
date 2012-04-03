library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcie_wb is
  port(
    pcie_clk125_i : in  std_logic; -- 125 MHz
    pcie_refclk_i : in  std_logic; -- 100 MHz
    pcie_rstn_i   : in  std_logic;
    pcie_rx_i     : in  std_logic_vector(3 downto 0);
    pcie_tx_o     : out std_logic_vector(3 downto 0);
    led_o         : out std_logic);
end pcie_wb;

architecture rtl of pcie_wb is
  component altera_reconfig is
    port(
      reconfig_clk     : in  std_logic;
      reconfig_fromgxb : in  std_logic_vector(16 downto 0);
      busy             : out std_logic;
      reconfig_togxb   : out std_logic_vector(3 downto 0));
  end component;
  
  component altera_pcie_pll is
    port(
      areset : in  std_logic := '0';
      inclk0 : in  std_logic := '0';
      c0     : out std_logic;
      locked : out std_logic);
  end component;
  
  component altera_pcie is 
    port (
      signal app_int_sts          : in  std_logic;
      signal app_msi_num          : in  std_logic_vector (4 downto 0);
      signal app_msi_req          : in  std_logic;
      signal app_msi_tc           : in  std_logic_vector (2 downto 0);
      signal busy_altgxb_reconfig : in  std_logic;
      signal cal_blk_clk          : in  std_logic;
      signal cpl_err              : in  std_logic_vector (6 downto 0);
      signal cpl_pending          : in  std_logic;
      signal crst                 : in  std_logic;
      signal fixedclk_serdes      : in  std_logic;
      signal gxb_powerdown        : in  std_logic;
      signal hpg_ctrler           : in  std_logic_vector (4 downto 0);
      signal lmi_addr             : in  std_logic_vector (11 downto 0);
      signal lmi_din              : in  std_logic_vector (31 downto 0);
      signal lmi_rden             : in  std_logic;
      signal lmi_wren             : in  std_logic;
      signal npor                 : in  std_logic;
      signal pclk_in              : in  std_logic;
      signal pex_msi_num          : in  std_logic_vector (4 downto 0);
      signal phystatus_ext        : in  std_logic;
      signal pipe_mode            : in  std_logic;
      signal pld_clk              : in  std_logic;
      signal pll_powerdown        : in  std_logic;
      signal pm_auxpwr            : in  std_logic;
      signal pm_data              : in  std_logic_vector (9 downto 0);
      signal pm_event             : in  std_logic;
      signal pme_to_cr            : in  std_logic;
      signal reconfig_clk         : in  std_logic;
      signal reconfig_togxb       : in  std_logic_vector (3 downto 0);
      signal refclk               : in  std_logic;
      signal rx_in0               : in  std_logic;
      signal rx_in1               : in  std_logic;
      signal rx_in2               : in  std_logic;
      signal rx_in3               : in  std_logic;
      signal rx_st_mask0          : in  std_logic;
      signal rx_st_ready0         : in  std_logic;
      signal rxdata0_ext          : in  std_logic_vector (7 downto 0);
      signal rxdata1_ext          : in  std_logic_vector (7 downto 0);
      signal rxdata2_ext          : in  std_logic_vector (7 downto 0);
      signal rxdata3_ext          : in  std_logic_vector (7 downto 0);
      signal rxdatak0_ext         : in  std_logic;
      signal rxdatak1_ext         : in  std_logic;
      signal rxdatak2_ext         : in  std_logic;
      signal rxdatak3_ext         : in  std_logic;
      signal rxelecidle0_ext      : in  std_logic;
      signal rxelecidle1_ext      : in  std_logic;
      signal rxelecidle2_ext      : in  std_logic;
      signal rxelecidle3_ext      : in  std_logic;
      signal rxstatus0_ext        : in  std_logic_vector (2 downto 0);
      signal rxstatus1_ext        : in  std_logic_vector (2 downto 0);
      signal rxstatus2_ext        : in  std_logic_vector (2 downto 0);
      signal rxstatus3_ext        : in  std_logic_vector (2 downto 0);
      signal rxvalid0_ext         : in  std_logic;
      signal rxvalid1_ext         : in  std_logic;
      signal rxvalid2_ext         : in  std_logic;
      signal rxvalid3_ext         : in  std_logic;
      signal srst                 : in  std_logic;
      signal test_in              : in  std_logic_vector (39 downto 0);
      signal tx_st_data0          : in  std_logic_vector (63 downto 0);
      signal tx_st_eop0           : in  std_logic;
      signal tx_st_err0           : in  std_logic;
      signal tx_st_sop0           : in  std_logic;
      signal tx_st_valid0         : in  std_logic;
      signal app_int_ack          : out std_logic;
      signal app_msi_ack          : out std_logic;
      signal clk250_out           : out std_logic;
      signal clk500_out           : out std_logic;
      signal core_clk_out         : out std_logic;
      signal derr_cor_ext_rcv0    : out std_logic;
      signal derr_cor_ext_rpl     : out std_logic;
      signal derr_rpl             : out std_logic;
      signal dlup_exit            : out std_logic;
      signal hotrst_exit          : out std_logic;
      signal ko_cpl_spc_vc0       : out std_logic_vector (19 downto 0);
      signal l2_exit              : out std_logic;
      signal lane_act             : out std_logic_vector (3 downto 0);
      signal lmi_ack              : out std_logic;
      signal lmi_dout             : out std_logic_vector (31 downto 0);
      signal ltssm                : out std_logic_vector (4 downto 0);
      signal npd_alloc_1cred_vc0  : out std_logic;
      signal npd_cred_vio_vc0     : out std_logic;
      signal nph_alloc_1cred_vc0  : out std_logic;
      signal nph_cred_vio_vc0     : out std_logic;
      signal pme_to_sr            : out std_logic;
      signal powerdown_ext        : out std_logic_vector (1 downto 0);
      signal r2c_err0             : out std_logic;
      signal rate_ext             : out std_logic;
      signal rc_pll_locked        : out std_logic;
      signal rc_rx_digitalreset   : out std_logic;
      signal reconfig_fromgxb     : out std_logic_vector (16 downto 0);
      signal reset_status         : out std_logic;
      signal rx_fifo_empty0       : out std_logic;
      signal rx_fifo_full0        : out std_logic;
      signal rx_st_bardec0        : out std_logic_vector (7 downto 0);
      signal rx_st_be0            : out std_logic_vector (7 downto 0);
      signal rx_st_data0          : out std_logic_vector (63 downto 0);
      signal rx_st_eop0           : out std_logic;
      signal rx_st_err0           : out std_logic;
      signal rx_st_sop0           : out std_logic;
      signal rx_st_valid0         : out std_logic;
      signal rxpolarity0_ext      : out std_logic;
      signal rxpolarity1_ext      : out std_logic;
      signal rxpolarity2_ext      : out std_logic;
      signal rxpolarity3_ext      : out std_logic;
      signal suc_spd_neg          : out std_logic;
      signal test_out             : out std_logic_vector (8 downto 0);
      signal tl_cfg_add           : out std_logic_vector (3 downto 0);
      signal tl_cfg_ctl           : out std_logic_vector (31 downto 0);
      signal tl_cfg_ctl_wr        : out std_logic;
      signal tl_cfg_sts           : out std_logic_vector (52 downto 0);
      signal tl_cfg_sts_wr        : out std_logic;
      signal tx_cred0             : out std_logic_vector (35 downto 0);
      signal tx_fifo_empty0       : out std_logic;
      signal tx_fifo_full0        : out std_logic;
      signal tx_fifo_rdptr0       : out std_logic_vector (3 downto 0);
      signal tx_fifo_wrptr0       : out std_logic_vector (3 downto 0);
      signal tx_out0              : out std_logic;
      signal tx_out1              : out std_logic;
      signal tx_out2              : out std_logic;
      signal tx_out3              : out std_logic;
      signal tx_st_ready0         : out std_logic;
      signal txcompl0_ext         : out std_logic;
      signal txcompl1_ext         : out std_logic;
      signal txcompl2_ext         : out std_logic;
      signal txcompl3_ext         : out std_logic;
      signal txdata0_ext          : out std_logic_vector (7 downto 0);
      signal txdata1_ext          : out std_logic_vector (7 downto 0);
      signal txdata2_ext          : out std_logic_vector (7 downto 0);
      signal txdata3_ext          : out std_logic_vector (7 downto 0);
      signal txdatak0_ext         : out std_logic;
      signal txdatak1_ext         : out std_logic;
      signal txdatak2_ext         : out std_logic;
      signal txdatak3_ext         : out std_logic;
      signal txdetectrx_ext       : out std_logic;
      signal txelecidle0_ext      : out std_logic;
      signal txelecidle1_ext      : out std_logic;
      signal txelecidle2_ext      : out std_logic;
      signal txelecidle3_ext      : out std_logic);
   end component;

  signal reconfig_clk     : std_logic;
  signal reconfig_fromgxb : std_logic_vector(16 downto 0);
  signal reconfig_togxb   : std_logic_vector(3 downto 0);
  signal core_clk_out     : std_logic;
  
  signal count : unsigned(26 downto 0) := to_unsigned(0, 27);
  signal led_r : std_logic := '0';
begin

  reconfig : altera_reconfig
    port map(
      reconfig_clk     => reconfig_clk,
      reconfig_fromgxb => reconfig_fromgxb,
      busy             => open,
      reconfig_togxb   => reconfig_togxb);
   
  pll : altera_pcie_pll
    port map(
      areset => '0',
      inclk0 => pcie_clk125_i,
      c0     => reconfig_clk,
      locked => open);
      
  pcie : altera_pcie
    port map(
      -- Clocking
      refclk               => pcie_refclk_i,
      pld_clk              => core_clk_out,
      pclk_in              => pcie_refclk_i,
      clk250_out           => open,
      clk500_out           => open,
      core_clk_out         => core_clk_out,
      
      -- Transceiver control
      cal_blk_clk          => pcie_clk125_i, -- All transceivers in FPGA must use the same calibration clock
      reconfig_clk         => reconfig_clk,
      fixedclk_serdes      => pcie_clk125_i,
      gxb_powerdown        => '0',
      pll_powerdown        => '0',
      reconfig_togxb       => reconfig_togxb,
      reconfig_fromgxb     => reconfig_fromgxb,
      busy_altgxb_reconfig => '1',
      
      -- PCIe lanes
      rx_in0               => pcie_rx_i(0),
      rx_in1               => pcie_rx_i(1),
      rx_in2               => pcie_rx_i(2),
      rx_in3               => pcie_rx_i(3),
      tx_out0              => pcie_tx_o(0),
      tx_out1              => pcie_tx_o(1),
      tx_out2              => pcie_tx_o(2),
      tx_out3              => pcie_tx_o(3),
      
      -- Avalon RX
      rx_st_mask0          => '0',
      rx_st_ready0         => '0',
      rx_st_bardec0        => open, --  7 downto 0
      rx_st_be0            => open, --  7 downto 0
      rx_st_data0          => open, -- 63 downto 0
      rx_st_eop0           => open,
      rx_st_err0           => open,
      rx_st_sop0           => open,
      rx_st_valid0         => open,
      rx_fifo_empty0       => open,
      rx_fifo_full0        => open,
      -- Errors in RX buffer
      derr_cor_ext_rcv0    => open,
      derr_cor_ext_rpl     => open,
      derr_rpl             => open,
      r2c_err0             => open,

      -- Avalon TX
      tx_st_data0          => (others => '0'),
      tx_st_eop0           => '0',
      tx_st_err0           => '0',
      tx_st_sop0           => '0',
      tx_st_valid0         => '0',
      tx_st_ready0         => open,
      tx_fifo_empty0       => open,
      tx_fifo_full0        => open,
      tx_fifo_rdptr0       => open, --  3 downto 0
      tx_fifo_wrptr0       => open, --  3 downto 0
      -- Avalon TX credit management
      tx_cred0             => open, -- 35 downto 0
      npd_alloc_1cred_vc0  => open,
      npd_cred_vio_vc0     => open,
      nph_alloc_1cred_vc0  => open,
      nph_cred_vio_vc0     => open,

      -- Report completion error status
      cpl_err              => (others => '0'), -- 6 downto 0
      cpl_pending          => '0',
      lmi_addr             => (others => '0'), -- 11 downto 0
      lmi_din              => (others => '0'), -- 31 downto 0
      lmi_rden             => '0',
      lmi_wren             => '0',
      lmi_ack              => open,
      lmi_dout             => open, -- 31 downto 0
      ko_cpl_spc_vc0       => open, -- 19 downto 0
      
      -- External PHY (PIPE). Not used; using altera PHY.
      pipe_mode            => '0',
      rxdata0_ext          => (others => '0'), -- 7 downto 0
      rxdata1_ext          => (others => '0'), -- 7 downto 0
      rxdata2_ext          => (others => '0'), -- 7 downto 0
      rxdata3_ext          => (others => '0'), -- 7 downto 0
      rxdatak0_ext         => '0',
      rxdatak1_ext         => '0',
      rxdatak2_ext         => '0',
      rxdatak3_ext         => '0',
      rxelecidle0_ext      => '0',
      rxelecidle1_ext      => '0',
      rxelecidle2_ext      => '0',
      rxelecidle3_ext      => '0',
      rxstatus0_ext        => (others => '0'), -- 2 downto 0
      rxstatus1_ext        => (others => '0'), -- 2 downto 0
      rxstatus2_ext        => (others => '0'), -- 2 downto 0
      rxstatus3_ext        => (others => '0'), -- 2 downto 0
      rxvalid0_ext         => '0',
      rxvalid1_ext         => '0',
      rxvalid2_ext         => '0',
      rxvalid3_ext         => '0',
      rxpolarity0_ext      => open,
      rxpolarity1_ext      => open,
      rxpolarity2_ext      => open,
      rxpolarity3_ext      => open,
      txcompl0_ext         => open,
      txcompl1_ext         => open,
      txcompl2_ext         => open,
      txcompl3_ext         => open,
      txdata0_ext          => open,
      txdata1_ext          => open, --  7 downto 0
      txdata2_ext          => open, --  7 downto 0
      txdata3_ext          => open, --  7 downto 0
      txdatak0_ext         => open,
      txdatak1_ext         => open,
      txdatak2_ext         => open,
      txdatak3_ext         => open,
      txdetectrx_ext       => open,
      txelecidle0_ext      => open,
      txelecidle1_ext      => open,
      txelecidle2_ext      => open,
      txelecidle3_ext      => open,
      phystatus_ext        => '0',
      powerdown_ext        => open, -- 1 downto 0
      rate_ext             => open,
      
      -- PCIe interrupts (for endpoint)
      app_int_sts          => '0',
      app_msi_num          => (others => '0'), -- 4 downto 0
      app_msi_req          => '0',
      app_msi_tc           => (others => '0'), -- 2 downto 0
      pex_msi_num          => (others => '0'), --  4 downto 0
      app_int_ack          => open,
      app_msi_ack          => open,
      
      -- PCIe configuration space
      hpg_ctrler           => (others => '0'), --  4 downto 0
      tl_cfg_add           => open, --  3 downto 0
      tl_cfg_ctl           => open, -- 31 downto 0
      tl_cfg_ctl_wr        => open,
      tl_cfg_sts           => open, -- 52 downto 0
      tl_cfg_sts_wr        => open,
      
      -- Power management signals
      pm_auxpwr            => '0',
      pm_data              => (others => '0'), -- 9 downto 0
      pm_event             => '0',
      pme_to_cr            => '0',
      pme_to_sr            => open,
      
      -- Reset and link training
      npor                 => pcie_rstn_i,
      srst                 => '0',
      crst                 => '0',
      l2_exit              => open,
      hotrst_exit          => open,
      dlup_exit            => open,
      suc_spd_neg          => open,
      ltssm                => open, --  4 downto 0
      rc_pll_locked        => open,
      reset_status         => open,
      
      -- Debugging signals
      lane_act             => open, --  3 downto 0
      test_in              => (others => '0'), -- 39 downto 0
      test_out             => open, --  8 downto 0
      
      -- WTF? Not documented
      rc_rx_digitalreset   => open);
  
  blink : process(pcie_clk125_i)
  begin
    if rising_edge(pcie_clk125_i) then
      count <= count + to_unsigned(1, count'length);
      if count = 0 then
        led_r <= not led_r;
      end if;
    end if;
  end process;
  led_o <= led_r;
end rtl;
