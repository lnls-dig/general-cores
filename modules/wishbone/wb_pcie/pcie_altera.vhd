library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pcie_altera is
  port(
    clk125_i      : in  std_logic; -- 125 MHz, free running
    cal_clk50_i   : in  std_logic; --  50 MHz, shared between all PHYs
    rstn_i        : in  std_logic; -- Power on reset
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
    tx_pad_i      : in  std_logic);
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
  signal rx_st_be0 : std_logic_vector(7 downto 0);
  signal rx_st_data0 : std_logic_vector(63 downto 0);
  signal rx_st_bardec0 : std_logic_vector(7 downto 0);
  
  signal r64_ready : std_logic_vector(1 downto 0); -- length must equal the latency of the Avalon RX bus
  signal r64_dat, s64_dat : std_logic_vector(63 downto 0);
  signal s64_need_refill, s64_filling, s64_valid, s64_advance, r64_full, r64_skip, s64_skip : std_logic;
  
  signal r32_word, s32_word, s32_progress, r32_full, s32_need_refill, r32_skip, s32_enter0 : std_logic;
  signal r32_dat0, r32_dat1 : std_logic_vector(31 downto 0);
  
  -- TX registers and signals
  
  constant log_bytes  : integer := 9; -- 256 byte maximum TLP, but we allocate twice the space to simplify provisioning
  constant buf_length : integer := (2**log_bytes)/8;
  constant buf_bits   : integer := log_bytes-3;
  type queue_t is array(buf_length-1 downto 0) of std_logic_vector(64 downto 0);
  
  signal tx_st_sop0, tx_st_eop0, tx_st_ready0, tx_st_valid0 : std_logic;
  signal tx_st_data0 : std_logic_vector(63 downto 0);
  signal s_eop, tx_queue_stall : std_logic;
  signal r_tx_sop : std_logic := '1';
  
  signal queue : queue_t;
  
  -- Invariant idxr <= idxe <= idxw <= idxa, extra bit is for wrap-around
  signal r_idxr, r_idxw, r_idxa, r_idxe, s_idxw_p1 : unsigned(buf_bits downto 0);
  signal r_delay_ready : std_logic_vector(1 downto 0); -- length must equal the latency of the Avalon TX bus
  
  signal s_queue_wdat : std_logic_vector(63 downto 0);
  signal s_queue_wen, s_64to32_full, r_tx32_full : std_logic;
  
  constant zero32 : std_logic_vector(31 downto 0) := (others => '0');
  signal r_tx_dat0 : std_logic_vector(31 downto 0);
  
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
      rx_st_be0            => rx_st_be0, --  7 downto 0
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
      app_int_sts          => '0',
      app_msi_num          => (others => '0'), -- 4 downto 0
      app_msi_req          => '0',
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
  
  npor <= rstn_i and pcie_rstn_i;
  rstn <= rstn_i or rst_reg;
  rstn_o <= rstn;
  
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
  rx_wb_bar_o(0) <= (rx_st_bardec0(1) or rx_st_bardec0(3) or rx_st_bardec0(5) or rx_st_bardec0(7));
  rx_wb_bar_o(1) <= (rx_st_bardec0(2) or rx_st_bardec0(3) or rx_st_bardec0(6) or rx_st_bardec0(7));
  rx_wb_bar_o(2) <= (rx_st_bardec0(4) or rx_st_bardec0(5) or rx_st_bardec0(6) or rx_st_bardec0(7));
  
  -- Stream rx data out as wishbone
  rx_wb_stb_o <= r32_full;
  rx_wb_dat_o <= r32_dat0;
  
  -- Advance state if the WB RX bus made progress
  s32_progress <= r32_full and not rx_wb_stall_i;
  s32_word <= (not r32_word and not r32_skip) when s32_progress = '1' else r32_word;
  s32_enter0 <= (r32_word or r32_skip) and s32_progress;
  
  -- The 32-bit buffers become empty when transitioning to word0
  s32_need_refill <= not r32_full or s32_enter0;
  
  -- Grab data when we need data and there is some ready
  s64_advance <= s64_valid and s32_need_refill;
  
  rx_data32 : process(core_clk_out)
  begin
    if rising_edge(core_clk_out) then
      if rstn = '0' then
        r32_word <= '0';
        r32_full <= '0';
      else
        r32_full <= s64_valid or not s32_need_refill;
        r32_word <= s32_word;
      end if;
      
      if s64_advance = '1' then
        r32_dat0 <= s64_dat(31 downto 0);
        r32_dat1 <= s64_dat(63 downto 32);
        r32_skip <= s64_skip;
      end if;
      
      if s32_word = '1' then
        r32_dat0 <= r32_dat1;
      end if;
    end if;
  end process;
  
  -- Is the Avalon bus filling data this cycle?
  s64_filling <= rx_st_valid0 and r64_ready(r64_ready'length-1);
  -- Can we provide data to the 32-bit layer on this cycle?
  s64_valid <= r64_full or s64_filling;
  -- We need to refill our buffer if we were empty or just got drained
  s64_need_refill <= s64_advance or not s64_valid;
  
  -- Supply the 64-bit data to the 32-bit stream with possible asynchronous bypass
  s64_dat <= r64_dat when r64_full = '1' else rx_st_data0;
  s64_skip <= r64_skip when r64_full = '1' else is_zero(rx_st_be0(7 downto 4));
  
  -- Issue a fetch only if we need refill and no fetch is pending
  rx_st_ready0 <= s64_need_refill and is_zero(r64_ready(r64_ready'length-2 downto 0));
  
  rx_data64 : process(core_clk_out)
  begin
    if rising_edge(core_clk_out) then
      if rstn = '0' then
        r64_full <= '0';
        r64_ready <= (others => '0');
      else
        r64_full <= not s64_need_refill;
        r64_ready <= r64_ready(r64_ready'length-2 downto 0) & rx_st_ready0;
      end if;
      
      r64_dat <= s64_dat;
      r64_skip <= s64_skip;
    end if;
  end process;
  
  -- TX queue
  tx_st_data0 <= queue(to_integer(r_idxr(buf_bits-1 downto 0)))(63 downto 0);
  s_eop       <= queue(to_integer(r_idxr(buf_bits-1 downto 0)))(64);
  tx_st_eop0  <= s_eop;
  tx_st_sop0  <= r_tx_sop;
  
  tx_st_valid0 <= active_high(r_idxr /= r_idxe) and r_delay_ready(r_delay_ready'length-1);
  
  tx_data64_r : process(core_clk_out)
  begin
    if rising_edge(core_clk_out) then
      if rstn = '0' then
        r_delay_ready <= (others => '0');
        r_idxr <= (others => '0');
        r_tx_sop <= '1';
      else
        r_delay_ready <= r_delay_ready(r_delay_ready'length-2 downto 0) & tx_st_ready0;
        if tx_st_valid0 = '1' then
          r_idxr <= r_idxr + 1;
          r_tx_sop <= s_eop;
        end if;
      end if;
    end if;
  end process;
  
  -- can only accept data if A pointer has not wrapped around the buffer to point at the R pointer
  tx_rdy_o <= active_high(r_idxa(buf_bits-1 downto 0) /= r_idxr(buf_bits-1 downto 0)) or
              active_high(r_idxa(buf_bits) = r_idxr(buf_bits));
  
  s_idxw_p1 <= r_idxw + 1;
  tx_data64_w : process(core_clk_out)
  begin
    if rising_edge(core_clk_out) then
      if rstn = '0' then
        r_idxw <= (others => '0');
        r_idxa <= (others => '0');
        r_idxe <= (others => '0');
      else
        queue(to_integer(r_idxw(buf_bits-1 downto 0))) <= tx_eop_i & s_queue_wdat;
        
        if s_queue_wen = '1' then
          r_idxw <= s_idxw_p1;
        end if;
        
        if (s_queue_wen and tx_eop_i) = '1' then
          r_idxe <= s_idxw_p1;
          r_idxa <= s_idxw_p1; -- clear over-allocation
        end if;
        
        if tx_alloc_i = '1' then
          -- !!! insanely wasteful. fix.
          r_idxa <= r_idxa + 1;
        end if;
      end if;
    end if;
  end process;
  
  s_queue_wdat <= 
    (zero32 & tx_dat_i) when r_tx32_full = '0' else
    (tx_dat_i & r_tx_dat0);
  
  s_64to32_full <= r_tx32_full or tx_pad_i or tx_eop_i;
  s_queue_wen <= tx_en_i and s_64to32_full;
  
  tx_data32 : process(core_clk_out)
  begin
    if rising_edge(core_clk_out) then
      if rstn = '0' then
        r_tx_dat0 <= (others => '0');
        r_tx32_full <= '0';
      else
        if tx_en_i = '1' then
          r_tx_dat0 <= tx_dat_i;
          r_tx32_full <= not s_64to32_full;
        end if;
      end if;
    end if;
  end process;
end rtl;
