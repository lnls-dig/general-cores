library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.genram_pkg.all;
use work.altera_networks_pkg.all;

entity pcie_altera is
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
  
  component arria2_pcie_reconf is
    port(
      reconfig_clk     : in  std_logic;
      reconfig_fromgxb : in  std_logic_vector(16 downto 0);
      busy             : out std_logic;
      reconfig_togxb   : out std_logic_vector(3 downto 0));
  end component;
  
  component arria2_pcie_hip is 
    port (
      app_int_sts          : in  std_logic;
      app_msi_num          : in  std_logic_vector (4 downto 0);
      app_msi_req          : in  std_logic;
      app_msi_tc           : in  std_logic_vector (2 downto 0);
      busy_altgxb_reconfig : in  std_logic;
      cal_blk_clk          : in  std_logic;
      cpl_err              : in  std_logic_vector (6 downto 0);
      cpl_pending          : in  std_logic;
      crst                 : in  std_logic;
      fixedclk_serdes      : in  std_logic;
      gxb_powerdown        : in  std_logic;
      hpg_ctrler           : in  std_logic_vector (4 downto 0);
      lmi_addr             : in  std_logic_vector (11 downto 0);
      lmi_din              : in  std_logic_vector (31 downto 0);
      lmi_rden             : in  std_logic;
      lmi_wren             : in  std_logic;
      npor                 : in  std_logic;
      pclk_in              : in  std_logic;
      pex_msi_num          : in  std_logic_vector (4 downto 0);
      phystatus_ext        : in  std_logic;
      pipe_mode            : in  std_logic;
      pld_clk              : in  std_logic;
      pll_powerdown        : in  std_logic;
      pm_auxpwr            : in  std_logic;
      pm_data              : in  std_logic_vector (9 downto 0);
      pm_event             : in  std_logic;
      pme_to_cr            : in  std_logic;
      reconfig_clk         : in  std_logic;
      reconfig_togxb       : in  std_logic_vector (3 downto 0);
      refclk               : in  std_logic;
      rx_in0               : in  std_logic;
      rx_in1               : in  std_logic;
      rx_in2               : in  std_logic;
      rx_in3               : in  std_logic;
      rx_st_mask0          : in  std_logic;
      rx_st_ready0         : in  std_logic;
      rxdata0_ext          : in  std_logic_vector (7 downto 0);
      rxdata1_ext          : in  std_logic_vector (7 downto 0);
      rxdata2_ext          : in  std_logic_vector (7 downto 0);
      rxdata3_ext          : in  std_logic_vector (7 downto 0);
      rxdatak0_ext         : in  std_logic;
      rxdatak1_ext         : in  std_logic;
      rxdatak2_ext         : in  std_logic;
      rxdatak3_ext         : in  std_logic;
      rxelecidle0_ext      : in  std_logic;
      rxelecidle1_ext      : in  std_logic;
      rxelecidle2_ext      : in  std_logic;
      rxelecidle3_ext      : in  std_logic;
      rxstatus0_ext        : in  std_logic_vector (2 downto 0);
      rxstatus1_ext        : in  std_logic_vector (2 downto 0);
      rxstatus2_ext        : in  std_logic_vector (2 downto 0);
      rxstatus3_ext        : in  std_logic_vector (2 downto 0);
      rxvalid0_ext         : in  std_logic;
      rxvalid1_ext         : in  std_logic;
      rxvalid2_ext         : in  std_logic;
      rxvalid3_ext         : in  std_logic;
      srst                 : in  std_logic;
      test_in              : in  std_logic_vector (39 downto 0);
      tx_st_data0          : in  std_logic_vector (63 downto 0);
      tx_st_eop0           : in  std_logic;
      tx_st_err0           : in  std_logic;
      tx_st_sop0           : in  std_logic;
      tx_st_valid0         : in  std_logic;
      app_int_ack          : out std_logic;
      app_msi_ack          : out std_logic;
      clk250_out           : out std_logic;
      clk500_out           : out std_logic;
      core_clk_out         : out std_logic;
      derr_cor_ext_rcv0    : out std_logic;
      derr_cor_ext_rpl     : out std_logic;
      derr_rpl             : out std_logic;
      dlup_exit            : out std_logic;
      hotrst_exit          : out std_logic;
      ko_cpl_spc_vc0       : out std_logic_vector (19 downto 0);
      l2_exit              : out std_logic;
      lane_act             : out std_logic_vector (3 downto 0);
      lmi_ack              : out std_logic;
      lmi_dout             : out std_logic_vector (31 downto 0);
      ltssm                : out std_logic_vector (4 downto 0);
      npd_alloc_1cred_vc0  : out std_logic;
      npd_cred_vio_vc0     : out std_logic;
      nph_alloc_1cred_vc0  : out std_logic;
      nph_cred_vio_vc0     : out std_logic;
      pme_to_sr            : out std_logic;
      powerdown_ext        : out std_logic_vector (1 downto 0);
      r2c_err0             : out std_logic;
      rate_ext             : out std_logic;
      rc_pll_locked        : out std_logic;
      rc_rx_digitalreset   : out std_logic;
      reconfig_fromgxb     : out std_logic_vector (16 downto 0);
      reset_status         : out std_logic;
      rx_fifo_empty0       : out std_logic;
      rx_fifo_full0        : out std_logic;
      rx_st_bardec0        : out std_logic_vector (7 downto 0);
      rx_st_be0            : out std_logic_vector (7 downto 0);
      rx_st_data0          : out std_logic_vector (63 downto 0);
      rx_st_eop0           : out std_logic;
      rx_st_err0           : out std_logic;
      rx_st_sop0           : out std_logic;
      rx_st_valid0         : out std_logic;
      rxpolarity0_ext      : out std_logic;
      rxpolarity1_ext      : out std_logic;
      rxpolarity2_ext      : out std_logic;
      rxpolarity3_ext      : out std_logic;
      suc_spd_neg          : out std_logic;
      tl_cfg_add           : out std_logic_vector (3 downto 0);
      tl_cfg_ctl           : out std_logic_vector (31 downto 0);
      tl_cfg_ctl_wr        : out std_logic;
      tl_cfg_sts           : out std_logic_vector (52 downto 0);
      tl_cfg_sts_wr        : out std_logic;
      tx_cred0             : out std_logic_vector (35 downto 0);
      tx_fifo_empty0       : out std_logic;
      tx_fifo_full0        : out std_logic;
      tx_fifo_rdptr0       : out std_logic_vector (3 downto 0);
      tx_fifo_wrptr0       : out std_logic_vector (3 downto 0);
      tx_out0              : out std_logic;
      tx_out1              : out std_logic;
      tx_out2              : out std_logic;
      tx_out3              : out std_logic;
      tx_st_ready0         : out std_logic;
      txcompl0_ext         : out std_logic;
      txcompl1_ext         : out std_logic;
      txcompl2_ext         : out std_logic;
      txcompl3_ext         : out std_logic;
      txdata0_ext          : out std_logic_vector (7 downto 0);
      txdata1_ext          : out std_logic_vector (7 downto 0);
      txdata2_ext          : out std_logic_vector (7 downto 0);
      txdata3_ext          : out std_logic_vector (7 downto 0);
      txdatak0_ext         : out std_logic;
      txdatak1_ext         : out std_logic;
      txdatak2_ext         : out std_logic;
      txdatak3_ext         : out std_logic;
      txdetectrx_ext       : out std_logic;
      txelecidle0_ext      : out std_logic;
      txelecidle1_ext      : out std_logic;
      txelecidle2_ext      : out std_logic;
      txelecidle3_ext      : out std_logic);
  end component;
  
  component arria5_pcie_reconf is
    port(
      reconfig_busy             : out std_logic;                                         --      reconfig_busy.reconfig_busy
      mgmt_clk_clk              : in  std_logic                      := '0';             --       mgmt_clk_clk.clk
      mgmt_rst_reset            : in  std_logic                      := '0';             --     mgmt_rst_reset.reset
      reconfig_mgmt_address     : in  std_logic_vector(6 downto 0)   := (others => '0'); --      reconfig_mgmt.address
      reconfig_mgmt_read        : in  std_logic                      := '0';             --                   .read
      reconfig_mgmt_readdata    : out std_logic_vector(31 downto 0);                     --                   .readdata
      reconfig_mgmt_waitrequest : out std_logic;                                         --                   .waitrequest
      reconfig_mgmt_write       : in  std_logic                      := '0';             --                   .write
      reconfig_mgmt_writedata   : in  std_logic_vector(31 downto 0)  := (others => '0'); --                   .writedata
      reconfig_to_xcvr          : out std_logic_vector(349 downto 0);                    --   reconfig_to_xcvr.reconfig_to_xcvr
      reconfig_from_xcvr        : in  std_logic_vector(229 downto 0) := (others => '0'));-- reconfig_from_xcvr.reconfig_from_xcvr
  end component;
  
  component arria5_pcie_hip is
    port(
      npor               : in  std_logic                      := '0';             --               npor.npor
      pin_perst          : in  std_logic                      := '0';             --                   .pin_perst
      test_in            : in  std_logic_vector(31 downto 0)  := (others => '0'); --           hip_ctrl.test_in
      simu_mode_pipe     : in  std_logic                      := '0';             --                   .simu_mode_pipe
      pld_clk            : in  std_logic                      := '0';             --            pld_clk.clk
      coreclkout         : out std_logic;                                         --     coreclkout_hip.clk
      refclk             : in  std_logic                      := '0';             --             refclk.clk
      rx_in0             : in  std_logic                      := '0';             --         hip_serial.rx_in0
      rx_in1             : in  std_logic                      := '0';             --                   .rx_in1
      rx_in2             : in  std_logic                      := '0';             --                   .rx_in2
      rx_in3             : in  std_logic                      := '0';             --                   .rx_in3
      tx_out0            : out std_logic;                                         --                   .tx_out0
      tx_out1            : out std_logic;                                         --                   .tx_out1
      tx_out2            : out std_logic;                                         --                   .tx_out2
      tx_out3            : out std_logic;                                         --                   .tx_out3
      rx_st_valid        : out std_logic;                                         --              rx_st.valid
      rx_st_sop          : out std_logic;                                         --                   .startofpacket
      rx_st_eop          : out std_logic;                                         --                   .endofpacket
      rx_st_ready        : in  std_logic                      := '0';             --                   .ready
      rx_st_err          : out std_logic;                                         --                   .error
      rx_st_data         : out std_logic_vector(63 downto 0);                     --                   .data
      rx_st_bar          : out std_logic_vector(7 downto 0);                      --          rx_bar_be.rx_st_bar
      rx_st_be           : out std_logic_vector(7 downto 0);                      --                   .rx_st_be
      rx_st_mask         : in  std_logic                      := '0';             --                   .rx_st_mask
      tx_st_valid        : in  std_logic                      := '0';             --              tx_st.valid
      tx_st_sop          : in  std_logic                      := '0';             --                   .startofpacket
      tx_st_eop          : in  std_logic                      := '0';             --                   .endofpacket
      tx_st_ready        : out std_logic;                                         --                   .ready
      tx_st_err          : in  std_logic                      := '0';             --                   .error
      tx_st_data         : in  std_logic_vector(63 downto 0)  := (others => '0'); --                   .data
      tx_fifo_empty      : out std_logic;                                         --            tx_fifo.fifo_empty
      tx_cred_datafccp   : out std_logic_vector(11 downto 0);                     --            tx_cred.tx_cred_datafccp
      tx_cred_datafcnp   : out std_logic_vector(11 downto 0);                     --                   .tx_cred_datafcnp
      tx_cred_datafcp    : out std_logic_vector(11 downto 0);                     --                   .tx_cred_datafcp
      tx_cred_fchipcons  : out std_logic_vector(5 downto 0);                      --                   .tx_cred_fchipcons
      tx_cred_fcinfinite : out std_logic_vector(5 downto 0);                      --                   .tx_cred_fcinfinite
      tx_cred_hdrfccp    : out std_logic_vector(7 downto 0);                      --                   .tx_cred_hdrfccp
      tx_cred_hdrfcnp    : out std_logic_vector(7 downto 0);                      --                   .tx_cred_hdrfcnp
      tx_cred_hdrfcp     : out std_logic_vector(7 downto 0);                      --                   .tx_cred_hdrfcp
      sim_pipe_pclk_in   : in  std_logic                      := '0';             --           hip_pipe.sim_pipe_pclk_in
      sim_pipe_rate      : out std_logic_vector(1 downto 0);                      --                   .sim_pipe_rate
      sim_ltssmstate     : out std_logic_vector(4 downto 0);                      --                   .sim_ltssmstate
      eidleinfersel0     : out std_logic_vector(2 downto 0);                      --                   .eidleinfersel0
      eidleinfersel1     : out std_logic_vector(2 downto 0);                      --                   .eidleinfersel1
      eidleinfersel2     : out std_logic_vector(2 downto 0);                      --                   .eidleinfersel2
      eidleinfersel3     : out std_logic_vector(2 downto 0);                      --                   .eidleinfersel3
      powerdown0         : out std_logic_vector(1 downto 0);                      --                   .powerdown0
      powerdown1         : out std_logic_vector(1 downto 0);                      --                   .powerdown1
      powerdown2         : out std_logic_vector(1 downto 0);                      --                   .powerdown2
      powerdown3         : out std_logic_vector(1 downto 0);                      --                   .powerdown3
      rxpolarity0        : out std_logic;                                         --                   .rxpolarity0
      rxpolarity1        : out std_logic;                                         --                   .rxpolarity1
      rxpolarity2        : out std_logic;                                         --                   .rxpolarity2
      rxpolarity3        : out std_logic;                                         --                   .rxpolarity3
      txcompl0           : out std_logic;                                         --                   .txcompl0
      txcompl1           : out std_logic;                                         --                   .txcompl1
      txcompl2           : out std_logic;                                         --                   .txcompl2
      txcompl3           : out std_logic;                                         --                   .txcompl3
      txdata0            : out std_logic_vector(7 downto 0);                      --                   .txdata0
      txdata1            : out std_logic_vector(7 downto 0);                      --                   .txdata1
      txdata2            : out std_logic_vector(7 downto 0);                      --                   .txdata2
      txdata3            : out std_logic_vector(7 downto 0);                      --                   .txdata3
      txdatak0           : out std_logic;                                         --                   .txdatak0
      txdatak1           : out std_logic;                                         --                   .txdatak1
      txdatak2           : out std_logic;                                         --                   .txdatak2
      txdatak3           : out std_logic;                                         --                   .txdatak3
      txdetectrx0        : out std_logic;                                         --                   .txdetectrx0
      txdetectrx1        : out std_logic;                                         --                   .txdetectrx1
      txdetectrx2        : out std_logic;                                         --                   .txdetectrx2
      txdetectrx3        : out std_logic;                                         --                   .txdetectrx3
      txelecidle0        : out std_logic;                                         --                   .txelecidle0
      txelecidle1        : out std_logic;                                         --                   .txelecidle1
      txelecidle2        : out std_logic;                                         --                   .txelecidle2
      txelecidle3        : out std_logic;                                         --                   .txelecidle3
      txswing0           : out std_logic;                                         --                   .txswing0
      txswing1           : out std_logic;                                         --                   .txswing1
      txswing2           : out std_logic;                                         --                   .txswing2
      txswing3           : out std_logic;                                         --                   .txswing3
      txmargin0          : out std_logic_vector(2 downto 0);                      --                   .txmargin0
      txmargin1          : out std_logic_vector(2 downto 0);                      --                   .txmargin1
      txmargin2          : out std_logic_vector(2 downto 0);                      --                   .txmargin2
      txmargin3          : out std_logic_vector(2 downto 0);                      --                   .txmargin3
      txdeemph0          : out std_logic;                                         --                   .txdeemph0
      txdeemph1          : out std_logic;                                         --                   .txdeemph1
      txdeemph2          : out std_logic;                                         --                   .txdeemph2
      txdeemph3          : out std_logic;                                         --                   .txdeemph3
      phystatus0         : in  std_logic                      := '0';             --                   .phystatus0
      phystatus1         : in  std_logic                      := '0';             --                   .phystatus1
      phystatus2         : in  std_logic                      := '0';             --                   .phystatus2
      phystatus3         : in  std_logic                      := '0';             --                   .phystatus3
      rxdata0            : in  std_logic_vector(7 downto 0)   := (others => '0'); --                   .rxdata0
      rxdata1            : in  std_logic_vector(7 downto 0)   := (others => '0'); --                   .rxdata1
      rxdata2            : in  std_logic_vector(7 downto 0)   := (others => '0'); --                   .rxdata2
      rxdata3            : in  std_logic_vector(7 downto 0)   := (others => '0'); --                   .rxdata3
      rxdatak0           : in  std_logic                      := '0';             --                   .rxdatak0
      rxdatak1           : in  std_logic                      := '0';             --                   .rxdatak1
      rxdatak2           : in  std_logic                      := '0';             --                   .rxdatak2
      rxdatak3           : in  std_logic                      := '0';             --                   .rxdatak3
      rxelecidle0        : in  std_logic                      := '0';             --                   .rxelecidle0
      rxelecidle1        : in  std_logic                      := '0';             --                   .rxelecidle1
      rxelecidle2        : in  std_logic                      := '0';             --                   .rxelecidle2
      rxelecidle3        : in  std_logic                      := '0';             --                   .rxelecidle3
      rxstatus0          : in  std_logic_vector(2 downto 0)   := (others => '0'); --                   .rxstatus0
      rxstatus1          : in  std_logic_vector(2 downto 0)   := (others => '0'); --                   .rxstatus1
      rxstatus2          : in  std_logic_vector(2 downto 0)   := (others => '0'); --                   .rxstatus2
      rxstatus3          : in  std_logic_vector(2 downto 0)   := (others => '0'); --                   .rxstatus3
      rxvalid0           : in  std_logic                      := '0';             --                   .rxvalid0
      rxvalid1           : in  std_logic                      := '0';             --                   .rxvalid1
      rxvalid2           : in  std_logic                      := '0';             --                   .rxvalid2
      rxvalid3           : in  std_logic                      := '0';             --                   .rxvalid3
      reset_status       : out std_logic;                                         --            hip_rst.reset_status
      serdes_pll_locked  : out std_logic;                                         --                   .serdes_pll_locked
      pld_clk_inuse      : out std_logic;                                         --                   .pld_clk_inuse
      pld_core_ready     : in  std_logic                      := '0';             --                   .pld_core_ready
      testin_zero        : out std_logic;                                         --                   .testin_zero
      lmi_addr           : in  std_logic_vector(11 downto 0)  := (others => '0'); --                lmi.lmi_addr
      lmi_din            : in  std_logic_vector(31 downto 0)  := (others => '0'); --                   .lmi_din
      lmi_rden           : in  std_logic                      := '0';             --                   .lmi_rden
      lmi_wren           : in  std_logic                      := '0';             --                   .lmi_wren
      lmi_ack            : out std_logic;                                         --                   .lmi_ack
      lmi_dout           : out std_logic_vector(31 downto 0);                     --                   .lmi_dout
      pm_auxpwr          : in  std_logic                      := '0';             --         power_mngt.pm_auxpwr
      pm_data            : in  std_logic_vector(9 downto 0)   := (others => '0'); --                   .pm_data
      pme_to_cr          : in  std_logic                      := '0';             --                   .pme_to_cr
      pm_event           : in  std_logic                      := '0';             --                   .pm_event
      pme_to_sr          : out std_logic;                                         --                   .pme_to_sr
      reconfig_to_xcvr   : in  std_logic_vector(349 downto 0) := (others => '0'); --   reconfig_to_xcvr.reconfig_to_xcvr
      reconfig_from_xcvr : out std_logic_vector(229 downto 0);                    -- reconfig_from_xcvr.reconfig_from_xcvr
      app_msi_num        : in  std_logic_vector(4 downto 0)   := (others => '0'); --            int_msi.app_msi_num
      app_msi_req        : in  std_logic                      := '0';             --                   .app_msi_req
      app_msi_tc         : in  std_logic_vector(2 downto 0)   := (others => '0'); --                   .app_msi_tc
      app_msi_ack        : out std_logic;                                         --                   .app_msi_ack
      app_int_sts_vec    : in  std_logic                      := '0';             --                   .app_int_sts
      tl_hpg_ctrl_er     : in  std_logic_vector(4 downto 0)   := (others => '0'); --          config_tl.hpg_ctrler
      tl_cfg_ctl         : out std_logic_vector(31 downto 0);                     --                   .tl_cfg_ctl
      cpl_err            : in  std_logic_vector(6 downto 0)   := (others => '0'); --                   .cpl_err
      tl_cfg_add         : out std_logic_vector(3 downto 0);                      --                   .tl_cfg_add
      tl_cfg_sts         : out std_logic_vector(52 downto 0);                     --                   .tl_cfg_sts
      cpl_pending        : in  std_logic_vector(0 downto 0)   := (others => '0'); --                   .cpl_pending
      tl_cfg_ctl_wr      : out std_logic;                                         --                   .tl_cfg_ctl_wr
      tl_cfg_sts_wr      : out std_logic;                                         --                   .tl_cfg_sts_wr
      derr_cor_ext_rcv0  : out std_logic;                                         --         hip_status.derr_cor_ext_rcv
      derr_cor_ext_rpl   : out std_logic;                                         --                   .derr_cor_ext_rpl
      derr_rpl           : out std_logic;                                         --                   .derr_rpl
      dlup_exit          : out std_logic;                                         --                   .dlup_exit
      dl_ltssm           : out std_logic_vector(4 downto 0);                      --                   .ltssmstate
      ev128ns            : out std_logic;                                         --                   .ev128ns
      ev1us              : out std_logic;                                         --                   .ev1us
      hotrst_exit        : out std_logic;                                         --                   .hotrst_exit
      int_status         : out std_logic_vector(3 downto 0);                      --                   .int_status
      l2_exit            : out std_logic;                                         --                   .l2_exit
      lane_act           : out std_logic_vector(3 downto 0);                      --                   .lane_act
      ko_cpl_spc_header  : out std_logic_vector(7 downto 0);                      --                   .ko_cpl_spc_header
      ko_cpl_spc_data    : out std_logic_vector(11 downto 0);                     --                   .ko_cpl_spc_data
      dl_current_speed   : out std_logic_vector(1 downto 0));                     --   hip_currentspeed.currentspeed
  end component arria5_pcie_hip;

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

  signal core_clk, core_clk_out, pll_locked : std_logic;
  signal rstn : std_logic;
  
  signal reconfig_clk     : std_logic;
  signal reconfig_busy    : std_logic;
  signal reconfig_fromgxb : std_logic_vector(16 downto 0);
  signal reconfig_togxb   : std_logic_vector(3 downto 0);
  signal reconfig_to_xcvr : std_logic_vector(349 downto 0);
  signal xcvr_to_reconfig : std_logic_vector(229 downto 0);
  
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
  
  signal tx_st_sop0, tx_st_eop0, tx_st_ready0, tx_st_valid0 : std_logic;
  signal tx_st_data0 : std_logic_vector(63 downto 0);
  
  signal tx_ready_delay : std_logic_vector(1 downto 0); -- length must equal the latency of the Avalon TX bus
  signal tx_eop, tx_sop : std_logic := '1';
  -- Invariant idxr <= idxe <= idxw <= idxa, extra bit is for wrap-around
  signal tx_idxr, tx_idxe, tx_idxw, tx_idxa, tx_idxw_p1, tx_idxr_next : unsigned(buf_bits downto 0);
  
begin

  reconfig_clk <= cal_clk50_i;
  wb_clk_o <= core_clk_out;
  
  arria2 : if (g_family = "Arria II") generate
    reconf : arria2_pcie_reconf
      port map(
        reconfig_clk     => reconfig_clk,
        reconfig_fromgxb => reconfig_fromgxb,
        busy             => reconfig_busy,
        reconfig_togxb   => reconfig_togxb);
     
    hip : arria2_pcie_hip
      port map(
        -- Clocking
        refclk               => pcie_refclk_i,
        pld_clk              => core_clk_out,
        core_clk_out         => core_clk,
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
        
        -- WTF? Not documented
        rc_rx_digitalreset   => open);
  end generate;
  
  arria5 : if (g_family = "Arria V") generate
    reconf : arria5_pcie_reconf
      port map(
        reconfig_busy             => open,
        mgmt_clk_clk              => reconfig_clk,
        mgmt_rst_reset            => '0',
        reconfig_mgmt_address     => (others => '0'),
        reconfig_mgmt_read        => '0',
        reconfig_mgmt_readdata    => open,
        reconfig_mgmt_waitrequest => open,
        reconfig_mgmt_write       => '0',
        reconfig_mgmt_writedata   => (others => '0'),
        reconfig_to_xcvr          => reconfig_to_xcvr,
        reconfig_from_xcvr        => xcvr_to_reconfig);
    
    hip : arria5_pcie_hip
      port map(
        -- Clocking
        refclk             => pcie_refclk_i,
        pld_clk            => core_clk_out,
        coreclkout         => core_clk,
        pld_clk_inuse      => open,
        pld_core_ready     => pll_locked,
        
        -- PCIe PHY pins
        rx_in0             => pcie_rx_i(0),
        rx_in1             => pcie_rx_i(1),
        rx_in2             => pcie_rx_i(2),
        rx_in3             => pcie_rx_i(3),
        tx_out0            => pcie_tx_o(0),
        tx_out1            => pcie_tx_o(1),
        tx_out2            => pcie_tx_o(2),
        tx_out3            => pcie_tx_o(3),
        
        -- Avalon RX
        rx_st_mask         => '0',
        rx_st_ready        => rx_st_ready0,
        rx_st_bar          => rx_st_bardec0,
        rx_st_be           => open,
        rx_st_data         => rx_st_data0,
        rx_st_sop          => open,
        rx_st_eop          => open,
        rx_st_err          => open,
        rx_st_valid        => rx_st_valid0,
        -- Errors in RX buffer
        derr_cor_ext_rcv0  => open,
        derr_cor_ext_rpl   => open,
        derr_rpl           => open,
        
        -- Avalon TX
        tx_st_data         => tx_st_data0,
        tx_st_eop          => tx_st_eop0,
        tx_st_err          => '0',
        tx_st_sop          => tx_st_sop0,
        tx_st_valid        => tx_st_valid0,
        tx_st_ready        => tx_st_ready0,
        tx_fifo_empty      => open,
        -- Avalon TX credit management
        tx_cred_datafccp   => open,
        tx_cred_datafcnp   => open,
        tx_cred_datafcp    => open,
        tx_cred_fchipcons  => open,
        tx_cred_fcinfinite => open,
        tx_cred_hdrfccp    => open,
        tx_cred_hdrfcnp    => open,
        tx_cred_hdrfcp     => open,
        
        -- Report completion error status
        cpl_err            => (others => '0'),
        cpl_pending        => (others => '0'),
        lmi_addr           => (others => '0'),
        lmi_din            => (others => '0'),
        lmi_rden           => '0',
        lmi_wren           => '0',
        lmi_ack            => open,
        lmi_dout           => open,
        ko_cpl_spc_header  => open,
        ko_cpl_spc_data    => open,
        
        -- PCIe interrupts (for endpoints)
        app_int_sts_vec    => app_int_sts,
        app_msi_num        => (others => '0'),
        app_msi_req        => app_msi_req,
        app_msi_tc         => (others => '0'),
        app_msi_ack        => open,
        int_status         => open, -- only for root ports
        
        -- PCIe configuration space
        tl_hpg_ctrl_er     => (others => '0'),
        tl_cfg_add         => tl_cfg_add,
        tl_cfg_ctl         => tl_cfg_ctl,
        tl_cfg_ctl_wr      => open,
        tl_cfg_sts         => open,
        tl_cfg_sts_wr      => open,
        
        -- Power management signals
        pm_auxpwr          => '0',
        pm_data            => (others => '0'),
        pm_event           => '0',
        pme_to_cr          => pme_shift(pme_shift'length-1),
        pme_to_sr          => pme_shift(0),
        
        -- Reset and link training
        npor               => npor,
        pin_perst          => pcie_rstn_i,
        l2_exit            => l2_exit,
        hotrst_exit        => hotrst_exit,
        dlup_exit          => dlup_exit,
        dl_ltssm           => open,
        serdes_pll_locked  => pll_locked,
        reset_status       => open,
        ev128ns            => open,
        ev1us              => open,
        
        -- Debug signals
        test_in            => (others => '0'),
        testin_zero        => open,
        lane_act           => open,
        dl_current_speed   => open,

        -- External PHY (PIPE). Not used; using altera PHY.
        rxdata0            => (others => '0'),
        rxdata1            => (others => '0'),
        rxdata2            => (others => '0'),
        rxdata3            => (others => '0'),
        rxdatak0           => '0',
        rxdatak1           => '0',
        rxdatak2           => '0',
        rxdatak3           => '0',
        rxelecidle0        => '0',
        rxelecidle1        => '0',
        rxelecidle2        => '0',
        rxelecidle3        => '0',
        rxstatus0          => (others => '0'),
        rxstatus1          => (others => '0'),
        rxstatus2          => (others => '0'),
        rxstatus3          => (others => '0'),
        rxvalid0           => '0',
        rxvalid1           => '0',
        rxvalid2           => '0',
        rxvalid3           => '0',
        rxpolarity0        => open,
        rxpolarity1        => open,
        rxpolarity2        => open,
        rxpolarity3        => open,
        txcompl0           => open,
        txcompl1           => open,
        txcompl2           => open,
        txcompl3           => open,
        txdata0            => open,
        txdata1            => open,
        txdata2            => open,
        txdata3            => open,
        txdatak0           => open,
        txdatak1           => open,
        txdatak2           => open,
        txdatak3           => open,
        txdetectrx0        => open,
        txdetectrx1        => open,
        txdetectrx2        => open,
        txdetectrx3        => open,
        txelecidle0        => open,
        txelecidle1        => open,
        txelecidle2        => open,
        txelecidle3        => open,
        txdeemph0          => open,
        txdeemph1          => open,
        txdeemph2          => open,
        txdeemph3          => open,
        txswing0           => open,
        txswing1           => open,
        txswing2           => open,
        txswing3           => open,
        txmargin0          => open,
        txmargin1          => open,
        txmargin2          => open,
        txmargin3          => open,
        powerdown0         => open,
        powerdown1         => open,
        powerdown2         => open,
        powerdown3         => open,
        phystatus0         => '0',
        phystatus1         => '0',
        phystatus2         => '0',
        phystatus3         => '0',
        eidleinfersel0     => open,
        eidleinfersel1     => open,
        eidleinfersel2     => open,
        eidleinfersel3     => open,
        -- Simulation PIPE signals
        sim_pipe_pclk_in   => '0',
        simu_mode_pipe     => '0',
        sim_pipe_rate      => open,
        sim_ltssmstate     => open,
        
        reconfig_to_xcvr   => reconfig_to_xcvr,
        reconfig_from_xcvr => xcvr_to_reconfig);
  end generate;
  
  coreclk : single_region
    port map(
      inclk  => core_clk,
      outclk => core_clk_out);
  
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
  
  queue : generic_simple_dpram
    generic map(
      g_data_width               => 65,
      g_size                     => buf_length,
      g_addr_conflict_resolution => "dont_care",
      g_dual_clock               => false)
    port map(
      clka_i            => core_clk_out,
      wea_i             => '1',
      aa_i              => std_logic_vector(tx_idxw(buf_bits-1 downto 0)),
      da_i(64)          => tx_eop_i,
      da_i(63 downto 0) => tx_wb_dat_i,
      clkb_i            => core_clk_out,
      ab_i              => std_logic_vector(tx_idxr_next(buf_bits-1 downto 0)),
      qb_o(64)          => tx_eop,
      qb_o(63 downto 0) => tx_st_data0);
  
  -- Dump TX out from a FIFO
  tx_st_eop0  <= tx_eop;
  tx_st_sop0  <= tx_sop;
  
  tx_st_valid0 <= active_high(tx_idxr /= tx_idxe) and tx_ready_delay(tx_ready_delay'length-1);
  
  tx_idxr_next <= (tx_idxr+1) when tx_st_valid0='1' else tx_idxr;
  
  tx_dequeue : process(core_clk_out)
  begin
    if rising_edge(core_clk_out) then
      if rstn = '0' then
        tx_ready_delay <= (others => '0');
        tx_idxr <= (others => '0');
        tx_sop <= '1';
      else
        tx_ready_delay <= tx_ready_delay(tx_ready_delay'length-2 downto 0) & tx_st_ready0;
        tx_idxr <= tx_idxr_next;
        if tx_st_valid0 = '1' then
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
        if tx_wb_stb_i = '1' then
          tx_idxw <= tx_idxw_p1;
        end if;
        
        if (tx_wb_stb_i and tx_eop_i) = '1' then
          tx_idxe <= tx_idxw_p1;
        end if;
        
        if tx_alloc_i = '1' then
          tx_idxa <= tx_idxa + 1;
        end if;
      end if;
    end if;
  end process;
end rtl;
