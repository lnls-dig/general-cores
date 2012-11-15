library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcie_altera is
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
    wb_clk_o      : out std_logic; -- core_clk_out (of PCIe Hard-IP)
    wb_rstn_i     : in  std_logic; -- wb_rstn_i in PCIe clock domain
    
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
    tx_eop_i      : in  std_logic); -- Mark last strobe
end pcie_altera;

architecture rtl of pcie_altera is
  component altera_reconfig is
    port(
      reconfig_clk     : in  std_logic;
      reconfig_fromgxb : in  std_logic_vector(16 downto 0);
      busy             : out std_logic;
      reconfig_togxb   : out std_logic_vector(3 downto 0));
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
  
  function is_zero(x : std_logic_vector) return std_logic is
    constant zero : std_logic_vector(x'length-1 downto 0) := (others => '0');
  begin
    if x = zero then
      return '1';
    else
      return '0';
    end if;
  end is_zero;
  
  function active_high(x : boolean) return std_logic is
  begin
    if x then
      return '1';
    else
      return '0';
    end if;
  end active_high;

  signal core_clk_out : std_logic;
  signal rstn : std_logic;
  
  signal reconfig_clk     : std_logic;
  signal reconfig_busy    : std_logic;
  signal reconfig_fromgxb : std_logic_vector(16 downto 0);
  signal reconfig_togxb   : std_logic_vector(3 downto 0);
  
  signal tl_cfg_add   : std_logic_vector(3 downto 0);
  signal tl_cfg_ctl   : std_logic_vector(31 downto 0);
  signal tl_cfg_delay : std_logic_vector(3 downto 0);
  
  signal l2_exit, hotrst_exit, dlup_exit : std_logic;
  signal npor, crst, srst, rst_reg : std_logic;
  signal pme_shift : std_logic_vector(4 downto 0);
  
  -- RX registers and signals
  
  signal rx_st_ready0, rx_st_valid0 : std_logic;
  signal rx_st_data0 : std_logic_vector(63 downto 0);
  signal rx_st_bardec0 : std_logic_vector(7 downto 0);
  
  signal rx_wb_stb, rx_data_full : std_logic;
  signal rx_data_cache : std_logic_vector(63 downto 0);
  signal rx_ready_delay : std_logic_vector(1 downto 0); -- length must equal the latency of the Avalon RX bus
  
  -- TX registers and signals
  
  constant log_bytes  : integer := 8; -- 256 byte maximum TLP
  constant buf_length : integer := (2**log_bytes)/8;
  constant buf_bits   : integer := log_bytes-3;
  type queue_t is array(buf_length-1 downto 0) of std_logic_vector(64 downto 0);
  signal queue : queue_t;
  
  signal tx_st_sop0, tx_st_eop0, tx_st_ready0, tx_st_valid0 : std_logic;
  signal tx_st_data0 : std_logic_vector(63 downto 0);
  
  signal tx_ready_delay : std_logic_vector(1 downto 0); -- length must equal the latency of the Avalon TX bus
  signal tx_eop, tx_sop : std_logic := '1';
  -- Invariant idxr <= idxe <= idxw <= idxa, extra bit is for wrap-around
  signal tx_idxr, tx_idxe, tx_idxw, tx_idxa, tx_idxw_p1 : unsigned(buf_bits downto 0);
  
begin

  reconfig_clk <= cal_clk50_i;
  wb_clk_o <= core_clk_out;
  
  reconfig : altera_reconfig
    port map(
      reconfig_clk     => reconfig_clk,
      reconfig_fromgxb => reconfig_fromgxb,
      busy             => reconfig_busy,
      reconfig_togxb   => reconfig_togxb);
   
  pcie : altera_pcie
    port map(
      -- Clocking
      refclk               => pcie_refclk_i,
      pld_clk              => core_clk_out,
      core_clk_out         => core_clk_out,
      -- Simulation only clocks:
      pclk_in              => pcie_refclk_i,
      clk250_out           => open,
      clk500_out           => open,
      
      -- Transceiver control
      cal_blk_clk          => cal_clk50_i, -- All transceivers in FPGA must use the same calibration clock
      reconfig_clk         => reconfig_clk,
      fixedclk_serdes      => clk125_i,
      gxb_powerdown        => '0',
      pll_powerdown        => '0',
      reconfig_togxb       => reconfig_togxb,
      reconfig_fromgxb     => reconfig_fromgxb,
      busy_altgxb_reconfig => reconfig_busy,
      
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
      rx_st_ready0         => rx_st_ready0,
      rx_st_bardec0        => rx_st_bardec0, --  7 downto 0
      rx_st_be0            => open, --  7 downto 0
      rx_st_data0          => rx_st_data0, -- 63 downto 0
      rx_st_eop0           => open,
      rx_st_err0           => open,
      rx_st_sop0           => open,
      rx_st_valid0         => rx_st_valid0,
      rx_fifo_empty0       => open, -- informative/debug only (ignore in real design)
      rx_fifo_full0        => open, -- informative/debug only (ignore in real design)
      -- Errors in RX buffer
      derr_cor_ext_rcv0    => open,
      derr_cor_ext_rpl     => open,
      derr_rpl             => open,
      r2c_err0             => open,

      -- Avalon TX
      tx_st_data0          => tx_st_data0,
      tx_st_eop0           => tx_st_eop0,
      tx_st_err0           => '0',
      tx_st_sop0           => tx_st_sop0,
      tx_st_valid0         => tx_st_valid0,
      tx_st_ready0         => tx_st_ready0,
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
      app_int_sts          => app_int_sts,
      app_msi_num          => (others => '0'), -- 4 downto 0
      app_msi_req          => app_msi_req,
      app_msi_tc           => (others => '0'), -- 2 downto 0
      pex_msi_num          => (others => '0'), --  4 downto 0
      app_int_ack          => open,
      app_msi_ack          => open,
      
      -- PCIe configuration space
      hpg_ctrler           => (others => '0'), --  4 downto 0
      tl_cfg_add           => tl_cfg_add, --  3 downto 0
      tl_cfg_ctl           => tl_cfg_ctl, -- 31 downto 0
      tl_cfg_ctl_wr        => open,
      tl_cfg_sts           => open, -- 52 downto 0
      tl_cfg_sts_wr        => open,
      
      -- Power management signals
      pm_auxpwr            => '0',
      pm_data              => (others => '0'), -- 9 downto 0
      pm_event             => '0',
      pme_to_cr            => pme_shift(pme_shift'length-1),
      pme_to_sr            => pme_shift(0),
      
      -- Reset and link training
      npor                 => npor,
      srst                 => srst,
      crst                 => crst,
      l2_exit              => l2_exit,
      hotrst_exit          => hotrst_exit,
      dlup_exit            => dlup_exit,
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
  
  
  reset : process(core_clk_out)
  begin
    if rising_edge(core_clk_out) then
      pme_shift(pme_shift'length-1 downto 1) <= pme_shift(pme_shift'length-2 downto 0);
      
      if (l2_exit and hotrst_exit and dlup_exit) = '0' then
        rst_reg <= '1';
        crst <= '1';
        srst <= '1';
      else
        rst_reg <= '0';
        crst <= rst_reg;
        srst <= rst_reg;
      end if;
    end if;
  end process;
  
  npor <= async_rstn and pcie_rstn_i; -- async
  rstn <= wb_rstn_i and not crst; -- core_clk_out
  
  -- Recover bus:device IDs from config space
  cfg : process(core_clk_out)
  begin
    if rising_edge(core_clk_out) then
      -- There is some instability on tl_cfg_ctl.
      -- We make sure to latch it in the middle of one of its 8 cycle periods
    
      tl_cfg_delay(tl_cfg_delay'left downto 1) <= tl_cfg_delay(tl_cfg_delay'left-1 downto 0);
      if tl_cfg_add = x"f" then
        tl_cfg_delay(0) <= '0';
      else
        tl_cfg_delay(0) <= '1';
      end if;
      
      if tl_cfg_delay(tl_cfg_delay'left) = '1' and is_zero(tl_cfg_delay(tl_cfg_delay'left-1 downto 0)) = '1' then
        cfg_busdev_o <= tl_cfg_ctl(12 downto 0);
      end if;
    end if;
  end process;
  
  -- Decode one-hot
  rx_bar_o(0) <= (rx_st_bardec0(1) or rx_st_bardec0(3) or rx_st_bardec0(5) or rx_st_bardec0(7));
  rx_bar_o(1) <= (rx_st_bardec0(2) or rx_st_bardec0(3) or rx_st_bardec0(6) or rx_st_bardec0(7));
  rx_bar_o(2) <= (rx_st_bardec0(4) or rx_st_bardec0(5) or rx_st_bardec0(6) or rx_st_bardec0(7));
  
  -- Stream RX data out as wishbone
  -- Wishbone stall is asynchronous, but Avalon ready must appear 2 cycles early
  -- To fix this, we only push data every 2 cycles and divert a word to a cache if needed
  rx_wb_stb <= rx_st_valid0 or rx_data_full;
  rx_wb_stb_o <= rx_wb_stb;
  rx_wb_dat_o <= rx_data_cache when rx_data_full = '1' else rx_st_data0;
  rx_st_ready0 <= is_zero(rx_ready_delay(rx_ready_delay'length-1 downto 1)) 
                  and not (rx_wb_stb and rx_wb_stall_i);
  
  rx_path : process(core_clk_out)
  begin
    if rising_edge(core_clk_out) then
      if rstn = '0' then
        rx_data_full <= '0';
        rx_ready_delay(rx_ready_delay'length-1 downto 1) <= (others => '0');
      else
        rx_data_full <= rx_wb_stb and rx_wb_stall_i;
        rx_ready_delay(rx_ready_delay'length-1 downto 1) <= rx_ready_delay(rx_ready_delay'length-2 downto 0);
        
        if rx_st_valid0 = '1' then
          rx_data_cache <= rx_st_data0;
        end if;
      end if;
    end if;
  end process;
  rx_ready_delay(0) <= rx_st_ready0;
  
  -- Dump TX out from a FIFO
  tx_st_data0 <= queue(to_integer(tx_idxr(buf_bits-1 downto 0)))(63 downto 0);
  tx_eop      <= queue(to_integer(tx_idxr(buf_bits-1 downto 0)))(64);
  tx_st_eop0  <= tx_eop;
  tx_st_sop0  <= tx_sop;
  
  tx_st_valid0 <= active_high(tx_idxr /= tx_idxe) and tx_ready_delay(tx_ready_delay'length-1);
  
  tx_dequeue : process(core_clk_out)
  begin
    if rising_edge(core_clk_out) then
      if rstn = '0' then
        tx_ready_delay <= (others => '0');
        tx_idxr <= (others => '0');
        tx_sop <= '1';
      else
        tx_ready_delay <= tx_ready_delay(tx_ready_delay'length-2 downto 0) & tx_st_ready0;
        if tx_st_valid0 = '1' then
          tx_idxr <= tx_idxr + 1;
          tx_sop <= tx_eop;
        end if;
      end if;
    end if;
  end process;
  
  -- Enqueue outgoing packets to a FIFO
  -- can only accept data if A pointer has not wrapped around the buffer to point at the R pointer
  tx_rdy_o <= active_high(tx_idxa(buf_bits-1 downto 0) /= tx_idxr(buf_bits-1 downto 0)) or
              active_high(tx_idxa(buf_bits) = tx_idxr(buf_bits));
  
  tx_idxw_p1 <= tx_idxw + 1;
  tx_enqueue : process(core_clk_out)
  begin
    if rising_edge(core_clk_out) then
      if rstn = '0' then
        tx_idxw <= (others => '0');
        tx_idxa <= (others => '0');
        tx_idxe <= (others => '0');
      else
        queue(to_integer(tx_idxw(buf_bits-1 downto 0))) <= tx_eop_i & tx_wb_dat_i;
        
        if tx_wb_stb_i = '1' then
          tx_idxw <= tx_idxw_p1;
        end if;
        
        if (tx_wb_stb_i and tx_eop_i) = '1' then
          tx_idxe <= tx_idxw_p1;
          tx_idxa <= tx_idxw_p1; -- clear over-allocation (!!! should not be needed in future)
        end if;
        
        if tx_alloc_i = '1' then
          tx_idxa <= tx_idxa + 1;
        end if;
      end if;
    end if;
  end process;
end rtl;
