-------------------------------------------------------------------------------
-- Title      : Testbench for WB-to-AXI4Lite bridge
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : tb_xaxi4lite_wb_bridge.vhd
-- Author     : Konstantinos Blantos <Konstantinos.blantos@cern.ch>
-- Company    : CERN (BE-CEM-EDL)
-- Platform   : FPGA-generics
-- Standard   : VHDL '08
-------------------------------------------------------------------------------
-- Description:
--
-- Testbench for a WB Slave Classic to AXI4-Lite Master bridge.
-------------------------------------------------------------------------------
-- Copyright (c) 2019 CERN
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.axi4_pkg.all;
use work.wishbone_pkg.all;

-- OSVVM library
library osvvm;
use osvvm.RandomPkg.all;
use osvvm.CoveragePkg.all;

entity tb_xaxi4lite_wb_bridge is
  generic (
    g_seed     : natural;
    g_sim_time : natural);
end entity;

architecture tb of tb_xaxi4lite_wb_bridge is

  -- Constants
  constant C_CLK_PERIOD : time := 10 ns;
  constant C_SIM_TIME   : time := (g_sim_time*1.0 ms);

  -- Signals
  signal tb_clk_i         : std_logic;
  signal tb_rst_n_i       : std_logic;
  signal tb_wb_slave_i    : t_wishbone_slave_in;
  signal tb_wb_slave_o    : t_wishbone_slave_out;
  signal tb_axi4_master_o : t_axi4_lite_master_out_32;
  signal tb_axi4_master_i : t_axi4_lite_master_in_32;

  signal stop             : boolean;
  signal s_araddr         : std_logic_vector(31 downto 0);
  signal s_wb_data        : std_logic_vector(31 downto 0);

  type t_state is (IDLE, READ, WRITE, WB_END);
  signal s_state : t_state;

  shared variable sv_cover : covPType;

  --------------------------------------------------------------------------------
  -- Procedures used for fsm coverage
  --------------------------------------------------------------------------------

  -- legal states
  procedure fsm_covadd_states (
    name  : in string;
    prev  : in t_state;
    curr  : in t_state;
    covdb : inout covPType) is
  begin
    covdb.AddCross ( name,
                     GenBin(t_state'pos(prev)),
                     GenBin(t_state'pos(curr)));
  end procedure;

  -- illegal states
  procedure fsm_covadd_illegal (
    name  : in string;
    covdb : inout covPType ) is
  begin
    covdb.AddCross(ALL_ILLEGAL,ALL_ILLEGAL);
  end procedure;

  -- bin collection
  procedure fsm_covcollect (
    signal reset : in std_logic;
    signal clk   : in std_logic;
    signal state : in t_state;
           covdb : inout covPType) is
    variable v_state : t_state := t_state'left;
  begin
    wait until reset='1';
    loop
      v_state := state;
      wait until rising_edge(clk);
      covdb.ICover((t_state'pos(v_state), t_state'pos(state)));
    end loop;
  end procedure;

begin

  -- Unit Under Test
  UUT : entity work.xaxi4lite_wb_bridge
  port map (
    rst_n_i       => tb_rst_n_i,
    clk_i         => tb_clk_i,
    wb_slave_i    => tb_wb_slave_i,
    wb_slave_o    => tb_wb_slave_o,
    axi4_master_i => tb_axi4_master_i,
    axi4_master_o => tb_axi4_master_o);

  -- Clock generation
	clk_proc : process
	begin
		while (not stop) loop
			tb_clk_i <= '1';
			wait for C_CLK_PERIOD/2;
			tb_clk_i <= '0';
			wait for C_CLK_PERIOD/2;
		end loop;
		wait;
	end process clk_proc;

  -- reset generation
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
      -- Slave inputs
      tb_wb_slave_i.cyc <= data.randSlv(1)(1);
      tb_wb_slave_i.stb <= data.randSlv(1)(1);
      tb_wb_slave_i.we  <= data.randSlv(1)(1);
      tb_wb_slave_i.adr <= data.randSlv(32);
      tb_wb_slave_i.sel <= data.randSlv(4);
      tb_wb_slave_i.dat <= data.randSlv(32);
      -- Master inputs
      tb_axi4_master_i.ARREADY <= data.randSlv(1)(1);
      tb_axi4_master_i.RVALID  <= data.randSlv(1)(1);
      tb_axi4_master_i.RRESP   <= data.randSlv(2);
      tb_axi4_master_i.RDATA   <= data.randSlv(32);
      tb_axi4_master_i.AWREADY <= data.randSlv(1)(1);
      tb_axi4_master_i.WREADY  <= data.randSlv(1)(1);
      tb_axi4_master_i.BVALID  <= data.randSlv(1)(1);
      tb_axi4_master_i.BRESP   <= data.randSlv(2);
      ncycles := ncycles + 1;
    end loop;
    report "Number of simulation cycles = " & to_string(ncycles);
    stop <= TRUE;
    report "Test PASS!";
    wait;
  end process stim;

  --------------------------------------------------------------------------------
  -- Coverage
  --------------------------------------------------------------------------------

  -- FSM
  fsm_proc : process(tb_clk_i)
  begin
    if rising_edge(tb_clk_i) then
      if tb_rst_n_i = '0' then
        s_state <= IDLE;
      else
        case s_state is

        -------------------------------------------
        --           IDLE STATE                 --
        ------------------------------------------
          when IDLE =>
            if tb_wb_slave_i.stb = '1' and tb_wb_slave_i.we = '0' then
              s_state <= READ;
            elsif tb_wb_slave_i.stb = '1' and tb_wb_slave_i.we = '1' then
              s_state <= WRITE;
            else
              s_state <= IDLE;
            end if;

        -------------------------------------------
        --            READ CYCLE                 --
        -------------------------------------------
          when READ =>
            if (tb_axi4_master_i.RVALID = '1') then
              s_state <= WB_END;
            else
              s_state <= READ;
            end if;

        -------------------------------------------
        --            WRITE CYCLE                --
        -------------------------------------------
          when WRITE =>
            if (tb_axi4_master_i.BVALID = '1') then
              s_state <= WB_END;
            else
              s_state <= WRITE;
            end if;

        ------------------------------------------
        --            WB_END                    --
        ------------------------------------------
          when WB_END =>
            if (tb_wb_slave_i.stb = '0') then
              s_state <= IDLE;
            else
              s_state <= WB_END;
            end if;

        end case;
      end if;
    end if;
  end process;

  process
  begin
    -- all possible legal state changes
    fsm_covadd_states("IDLE   -> READ  ",IDLE,  READ,  sv_cover);
    fsm_covadd_states("IDLE   -> WRITE ",IDLE,  WRITE, sv_cover);
    fsm_covadd_states("READ   -> WB_END",READ,  WB_END,sv_cover);
    fsm_covadd_states("WRITE  -> WB_END",WRITE, WB_END,sv_cover);
    fsm_covadd_states("WB_END -> IDLE  ",WB_END,IDLE,  sv_cover);
    -- when current and next state is the same
    fsm_covadd_states("IDLE   -> IDLE  ",IDLE,  IDLE,  sv_cover);
    fsm_covadd_states("READ   -> READ  ",READ,  READ,  sv_cover);
    fsm_covadd_states("WRITE  -> READ  ",WRITE, WRITE, sv_cover);
    fsm_covadd_states("WB_END -> WB_END",WB_END,WB_END,sv_cover);
    -- illegal states
    fsm_covadd_illegal("ILLEGAL",sv_cover);
    wait;
  end process;

  -- collect the cov bins
  fsm_covcollect(tb_rst_n_i, tb_clk_i, s_state, sv_cover);

  -- coverage report
  cov_report : process
  begin
    wait until stop;
    sv_cover.writebin;
    report "Test PASS!";
  end process;

  --------------------------------------------------------------------------------
  -- Assertions
  --------------------------------------------------------------------------------

  -- Check wb and axi4lite signals when IDLE
  process
  begin
    while (not stop) loop
      wait until rising_edge(tb_clk_i) and tb_rst_n_i /= '0';
      if s_state = IDLE then
        if tb_wb_slave_i.stb = '1' and tb_wb_slave_i.we = '0' then
          s_araddr <= tb_wb_slave_i.adr;
          wait for C_CLK_PERIOD;
          assert (tb_axi4_master_o.ARADDR = s_araddr)
            report "Read Address mismatch" severity failure;
          assert (tb_axi4_master_o.ARVALID = '1')
            report "ARVALID mismatch" severity failure;
          assert (tb_axi4_master_o.RREADY = '1')
            report "RREADY mismatch" severity failure;
        else
          s_araddr <= (others=>'0');
        end if;
      end if;
    end loop;
    wait;
  end process;


  -- Check wb and axi4lite signals when READ
  process
  begin
    while (not stop) loop
      wait until rising_edge(tb_clk_i) and tb_rst_n_i /= '0';
      if s_state = READ then
        assert (tb_wb_slave_o.ack = '0' and tb_wb_slave_o.err = '0')
          report "ACK and ERR not zero when READ" severity failure;
        assert (tb_axi4_master_o.RREADY = '1')
          report "RREADY not HIGH when READ" severity failure;
        if falling_edge(tb_axi4_master_i.ARREADY) then
          assert (tb_axi4_master_o.ARVALID = '0')
            report "WRONG ARVALID" severity failure;
        end if;
        if tb_axi4_master_i.RVALID = '1' AND tb_axi4_master_i.RRESP = c_AXI4_RESP_OKAY then
          s_wb_data <= tb_axi4_master_i.RDATA;
          wait for 1 ns;
          assert (tb_wb_slave_o.dat = s_wb_data)
            report "WB slave output data mismatch" severity failure;
          assert (tb_wb_slave_o.ack = '1' AND tb_wb_slave_o.err = '0')
            report "Wrong ACK and ERR for specific RRESP" severity failure;
        elsif tb_axi4_master_i.RVALID = '1' then
          wait for 1 ns;
          assert (tb_wb_slave_o.ack = '0' AND tb_Wb_slave_o.err = '1')
            report "Wrong ACK and ERR" severity failure;
        else
          s_wb_data <= (others=>'0');
          assert (tb_wb_slave_o.ack = '0' AND tb_Wb_slave_o.err = '0')
            report "ACK and ERR are not zero" severity failure;
        end if;
      end if;
    end loop;
    wait;
  end process;

  -- Check wb and axi4lite signals when WRITE
  process
  begin
    while (not stop) loop
      wait until rising_edge(tb_clk_i) and tb_rst_n_i = '1';
      if s_state = WRITE then
        assert (tb_wb_slave_o.ack = '0' AND tb_wb_slave_o.err = '0')
          report "ACK and ERR not zero when WRITE" severity failure;
        if falling_edge(tb_axi4_master_i.AWREADY) then
          assert (tb_axi4_master_o.AWVALID = '0')
            report "Wrong AWVALID for AWREADY HIGH" severity failure;
        end if;
        if falling_edge(tb_axi4_master_i.WREADY) then
          assert (tb_axi4_master_o.WVALID = '0')
            report "Wrong WVALID for WREADY HIGH" severity failure;
        end if;
        if rising_edge(tb_axi4_master_i.BVALID) then
          assert (tb_axi4_master_o.BREADY = '0')
            report "Wrong BREADY for BVALID HIGH" severity failure;
        elsif falling_edge(tb_axi4_master_i.BVALID) then
          assert (tb_axi4_master_o.BREADY = '1')
            report "Wrong BREADY for BVALID LOW" severity failure;
        end if;
      end if;
    end loop;
    wait;
  end process;

  -- Check wb signals when WB_END state
  process
  begin
    while (not stop) loop
      wait until rising_edge(tb_clk_i) and tb_rst_n_i = '1';
      if s_state = WB_END then
        wait for C_CLK_PERIOD;
        assert (tb_wb_slave_o.ack = '0' AND tb_wb_slave_o.err = '0')
          report "ACK and ERR are not zero when WB_END" severity failure;
      end if;
    end loop;
    wait;
  end process;

end tb;
