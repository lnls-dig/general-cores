--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://gitlab.com/ohwr/project/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_clock_bridge
--
-- description: Cross clock-domain wishbone adapter
--
--------------------------------------------------------------------------------
-- Copyright CERN 2018
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

-- IMPORTANT: If you reset one clock domain, you must reset BOTH!
-- Release of the reset lines may be arbitrarily out-of-phase

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;

entity xwb_clock_bridge is
  generic (
    -- Slave port (from WB master) mode
    g_SLAVE_PORT_WB_MODE  : t_wishbone_interface_mode := PIPELINED;
    -- Master port (to WB slave) mode
    g_MASTER_PORT_WB_MODE : t_wishbone_interface_mode := PIPELINED;
    -- Depth of sync FIFOs. Increase it to improve performance
    -- in case of longer pipelined bursts
    g_SIZE                : natural                   := 16);
  port (
    -- Slave port (from WB master)
    slave_clk_i    : in  std_logic;
    slave_rst_n_i  : in  std_logic;
    slave_i        : in  t_wishbone_slave_in;
    slave_o        : out t_wishbone_slave_out;
    -- Master port (to WB slave)
    master_clk_i   : in  std_logic;
    master_rst_n_i : in  std_logic;
    master_i       : in  t_wishbone_master_in;
    master_o       : out t_wishbone_master_out);
end xwb_clock_bridge;

architecture arch of xwb_clock_bridge is

  -- size of counter for keeping track of pending WB transactions.
  constant c_PEND_WB_CNT_LEN : positive := 16;

  constant c_S2M_FIFO_WIDTH : natural :=
    c_WISHBONE_ADDRESS_WIDTH +
    C_WISHBONE_DATA_WIDTH +
    4 +   -- SEL
    1;    -- WE

  constant c_S2M_DATA_OFFSET : natural := c_S2M_FIFO_WIDTH - c_WISHBONE_ADDRESS_WIDTH - 1;

  subtype t_s2m_addr_range is
    natural range c_S2M_FIFO_WIDTH - 1 downto c_S2M_DATA_OFFSET + 1;

  subtype t_s2m_data_range is
    natural range c_S2M_DATA_OFFSET downto 5;

  subtype t_s2m_fifo_data is
    std_logic_vector(c_S2M_FIFO_WIDTH - 1 downto 0);

  constant c_M2S_FIFO_WIDTH : natural :=
    C_WISHBONE_DATA_WIDTH +
    1 +   -- ACK
    1 +   -- ERR
    1;    -- RTY

  subtype t_m2s_data_range is
    natural range c_M2S_FIFO_WIDTH - 1 downto 3;

  subtype t_m2s_fifo_data is
    std_logic_vector(c_M2S_FIFO_WIDTH - 1 downto 0);

  -- signals in the slave port clock domain (SDM).
  signal sdm_fifo_in   : t_s2m_fifo_data;
  signal sdm_s2m_full  : std_logic;
  signal sdm_wr_en     : std_logic;
  signal sdm_fifo_out  : t_m2s_fifo_data;
  signal sdm_m2s_empty : std_logic;
  signal sdm_rd_en     : std_logic;
  signal sdm_rd_en_d1  : std_logic;
  signal sdm_wb_in     : t_wishbone_slave_in;
  signal sdm_wb_out    : t_wishbone_slave_out;

  -- signals in the master port clock domain (MDM).
  signal mdm_fifo_in   : t_m2s_fifo_data;
  signal mdm_wr_en     : std_logic;
  signal mdm_fifo_out  : t_s2m_fifo_data;
  signal mdm_s2m_empty : std_logic;
  signal mdm_rd_en     : std_logic;
  signal mdm_rd_en_d1  : std_logic;
  signal mdm_wb_in     : t_wishbone_master_in;
  signal mdm_wb_out    : t_wishbone_master_out;
  signal mdm_m2s_count : std_logic_vector(f_log2_size(g_SIZE)-1 downto 0);
  signal mdm_pend_tr   : std_logic;
  signal mdm_pend_cnt  : unsigned(f_log2_size(g_SIZE)-1 downto 0);
  signal mdm_block_en  : std_logic;
  signal mdm_block_lim : unsigned(f_log2_size(g_SIZE)-1 downto 0);
  signal mdm_wb_new_tr : std_logic;

begin  -- architecture arch

  ------------------------------------------------------------------------------
  -- Slave and Master port adapters to convert from user's interface to
  -- PIPELINED mode because all the sync logic is based on the pipelined
  -- protocol.
  -- Address granularity is irrelevant for the clock bridge, we assume it is
  -- BYTE and just pass it over.
  ------------------------------------------------------------------------------

  cmp_wb_slave_port_adapter : wb_slave_adapter
    generic map (
      g_slave_use_struct   => TRUE,
      g_slave_mode         => g_SLAVE_PORT_WB_MODE,
      g_slave_granularity  => BYTE,
      g_master_use_struct  => TRUE,
      g_master_mode        => PIPELINED,
      g_master_granularity => BYTE)
    port map (
      clk_sys_i => slave_clk_i,
      rst_n_i   => slave_rst_n_i,
      slave_i   => slave_i,
      slave_o   => slave_o,
      master_i  => sdm_wb_out,
      master_o  => sdm_wb_in);

  cmp_wb_master_port_adapter : wb_slave_adapter
    generic map (
      g_slave_use_struct   => TRUE,
      g_slave_mode         => PIPELINED,
      g_slave_granularity  => BYTE,
      g_master_use_struct  => TRUE,
      g_master_mode        => g_MASTER_PORT_WB_MODE,
      g_master_granularity => BYTE)
    port map (
      clk_sys_i => master_clk_i,
      rst_n_i   => master_rst_n_i,
      slave_i   => mdm_wb_out,
      slave_o   => mdm_wb_in,
      master_i  => master_i,
      master_o  => master_o);

  ------------------------------------------------------------------------------
  -- S2M FIFO: from slave port to master port (transmits transcactions to WB slaves).
  -- Including all signal assignments in the slave port clock domain (SDM).
  ------------------------------------------------------------------------------

  cmp_s2m_fifo : generic_async_fifo_dual_rst
    generic map (
      g_DATA_WIDTH => c_S2M_FIFO_WIDTH,
      g_SIZE       => g_SIZE)
    port map (
      rst_wr_n_i => slave_rst_n_i,
      clk_wr_i   => slave_clk_i,
      d_i        => sdm_fifo_in,
      we_i       => sdm_wr_en,
      wr_full_o  => sdm_s2m_full,
      rst_rd_n_i => master_rst_n_i,
      clk_rd_i   => master_clk_i,
      q_o        => mdm_fifo_out,
      rd_i       => mdm_rd_en,
      rd_empty_o => mdm_s2m_empty);

  -- Write to S2M FIFO whenever the WB master has asserted CYC and STB
  -- and the S2M FIFO is not full (otherwise, we stall).
  sdm_wr_en <= not sdm_s2m_full and sdm_wb_in.cyc and sdm_wb_in.stb;

  -- Map sdm_wb_in to sdm_fifo_in
  sdm_fifo_in(t_s2m_addr_range) <= sdm_wb_in.adr;
  sdm_fifo_in(t_s2m_data_range) <= sdm_wb_in.dat;
  sdm_fifo_in(4 downto 1)       <= sdm_wb_in.sel;
  sdm_fifo_in(0)                <= sdm_wb_in.we;

  -- Read from M2S FIFO (in other words, update state of ACK, ERR, RTY and
  -- DAT signals) whenever it is not empty.
  sdm_rd_en <= not sdm_m2s_empty;

  -- Always stall when the S2M FIFO is full.
  sdm_wb_out.stall <= sdm_s2m_full;

  -- DAT is always output, since it is validated by ACK/ERR/RTY.
  sdm_wb_out.dat <= sdm_fifo_out(t_m2s_data_range);

  -- Delay sdm_rd_en by one cycle to align it with the data on sdm_fifo_out.
  p_sdm_rd_en_d1 : process (slave_clk_i) is
  begin
    if rising_edge(slave_clk_i) then
      sdm_rd_en_d1 <= sdm_rd_en;
    end if;
  end process p_sdm_rd_en_d1;

  -- Acknowledge with a one clock cycle wide pulse per entry in M2S FIFO
  -- (M2S FIFO is read whenever it is not empty). Data is made available one
  -- clock cycle after sdm_rd_en is asserted.
  sdm_wb_out.ack <= sdm_wb_in.cyc and sdm_fifo_out(2) and sdm_rd_en_d1;
  sdm_wb_out.err <= sdm_wb_in.cyc and sdm_fifo_out(1) and sdm_rd_en_d1;
  sdm_wb_out.rty <= sdm_wb_in.cyc and sdm_fifo_out(0) and sdm_rd_en_d1;

  ------------------------------------------------------------------------------
  -- M2S FIFO: from master port to slave port (receives replies from WB slaves)
  ------------------------------------------------------------------------------

  cmp_m2s_fifo : generic_async_fifo_dual_rst
    generic map (
      g_DATA_WIDTH    => c_M2S_FIFO_WIDTH,
      g_WITH_WR_FULL  => FALSE,
      g_WITH_WR_COUNT => TRUE,
      g_SIZE          => g_SIZE)
    port map (
      rst_wr_n_i => master_rst_n_i,
      clk_wr_i   => master_clk_i,
      d_i        => mdm_fifo_in,
      we_i       => mdm_wr_en,
      wr_count_o => mdm_m2s_count,
      rst_rd_n_i => slave_rst_n_i,
      clk_rd_i   => slave_clk_i,
      q_o        => sdm_fifo_out,
      rd_i       => sdm_rd_en,
      rd_empty_o => sdm_m2s_empty);

  -- Read from S2M FIFO (in other words, update state of ADR, DAT, SEL and WE
  -- signals) whenever the S2M FIFO is not empty and there is enough space in
  -- the M2S_FIFO to push the new reply, taking into account any pending
  -- transactions (not yet ack'ed by the WB slave).
  mdm_rd_en <= not (mdm_s2m_empty or mdm_block_en) and
               not (mdm_pend_tr and mdm_wb_in.stall);

  -- Assert CYC whenever there are pending WB transactions.
  mdm_wb_out.cyc <= mdm_pend_tr;

  -- Delay mdm_rd_en by one cycle to align it with the data on mdm_fifo_out.
  -- Delay STB and STALL by one cycle to properly detect new transactions.
  p_mdm_d1 : process (master_clk_i) is
  begin
    if rising_edge(master_clk_i) then
      mdm_rd_en_d1  <= mdm_rd_en;
      mdm_wb_new_tr <= mdm_wb_out.stb and mdm_wb_in.stall;
    end if;
  end process p_mdm_d1;

  -- Strobe with a one clock cycle wide pulse per entry in S2M FIFO, unless
  -- the WB slave stalls, in which case the STB is extended.
  mdm_wb_out.stb <= mdm_rd_en_d1 or mdm_wb_new_tr;

  -- ADR, DAT, SEL and WE are always output, since they are validated by STB.
  mdm_wb_out.adr <= mdm_fifo_out(t_s2m_addr_range);
  mdm_wb_out.dat <= mdm_fifo_out(t_s2m_data_range);
  mdm_wb_out.sel <= mdm_fifo_out(4 downto 1);
  mdm_wb_out.we  <= mdm_fifo_out(0);

  -- Map mdm_wb_in to mdm_fifo_in
  mdm_fifo_in(t_m2s_data_range) <= mdm_wb_in.dat;
  mdm_fifo_in(2)                <= mdm_wb_in.ack;
  mdm_fifo_in(1)                <= mdm_wb_in.err;
  mdm_fifo_in(0)                <= mdm_wb_in.rty;

  -- Write to M2S FIFO whenever the WB slave terminates a cycle in any way.
  mdm_wr_en <= mdm_wb_out.cyc and (mdm_wb_in.ack or mdm_wb_in.err or mdm_wb_in.rty);

  -- Keep a count of pending WB transactions.
  p_wb_pending_cnt : process (master_clk_i) is
  begin
    if rising_edge(master_clk_i) then
      if master_rst_n_i = '0' then
        mdm_pend_cnt <= (others => '0');
      elsif mdm_rd_en = '1' and mdm_wr_en = '0' then
        mdm_pend_cnt <= mdm_pend_cnt + 1;
      elsif mdm_rd_en = '0' and mdm_wr_en = '1' then
        mdm_pend_cnt <= mdm_pend_cnt - 1;
      end if;
    end if;
  end process p_wb_pending_cnt;

  mdm_pend_tr <= '0' when mdm_pend_cnt = 0 else '1';

  mdm_block_lim <= to_unsigned(g_SIZE-1, mdm_m2s_count'length) - unsigned(mdm_m2s_count);
  mdm_block_en  <= '0' when mdm_pend_cnt < mdm_block_lim else '1';

end architecture arch;
