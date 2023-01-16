-------------------------------------------------------------------------------
-- SPDX-FileCopyrightText: 2023 CERN (home.cern)
--
-- SPDX-License-Identifier: CERN-OHL-W-2.0+
-------------------------------------------------------------------------------
-- Title      : Testbench for AXI4Lite to AXI4Full bridge
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : tb_axi4lite_axi4full_bridge.vhd
-- Company    : CERN (BE-CEM-EDL)
-- Author     : Konstantinos Blantos <konstantinos.blantos@cern.ch>
-- Platform   : FPGA-generics
-- Standard   : VHDL '08
-------------------------------------------------------------------------------

--=============================================================================
--                            Libraries & Packages                           --
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- OSVVM library
library osvvm;
use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;

--=============================================================================
--                Entity declaration for tb_axi4lite_axi4full_bridge         --
--=============================================================================

entity tb_axi4lite_axi4full_bridge is
  generic (
    g_seed       : natural;
    g_sim_time   : natural;
    g_ADDR_WIDTH : natural := 32;
    g_DATA_WIDTH : natural := 32;
    g_ID_WIDTH   : natural := 4;
    g_LEN_WIDTH  : natural := 8
  );
end entity tb_axi4lite_axi4full_bridge;

--==============================================================================
--                           Architecture declaration                         --
--==============================================================================

architecture tb of tb_axi4lite_axi4full_bridge is

  --==========================================================
  -- Constants
  --==========================================================

  constant C_CLK_PERIOD : time := 10 ns;
  constant C_SIM_TIME   : time := (g_sim_time*1.0 ms);
  -- Used for FSM coverage
  constant RSP_OKAY     : std_logic_vector(1 downto 0) := b"00";
  constant RSP_EXOKAY   : std_logic_vector(1 downto 0) := b"01";
  constant RSP_SLVERR   : std_logic_vector(1 downto 0) := b"10";
  constant RSP_DECERR   : std_logic_vector(1 downto 0) := b"11";

  --==========================================================
  -- Signals
  --==========================================================

  signal tb_clk_i     : std_logic;
  signal tb_rst_n_i   : std_logic;
  --  AXI4-Full slave
  signal tb_s_awaddr  : std_logic_vector (g_ADDR_WIDTH-1 downto 0);
  signal tb_s_awlen   : std_logic_vector (g_LEN_WIDTH-1 downto 0);
  signal tb_s_awsize  : std_logic_vector (2 downto 0);
  signal tb_s_awburst : std_logic_vector (1 downto 0);
  signal tb_s_awid    : std_logic_vector (g_ID_WIDTH-1 downto 0);
  signal tb_s_awvalid : std_logic;
  signal tb_s_awready : std_logic;

  signal tb_s_wdata   : std_logic_vector (g_DATA_WIDTH-1 downto 0);
  signal tb_s_wstrb   : std_logic_vector ((g_DATA_WIDTH/8)-1 downto 0);
  signal tb_s_wid     : std_logic_vector (g_ID_WIDTH-1 downto 0);
  signal tb_s_wlast   : std_logic;
  signal tb_s_wvalid  : std_logic;
  signal tb_s_wready  : std_logic;

  signal tb_s_bid     : std_logic_vector (g_ID_WIDTH-1 downto 0);
  signal tb_s_bresp   : std_logic_vector (1 downto 0);
  signal tb_s_bvalid  : std_logic;
  signal tb_s_bready  : std_logic;

  signal tb_s_araddr  : std_logic_vector (g_ADDR_WIDTH-1 downto 0);
  signal tb_s_arlen   : std_logic_vector (g_LEN_WIDTH-1 downto 0);
  signal tb_s_arsize  : std_logic_vector (2 downto 0);
  signal tb_s_arburst : std_logic_vector (1 downto 0);
  signal tb_s_arid    : std_logic_vector (g_ID_WIDTH-1 downto 0);
  signal tb_s_arvalid : std_logic;
  signal tb_s_arready : std_logic;

  signal tb_s_rdata   : std_logic_vector (g_DATA_WIDTH-1 downto 0);
  signal tb_s_rid     : std_logic_vector (g_ID_WIDTH-1 downto 0);
  signal tb_s_rresp   : std_logic_vector (1 downto 0);
  signal tb_s_rlast   : std_logic;
  signal tb_s_rvalid  : std_logic;
  signal tb_s_rready  : std_logic;

  --  AXI4-Lite master
  signal tb_m_awaddr  : std_logic_vector (g_ADDR_WIDTH-1 downto 0);
  signal tb_m_awvalid : std_logic;
  signal tb_m_awready : std_logic;

  signal tb_m_wdata   : std_logic_vector (g_DATA_WIDTH-1 downto 0);
  signal tb_m_wstrb   : std_logic_vector ((g_DATA_WIDTH/8)-1 downto 0);
  signal tb_m_wvalid  : std_logic;
  signal tb_m_wready  : std_logic;

  signal tb_m_bresp   : std_logic_vector (1 downto 0);
  signal tb_m_bvalid  : std_logic;
  signal tb_m_bready  : std_logic;

  signal tb_m_araddr  : std_logic_vector (g_ADDR_WIDTH-1 downto 0);
  signal tb_m_arvalid : std_logic;
  signal tb_m_arready : std_logic;

  signal tb_m_rdata   : std_logic_vector (g_DATA_WIDTH-1 downto 0);
  signal tb_m_rresp   : std_logic_vector (1 downto 0);
  signal tb_m_rvalid  : std_logic;
  signal tb_m_rready  : std_logic;

  signal stop        : boolean;
  signal waddr       : std_logic_vector(g_ADDR_WIDTH-1 downto 0) := (others=>'0');
  signal s_wlen      : std_logic_vector(g_LEN_WIDTH-1 downto 0)  := (others=>'0');
  signal s_wsize     : std_logic_vector(2 downto 0) ;
  signal s_raddr     : std_logic_vector(g_ADDR_WIDTH-1 downto 0) := (others=>'0');
  signal s_rlen      : std_logic_vector(g_LEN_WIDTH-1 downto 0)  := (others=>'0');
  signal s_rsize     : std_logic_vector(2 downto 0);
  signal s_rdata     : std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others=>'0');
  signal s_awvalid   : std_logic;
  signal s_wvalid    : std_logic;
  signal s_wstrb     : std_logic_vector((g_DATA_WIDTH/8)-1 downto 0);
  signal s_arvalid   : std_logic;
  signal s_rready    : std_logic;
  signal s_bready    : std_logic;
  signal m_bvalid    : std_logic;
  signal s_wid       : std_logic_vector(g_ID_WIDTH-1 downto 0);
  signal wdata       : std_logic_vector(g_ADDR_WIDTH-1 downto 0);
  signal tmp_awaddr  : std_logic_vector(g_ADDR_WIDTH-1 downto 0) := (others=>'0');
  signal tmp_araddr  : std_logic_vector(g_ADDR_WIDTH-1 downto 0) := (others=>'0');
  signal tmp_wdata   : std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others=>'0');
  signal tmp_rdata   : std_logic_vector(g_DATA_WIDTH-1 downto 0) := (others=>'0');

  type t_wr_state is (WR_IDLE,
                      WR_MASTER, WR_SLAVE, WR_SLAVE2, WR_WAIT, WR_DONE);
  type t_rd_state is (RD_IDLE, RD_READ, RD_SLAVE);

  signal s_wstate : t_wr_state;
  signal s_rstate : t_rd_state;

  shared variable sv_cover_wr : covPType;
  shared variable sv_cover_rd : covPType;

  --==========================================================
  -- Procedures used for FSM coverage
  --==========================================================

  -- legal states for Write FSM
  procedure fsm_covadd_states_wr (
    name  : in string;
    prev  : in t_wr_state;
    curr  : in t_wr_state;
    covdb : inout covPType) is
  begin
     covdb.AddCross ( name,
                      GenBin(t_wr_state'pos(prev)),
                      GenBin(t_wr_state'pos(curr)));
  end procedure;

  -- legal states for Read FSM
  procedure fsm_covadd_states_rd (
    name  : in string;
    prev  : in t_rd_state;
    curr  : in t_rd_state;
    covdb : inout covPType) is
  begin
     covdb.AddCross ( name,
                      GenBin(t_rd_state'pos(prev)),
                      GenBin(t_rd_state'pos(curr)));
  end procedure;

  -- illegal states
  procedure fsm_covadd_illegal (
    name  : in string;
    covdb : inout covPType ) is
  begin
    covdb.AddCross(ALL_ILLEGAL,ALL_ILLEGAL);
  end procedure;

  -- bin collection for Write FSM
  procedure fsm_covcollect_wr (
    signal reset : in std_logic;
    signal clk   : in std_logic;
    signal state : in t_wr_state;
    covdb : inout covPType) is
    variable v_state : t_wr_state := t_wr_state'left;
  begin
    wait until reset='1';
    loop
      v_state := state;
      wait until rising_edge(clk);
      covdb.ICover((t_wr_state'pos(v_state), t_wr_state'pos(state)));
    end loop;
  end procedure;

  -- bin collection for Read FSM
  procedure fsm_covcollect_rd (
    signal reset : in std_logic;
    signal clk   : in std_logic;
    signal state : in t_rd_state;
    covdb : inout covPType) is
    variable v_state : t_rd_state := t_rd_state'left;
  begin
    wait until reset='1';
    loop
      v_state := state;
      wait until rising_edge(clk);
      covdb.ICover((t_rd_state'pos(v_state), t_rd_state'pos(state)));
    end loop;
  end procedure;

begin

  -- Unit Under Test
  UUT : entity work.axi4lite_axi4full_bridge
  port map (
    clk_i     => tb_clk_i,
    rst_n_i   => tb_rst_n_i,
    s_awaddr  => tb_s_awaddr,
    s_awlen   => tb_s_awlen,
    s_awsize  => tb_s_awsize,
    s_awburst => tb_s_awburst,
    s_awid    => tb_s_awid,
    s_awvalid => tb_s_awvalid,
    s_awready => tb_s_awready,
    s_wdata   => tb_s_wdata,
    s_wstrb   => tb_s_wstrb,
    s_wid     => tb_s_wid,
    s_wlast   => tb_s_wlast,
    s_wvalid  => tb_s_wvalid,
    s_wready  => tb_s_wready,
    s_bid     => tb_s_bid,
    s_bresp   => tb_s_bresp,
    s_bvalid  => tb_s_bvalid,
    s_bready  => tb_s_bready,
    s_araddr  => tb_s_araddr,
    s_arlen   => tb_s_arlen,
    s_arsize  => tb_s_arsize,
    s_arburst => tb_s_arburst,
    s_arid    => tb_s_arid,
    s_arvalid => tb_s_arvalid,
    s_arready => tb_s_arready,
    s_rdata   => tb_s_rdata,
    s_rid     => tb_s_rid,
    s_rresp   => tb_s_rresp,
    s_rlast   => tb_s_rlast,
    s_rvalid  => tb_s_rvalid,
    s_rready  => tb_s_rready,
    m_awaddr  => tb_m_awaddr,
    m_awvalid => tb_m_awvalid,
    m_awready => tb_m_awready,
    m_wdata   => tb_m_wdata,
    m_wstrb   => tb_m_wstrb,
    m_wvalid  => tb_m_wvalid,
    m_wready  => tb_m_wready,
    m_bresp   => tb_m_bresp,
    m_bvalid  => tb_m_bvalid,
    m_bready  => tb_m_bready,
    m_araddr  => tb_m_araddr,
    m_arvalid => tb_m_arvalid,
    m_arready => tb_m_arready,
    m_rdata   => tb_m_rdata,
    m_rresp   => tb_m_rresp,
    m_rvalid  => tb_m_rvalid,
    m_rready  => tb_m_rready);

  -- Clock generation
  p_clk_gen : process
  begin
    while not stop loop
      tb_clk_i <= '1';
      wait for C_CLK_PERIOD/2;
      tb_clk_i <= '0';
      wait for C_CLK_PERIOD/2;
    end loop;
    wait;
  end process p_clk_gen;

  -- Reset generation
  tb_rst_n_i <= '0', '1' after 2*C_CLK_PERIOD;

  -- Stimulus
  stim : process
    variable data    : RandomPType;
    variable ncycles : natural;
  begin
    data.InitSeed(g_seed);
    report "[STARTING] with seed = " & to_string(g_seed);
    wait until tb_rst_n_i = '1';
    while (NOW < C_SIM_TIME) loop
      wait until rising_edge(tb_clk_i);
      -- AXI-4 Full inputs
      tb_s_awaddr  <= data.randSlv(g_ADDR_WIDTH);
      tb_s_awlen   <= data.randSlv(0,4,8) when s_wstate=WR_IDLE else (others=>'0');
      s_awvalid    <= data.randSlv(1)(1);
      tb_s_wdata   <= data.randSlv(g_DATA_WIDTH);
      s_wvalid     <= data.randSlv(1)(1);
      s_bready     <= data.randSlv(1)(1);
      tb_s_araddr  <= data.randSlv(g_ADDR_WIDTH);
      tb_s_arlen   <= data.randSlv(0,4,8) when s_rstate=RD_IDLE;
      s_arvalid    <= data.randSlv(1)(1);
      s_rready     <= data.randSlv(1)(1);
      -- AXI-4 Lite inputs
      m_bvalid     <= data.randSlv(1)(1);
      tb_m_rdata   <= data.randSlv(g_ADDR_WIDTH);
      ncycles      := ncycles + 1;
    end loop;
    report "Number of simulation cycles = " & to_string(ncycles);
    stop <= TRUE;
    report "Test PASS!";
    wait;
  end process stim;

  -- Based on AMBA AXI4 specification (A3.4)
  -- depending on the data width, axSize can differ
  g_axSize_gen : if g_DATA_WIDTH > 0 generate
    process
    begin
      case g_DATA_WIDTH is
        when 1 =>
          tb_s_awsize <= "000";
          tb_s_arsize <= "000";
        when 2 =>
          tb_s_awsize <= "001";
          tb_s_arsize <= "001";
        when 4 =>
          tb_s_awsize <= "010";
          tb_s_arsize <= "010";
        when 8 =>
          tb_s_awsize <= "011";
          tb_s_arsize <= "011";
        when 16 =>
          tb_s_awsize <= "100";
          tb_s_arsize <= "100";
        when 32 =>
          tb_s_awsize <= "101";
          tb_s_arsize <= "101";
        when 64 =>
          tb_s_awsize <= "110";
          tb_s_arsize <= "110";
        when 128 =>
          tb_s_awsize <= "111";
          tb_s_arsize <= "111";
        when others =>
          tb_s_awsize <= "000";
          tb_s_arsize <= "000";
      end case;
      wait;
    end process;
  end generate g_axSize_gen;

  -- Assign to strobe the default value which
  -- means that all byte lanes hold valid data
  tb_s_wstrb <= (others=>'1');

  -- AXBurst logic not included in RTL
  -- The default value chosen for INCR
  tb_s_awburst <= "01";
  tb_s_arburst <= "01";

  -- Transactions ID. Set all to 0
  -- for convenience
  tb_s_awid <= (others=>'0');
  tb_s_wid  <= (others=>'0');
  tb_s_arid <= (others=>'0');

  -- BRESP for Master is always OKAY
  -- just for convenience in testing
  tb_m_bresp <= RSP_OKAY;

  -- Valid/Ready signals generation
  -- both for slave and master
  tb_s_awvalid <= s_awvalid  when s_wstate = WR_IDLE   else '0';
  tb_s_wvalid  <= s_wvalid   when s_wstate = WR_MASTER else '0';
  tb_s_arvalid <= s_arvalid  when s_rstate = RD_IDLE   else '0';
  tb_s_rready  <= s_rready   when s_rstate = RD_SLAVE  else '0';
  tb_s_bready  <= s_bready   when s_wstate = WR_DONE   else '0';
  tb_m_bvalid  <= m_bvalid   when s_wstate = WR_WAIT   else '0';

  -- Write side, signal assignments
  tb_m_awaddr <= waddr;
  tb_m_wdata  <= wdata;
  tb_m_wstrb  <= s_wstrb;
  tb_s_bid    <= s_wid;

  -- Read side, signal assignments
  tb_m_araddr <= s_raddr;
  tb_s_rdata  <= s_rdata;

  -- Wlast generation
  tb_s_wlast <= '1' when (unsigned(s_wlen)=0 and tb_s_wvalid = '1') else '0';

  -- AWREADY generation
  -- awready is asserted for one clock cycle when both
  -- awvalid and wvalid are asserted. awready is
  -- de-asserted when reset is low.
  process (tb_clk_i)
  begin
    if rising_edge(tb_clk_i) then
      if tb_rst_n_i = '0' then
        tb_m_awready <= '0';
      else
        if tb_m_awready = '0' and tb_m_awvalid = '1' and tb_m_wvalid = '1' then
          -- slave is ready to accept write address when
          -- there is a valid write address and write data
          -- on the write address and data bus.
          tb_m_awready <= '1';
        else
          tb_m_awready <= '0';
        end if;
      end if;
    end if;
  end process;

  -- WREADY generation
  -- wready is asserted for one clock cycle when both
  -- awvalid and wvalid are asserted. wready is
  -- de-asserted when reset is low.
  process (tb_clk_i)
  begin
    if rising_edge(tb_clk_i) then
      if tb_rst_n_i = '0' then
        tb_m_wready <= '0';
      else
        if tb_m_wready = '0' and tb_m_wvalid = '1' and tb_m_awvalid = '1' then
          -- slave is ready to accept write data when
          -- there is a valid write address and write data
          -- on the write address and data bus.
          tb_m_wready <= '1';
        else
          tb_m_wready <= '0';
        end if;
      end if;
    end if;
  end process;

  -- RVALID generation
  process (tb_clk_i)
  begin
    if rising_edge(tb_clk_i) then
      if tb_rst_n_i = '0' then
        tb_m_rvalid <= '0';
        tb_m_rresp  <= "00";
      else
        if tb_m_arready = '1' and tb_m_arvalid = '1' and tb_m_rvalid = '0' then
          -- Valid read data is available at the read data bus
          tb_m_rvalid <= '1';
          tb_m_rresp  <= "00"; -- 'OKAY' response
        elsif tb_m_rvalid = '1' and tb_m_rready = '1' then
          tb_m_rvalid <= '0';
          tb_m_rresp  <= (others=>'X');
        end if;
      end if;
    end if;
  end process;

  -- ARREADY generation
  process (tb_clk_i)
  begin
    if rising_edge(tb_clk_i) then
      if tb_rst_n_i = '0' then
        tb_m_arready <= '0';
      else
        if tb_m_arready = '0' and tb_m_arvalid = '1' then
          -- indicates that the slave has acceped the valid read address
          tb_m_arready <= '1';
        else
          tb_m_arready <= '0';
        end if;
      end if;
    end if;
  end process;

  --==============================================================================
  --                              Coverage                                      --
  --==============================================================================

  -- **********************
  -- **FSM for Write Part**
  -- **********************
  p_wr_fsm : process (tb_clk_i)
  begin
    if rising_edge (tb_clk_i) then
      if tb_rst_n_i = '0' then
        s_wstate     <= WR_IDLE;
        tb_s_awready <= '1';
        tb_s_bvalid  <= '0';
        tb_m_awvalid <= '0';
        tb_m_wvalid  <= '0';
        tb_m_bready  <= '0';
      else
        case s_wstate is
          when WR_IDLE =>
            --  Wait until awvalid is ready.
            if tb_s_awvalid = '1' then
              --  Save transaction parameters
              waddr   <= tb_s_awaddr;
              s_wlen  <= tb_s_awlen;
              s_wsize <= tb_s_awsize;
              s_wid   <= tb_s_awid;

              --  Not anymore ready for addresses.
              tb_s_awready <= '0';
              --  But ready for data.

              s_wstate <= WR_MASTER;
            end if;

          when WR_MASTER =>
            --  Clear wvalid when coming from WR_SLAVE.
            tb_m_wvalid <= '0';

            if tb_s_wvalid = '1' then
              --  Got data from master.
              wdata     <= tb_s_wdata;
              s_wstrb   <= tb_s_wstrb;
              --  Address cycle.
              tb_m_awvalid <= '1';
              s_wstate    <= WR_SLAVE;
            end if;

          when WR_SLAVE =>
            if tb_m_awready = '1' then
              --  Wait for address ack.
              tb_m_awvalid <= '0';
            end if;

            --  Prepare data write cycle.
            tb_m_wvalid <= '1';
            s_wstate <= WR_SLAVE2;

          when WR_SLAVE2 =>
            if tb_m_awready = '1' then
              --  Wait for address ack.
              tb_m_awvalid <= '0';
            end if;

            if tb_m_wready = '1' then
              --  Data ack.
              tb_m_wvalid <= '0';
              tb_m_bready <= '1';
              s_wstate    <= WR_WAIT;
            end if;

          when WR_WAIT =>
            --  End of transfer ?
            if tb_m_bvalid = '1' then
              tb_m_bready <= '0';

              if s_wlen = (g_LEN_WIDTH - 1 downto 0 => '0') then
                --  End of the burst.
                tb_s_bresp  <= RSP_OKAY;
                tb_s_bvalid <= '1';
                s_wstate    <= WR_DONE;
              else
                s_wlen      <= std_logic_vector(unsigned(s_wlen) - 1);
                s_wstate    <= WR_MASTER;
              end if;
            end if;

          when WR_DONE =>
            if tb_s_bready = '1' then
              tb_s_bvalid  <= '0';
              tb_s_awready <= '1';
              s_wstate     <= WR_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process p_wr_fsm;

  -- Legal, illegal states and coverage
  -- report for write side FSM
  process
  begin
    -- all possible legal state changes
    fsm_covadd_states_wr("WR_IDLE   -> WR_MASTER",WR_IDLE  ,WR_MASTER,sv_cover_wr);
    fsm_covadd_states_wr("WR_MASTER -> WR_SLAVE ",WR_MASTER,WR_SLAVE ,sv_cover_wr);
    fsm_covadd_states_wr("WR_SLAVE  -> WR_SLAVE2",WR_SLAVE ,WR_SLAVE2,sv_cover_wr);
    fsm_covadd_states_wr("WR_SLAVE2 -> WR_WAIT  ",WR_SLAVE2,WR_WAIT  ,sv_cover_wr);
    fsm_covadd_states_wr("WR_WAIT   -> WR_DONE  ",WR_WAIT  ,WR_DONE  ,sv_cover_wr);
    fsm_covadd_states_wr("WR_WAIT   -> WR_MASTER",WR_WAIT  ,WR_MASTER,sv_cover_wr);
    fsm_covadd_states_wr("WR_DONE   -> WR_IDLE  ",WR_DONE  ,WR_IDLE  ,sv_cover_wr);
    -- when current and next state is the same
    fsm_covadd_states_wr("WR_IDLE   -> WR_IDLE  ",WR_IDLE  ,WR_IDLE  ,sv_cover_wr);
    fsm_covadd_states_wr("WR_MASTER -> WR_MASTER",WR_MASTER,WR_MASTER,sv_cover_wr);
    fsm_covadd_states_wr("WR_WAIT   -> WR_WAIT  ",WR_WAIT  ,WR_WAIT  ,sv_cover_wr);
    fsm_covadd_states_wr("WR_SLAVE2 -> WR_SLAVE2",WR_SLAVE2,WR_SLAVE2,sv_cover_wr);
    fsm_covadd_states_wr("WR_DONE   -> WR_DONE  ",WR_DONE  ,WR_DONE  ,sv_cover_wr);
    -- illegal states
    fsm_covadd_illegal("ILLEGAL",sv_cover_wr);
    wait;
  end process;

  -- collect the cov bins
  fsm_covcollect_wr(tb_rst_n_i, tb_clk_i, s_wstate, sv_cover_wr);

  -- coverage report
  cov_report_wr : process
  begin
      wait until stop;
      sv_cover_wr.writebin;
      report "Test PASS!";
  end process;

  -- **********************
  -- **FSM for  Read part**
  -- **********************
  p_read_fsm : process (tb_clk_i)
  begin
    if rising_edge (tb_clk_i) then
      if tb_rst_n_i = '0' then
        s_rstate     <= RD_IDLE;
        tb_s_arready <= '1';
        tb_s_rvalid  <= '0';
        tb_m_arvalid <= '0';
        s_raddr      <= (others => 'X');
        s_rdata      <= (others => '0');
      else
        case s_rstate is
          when RD_IDLE =>
            --  Wait until awvalid is ready.
            if tb_s_arvalid = '1' then
              --  Save transaction parameters
              s_raddr  <= tb_s_araddr;
              s_rlen   <= tb_s_arlen;
              s_rsize  <= tb_s_arsize;
              tb_s_rid <= tb_s_arid;

              --  Provide a clean result.
              s_rdata <= (others => '0');

              --  Not anymore ready for addresses.
              tb_s_arready <= '0';

              --  Start transfer on the slave part.
              tb_m_arvalid <= '1';
              s_rstate     <= RD_READ;
            end if;

          when RD_READ =>
            if tb_m_arready = '1' then
              --  Address has been accepted.
              tb_m_arvalid <= '0';
            end if;
            if tb_m_rvalid = '1' then
              --  Read data.  Address must have been acked.
              --  According to A3.4.3 of AXI4 spec, the AXI4 bus is little
              --  endian.
              s_rdata     <= tb_m_rdata;
              s_rstate    <= RD_SLAVE;
              tb_s_rresp  <= RSP_OKAY;
              tb_s_rvalid <= '1';
            end if;

          when RD_SLAVE =>
            if tb_s_rready = '1' then
              tb_s_rvalid <= '0';
              if s_rlen = (g_LEN_WIDTH - 1 downto 0 => '0') then
                --  End of the burst.
                tb_s_arready <= '1';
                s_rstate <= RD_IDLE;
              else
                s_rlen <= std_logic_vector(unsigned(s_rlen) - 1);
                --  New beat.
                tb_m_arvalid <= '1';
                s_rstate <= RD_READ;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

  -- Legal, illegal states and coverage
  -- report for read side FSM
  process
  begin
    -- all possible legal state changes
    fsm_covadd_states_rd("RD_IDLE   -> RD_READ  ",RD_IDLE  ,RD_READ  ,sv_cover_rd);
    fsm_covadd_states_rd("RD_READ   -> RD_SLAVE ",RD_READ  ,RD_SLAVE ,sv_cover_rd);
    fsm_covadd_states_rd("RD_SLAVE  -> RD_READ  ",RD_SLAVE ,RD_READ  ,sv_cover_rd);
    fsm_covadd_states_rd("RD_SLAVE  -> RD_IDLE  ",RD_SLAVE ,RD_IDLE  ,sv_cover_rd);
    -- when current and next state is the same
    fsm_covadd_states_rd("RD_IDLE   -> RD_IDLE  ",RD_IDLE  ,RD_IDLE  ,sv_cover_rd);
    fsm_covadd_states_rd("RD_READ   -> RD_READ  ",RD_READ  ,RD_READ  ,sv_cover_rd);
    fsm_covadd_states_rd("RD_SLAVE  -> RD_SLAVE ",RD_SLAVE ,RD_SLAVE ,sv_cover_rd);
    -- illegal states
    fsm_covadd_illegal("ILLEGAL",sv_cover_rd);
    wait;
  end process;

  -- collect the cov bins
  fsm_covcollect_rd(tb_rst_n_i, tb_clk_i, s_rstate, sv_cover_rd);

  -- coverage report
  cov_report_rd : process
  begin
      wait until stop;
      sv_cover_rd.writebin;
      report "Test PASS!";
  end process;

  --==============================================================================
  --                              Assertions                                    --
  --==============================================================================

  -- Check AXI-4 FULL Slave signals
  p_s_check : process(tb_s_awvalid, tb_s_wvalid,tb_s_bready,tb_s_arvalid,tb_s_rready)
  begin
    if falling_edge(tb_s_awvalid) then
      assert (tb_s_awready = '0')
      report "SLAVE: Wrong AWREADY for AWVALID LOW" severity failure;
    end if;
    if falling_edge(tb_s_wvalid) then
      assert (tb_s_wready = '0')
      report "SLAVE: Wrong WREADY for WVALID LOW" severity failure;
    end if;
    if falling_edge(tb_s_bready) then
      assert (tb_s_bvalid = '0')
      report "SLAVE: Wrong BVALID for BREADY LOW" severity failure;
    end if;
    if falling_edge(tb_s_arvalid) then
      assert (tb_s_arready = '0')
      report "SLAVE: Wrong ARREADY for ARVALID LOW" severity failure;
    end if;
    if falling_edge(tb_s_rready) then
      assert (tb_s_rvalid = '0')
      report "SLAVE: Wrong RVALID for RREADY LOW" severity failure;
    end if;
  end process;


  -- Check AXI-4 LITE Master signals
  p_m_check : process(tb_m_awready,tb_m_wready,tb_m_bvalid,tb_m_arready,tb_m_rvalid)
  begin
    if falling_edge(tb_m_awready) then
      assert (tb_m_awvalid = '0')
      report "MASTER: Wrong AWVALID for AWREADY LOW" severity failure;
    end if;
    if falling_edge(tb_m_wready) then
      assert (tb_m_wvalid = '0')
      report "MASTER: Wrong WVALID for WREADY LOW" severity failure;
    end if;
    if falling_edge(tb_m_bvalid) then
      assert (tb_m_bready = '0')
      report "MASTER: Wrong BREADY for BVALID LOW" severity failure;
    end if;
    if falling_edge(tb_m_arready) then
      assert (tb_m_arvalid = '0')
      report "MASTER: Wrong ARVALID for ARREADY LOW" severity failure;
    end if;
    if falling_edge(tb_m_rvalid) then
      assert (tb_m_rready = '0')
      report "MASTER: Wrong RREADY for RVALID LOW" severity failure;
    end if;
  end process;

  -- Check that master and slave awaddr is the same
  p_awaddr_check : process
  begin
    while not stop loop
      wait until (tb_s_awready = '1' and tb_s_awvalid = '1');
      tmp_awaddr <= tb_s_awaddr;
      wait until (tb_m_awready = '1' and tb_m_awvalid = '1');
      assert (tb_m_awaddr = tmp_awaddr);
    end loop;
    wait;
  end process;

  -- Check that master and slave araddr is the same
  p_araddr_check : process
  begin
    while not stop loop
      wait until (tb_s_arready = '1' and tb_s_arvalid = '1');
      tmp_araddr <= tb_s_araddr;
      wait until (tb_m_arready = '1' and tb_m_arvalid = '1');
      assert (tb_m_araddr = tmp_araddr);
    end loop;
    wait;
  end process;

  -- Check that master and slave wdata is the same
  p_wdata_check : process
  begin
    while not stop loop
      wait until (tb_s_wready = '1' and tb_s_wvalid = '1');
      tmp_wdata <= tb_s_wdata;
      wait until (tb_m_wready = '1' and tb_m_wvalid = '1');
      assert (tb_m_wdata = tmp_wdata);
    end loop;
    wait;
  end process;

  -- Check that master and slave rdata is the same
  p_rdata_check : process
  begin
    while not stop loop
      wait until (tb_m_rready = '1' and tb_m_rvalid = '1');
      tmp_rdata <= tb_m_rdata;
      wait until (tb_s_rready = '1' and tb_s_rvalid = '1');
      assert (tb_s_rdata = tmp_rdata);
    end loop;
    wait;
  end process;


end tb;

