--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General cores: Simple Wishbone UART
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   wb_simple_uart
--
-- description: A simple UART controller, providing two modes of operation
-- (both can be used simultenously):
-- - physical UART (encoding fixed to 8 data bits, no parity and one stop bit)
-- - virtual UART: TXed data is passed via a FIFO to the Wishbone host (and
--   vice versa).
--
-- This unit does not use VHDL records for entity ports. For a version with
-- records, see xwb_simple_uart.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2010-2019
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
use ieee.numeric_std.all;

use work.genram_pkg.all;
use work.wishbone_pkg.all;
use work.UART_wbgen2_pkg.all;

entity wb_simple_uart is
  generic(
    g_WITH_VIRTUAL_UART       : boolean;
    g_WITH_PHYSICAL_UART      : boolean;
    g_WITH_PHYSICAL_UART_FIFO : boolean                        := false;
    g_TX_FIFO_SIZE            : integer                        := 0;
    g_RX_FIFO_SIZE            : integer                        := 0;
    g_INTERFACE_MODE          : t_wishbone_interface_mode      := CLASSIC;
    g_ADDRESS_GRANULARITY     : t_wishbone_address_granularity := WORD;
    g_VUART_FIFO_SIZE         : integer                        := 1024;
    g_PRESET_BCR              : integer                        := 0
    );
  port (

    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    wb_adr_i   : in  std_logic_vector(4 downto 0);
    wb_dat_i   : in  std_logic_vector(31 downto 0);
    wb_dat_o   : out std_logic_vector(31 downto 0);
    wb_cyc_i   : in  std_logic;
    wb_sel_i   : in  std_logic_vector(3 downto 0);
    wb_stb_i   : in  std_logic;
    wb_we_i    : in  std_logic;
    wb_ack_o   : out std_logic;
    wb_stall_o : out std_logic;

    int_o : out std_logic;

    uart_rxd_i : in  std_logic;
    uart_txd_o : out std_logic
    );
end wb_simple_uart;

architecture arch of wb_simple_uart is

  constant c_BAUD_ACC_WIDTH : integer := 16;

  signal rx_ready_reg : std_logic;
  signal rx_ready     : std_logic;
  signal uart_bcr     : std_logic_vector(31 downto 0);

  signal rdr_rack  : std_logic;
  signal host_rack : std_logic;

  signal baud_tick  : std_logic;
  signal baud_tick8 : std_logic;

  signal resized_addr : std_logic_vector(c_WISHBONE_ADDRESS_WIDTH-1 downto 0);

  signal wb_in  : t_wishbone_slave_in;
  signal wb_out : t_wishbone_slave_out;

  signal regs_in  : t_UART_in_registers;
  signal regs_out : t_UART_out_registers;

  signal vuart_fifo_empty : std_logic;
  signal vuart_fifo_full  : std_logic;
  signal vuart_fifo_rd    : std_logic;
  signal vuart_fifo_wr    : std_logic;
  signal vuart_fifo_count : std_logic_vector(f_log2_size(g_VUART_FIFO_SIZE)-1 downto 0);

  signal tx_fifo_empty   : std_logic;
  signal tx_fifo_full    : std_logic;
  signal tx_fifo_rd      : std_logic;
  signal tx_fifo_wr      : std_logic;
  signal tx_fifo_count   : std_logic_vector(f_log2_size(g_TX_FIFO_SIZE)-1 downto 0);
  signal tx_fifo_reset_n : std_logic;

  signal rx_fifo_empty    : std_logic;
  signal rx_fifo_full     : std_logic;
  signal rx_fifo_overflow : std_logic;
  signal rx_fifo_rd       : std_logic;
  signal rx_fifo_wr       : std_logic;
  signal rx_fifo_count    : std_logic_vector(f_log2_size(g_RX_FIFO_SIZE)-1 downto 0);
  signal rx_fifo_reset_n  : std_logic;

  signal phys_rx_ready, phys_tx_busy, phys_tx_start : std_logic;

  signal phys_rx_data, phys_tx_data : std_logic_vector(7 downto 0);

  type t_tx_fifo_state is (IDLE, TRANSMIT_PENDING);
  type t_rx_fifo_state is (IDLE, RX_READ, RX_WAIT_ACK );

  signal tx_fifo_state : t_tx_fifo_state;
  signal rx_fifo_state : t_rx_fifo_state;

  signal rx_fifo_rdata : std_logic_vector(7 downto 0);
  signal rx_fifo_wdata : std_logic_vector(7 downto 0);


  function f_to_sl( x : boolean ) return std_logic is
  begin
    if(x) then
      return '1';
    else
      return '0';
    end if;
  end f_to_sl;
  
begin  -- arch

  gen_check_generics : if (not g_WITH_PHYSICAL_UART and not g_WITH_VIRTUAL_UART) generate
    assert false report
      "wb_simple_uart: dummy configuration (use virtual, physical or both uarts)"
      severity failure;
  end generate gen_check_generics;

  resized_addr(4 downto 0)                          <= wb_adr_i;
  resized_addr(c_WISHBONE_ADDRESS_WIDTH-1 downto 5) <= (others => '0');

  U_Adapter : wb_slave_adapter
    generic map (
      g_MASTER_USE_STRUCT  => true,
      g_MASTER_MODE        => CLASSIC,
      g_MASTER_GRANULARITY => WORD,
      g_SLAVE_USE_STRUCT   => false,
      g_SLAVE_MODE         => g_INTERFACE_MODE,
      g_SLAVE_GRANULARITY  => g_ADDRESS_GRANULARITY)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      master_i   => wb_out,
      master_o   => wb_in,
      sl_adr_i   => resized_addr,
      sl_dat_i   => wb_dat_i,
      sl_sel_i   => wb_sel_i,
      sl_cyc_i   => wb_cyc_i,
      sl_stb_i   => wb_stb_i,
      sl_we_i    => wb_we_i,
      sl_dat_o   => wb_dat_o,
      sl_ack_o   => wb_ack_o,
      sl_stall_o => wb_stall_o);

  U_WB_SLAVE : entity work.simple_uart_wb
    port map (
      rst_n_i    => rst_n_i,
      clk_sys_i  => clk_sys_i,
      wb_adr_i   => wb_in.adr(2 downto 0),
      wb_dat_i   => wb_in.dat,
      wb_dat_o   => wb_out.dat,
      wb_cyc_i   => wb_in.cyc,
      wb_sel_i   => wb_in.sel,
      wb_stb_i   => wb_in.stb,
      wb_we_i    => wb_in.we,
      wb_ack_o   => wb_out.ack,
      wb_stall_o => wb_out.stall,

      rdr_rack_o  => rdr_rack,
      host_rack_o => host_rack,
      regs_o      => regs_out,
      regs_i      => regs_in);

  wb_out.err <= '0';
  wb_out.rty <= '0';

  gen_phys_uart : if (g_WITH_PHYSICAL_UART) generate

    p_bcr_reg : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          uart_bcr <= std_logic_vector(to_unsigned(g_preset_bcr, uart_bcr'length));
        elsif(regs_out.bcr_wr_o = '1')then
          uart_bcr <= regs_out.bcr_o;
        end if;
      end if;
    end process p_bcr_reg;

    U_BAUD_GEN : entity work.uart_baud_gen
      generic map (
        g_BAUD_ACC_WIDTH => c_BAUD_ACC_WIDTH)
      port map (
        clk_sys_i    => clk_sys_i,
        rst_n_i      => rst_n_i,
        baudrate_i   => uart_bcr(c_BAUD_ACC_WIDTH downto 0),
        baud_tick_o  => baud_tick,
        baud8_tick_o => baud_tick8);

    U_TX : entity work.uart_async_tx
      port map (
        clk_sys_i    => clk_sys_i,
        rst_n_i      => rst_n_i,
        baud_tick_i  => baud_tick,
        txd_o        => uart_txd_o,
        tx_start_p_i => phys_tx_start,
        tx_data_i    => phys_tx_data,
        tx_busy_o    => phys_tx_busy);

    U_RX : entity work.uart_async_rx
      port map (
        clk_sys_i    => clk_sys_i,
        rst_n_i      => rst_n_i,
        baud8_tick_i => baud_tick8,
        rxd_i        => uart_rxd_i,
        rx_ready_o   => phys_rx_ready,
        rx_error_o   => open, -- fixme: support RX error detection
        rx_data_o    => phys_rx_data);

  end generate gen_phys_uart;

  gen_phys_fifos : if g_WITH_PHYSICAL_UART_FIFO generate

    rx_fifo_wr <= not rx_fifo_full and (phys_rx_ready or ( f_to_sl(g_WITH_VIRTUAL_UART) and regs_out.host_tdr_data_wr_o ) );
    tx_fifo_wr <= not tx_fifo_full and regs_out.tdr_tx_data_wr_o;

    tx_fifo_reset_n <= rst_n_i and not regs_out.cr_tx_fifo_purge_o;
    rx_fifo_reset_n <= rst_n_i and not regs_out.cr_rx_fifo_purge_o;

    -- RX FIFO write data: Physical UART takes the priority over VUART. Note these
    -- are not meant to be used simultaneously.
    rx_fifo_wdata <= phys_rx_data when phys_rx_ready = '1' else regs_out.host_tdr_data_o;
    

    U_UART_RX_FIFO : generic_sync_fifo
      generic map (
        g_DATA_WIDTH => 8,
        g_SIZE       => g_RX_FIFO_SIZE,
        g_WITH_COUNT => true,
        g_SHOW_AHEAD => false
        )
      port map (
        rst_n_i => rx_fifo_reset_n,
        clk_i   => clk_sys_i,
        d_i     => rx_fifo_wdata,
        we_i    => rx_fifo_wr,
        q_o     => rx_fifo_rdata,
        rd_i    => rx_fifo_rd,
        empty_o => rx_fifo_empty,
        full_o  => rx_fifo_full,
        count_o => rx_fifo_count);

    U_UART_TX_FIFO : generic_sync_fifo
      generic map (
        g_DATA_WIDTH => 8,
        g_SIZE       => g_TX_FIFO_SIZE,
        g_WITH_COUNT => false,
        g_SHOW_AHEAD => true
        )
      port map (
        rst_n_i => tx_fifo_reset_n,
        clk_i   => clk_sys_i,
        d_i     => regs_out.tdr_tx_data_o,
        we_i    => tx_fifo_wr,
        q_o     => phys_tx_data,
        rd_i    => phys_tx_start,
        empty_o => tx_fifo_empty,
        full_o  => tx_fifo_full);


    regs_in.sr_rx_fifo_supported_i <= '1';
    regs_in.sr_tx_fifo_supported_i <= '1';
    regs_in.sr_rx_fifo_overflow_i  <= rx_fifo_overflow;
    regs_in.sr_tx_fifo_full_i      <= tx_fifo_full;
    regs_in.sr_tx_fifo_empty_i     <= tx_fifo_empty;

    regs_in.sr_rx_fifo_bytes_i (rx_fifo_count'length-1 downto 0) <= rx_fifo_count;
    regs_in.sr_rx_fifo_bytes_i ( 15 downto rx_fifo_count'length ) <= (others => '0');
    
    
    phys_tx_start <= '1' when tx_fifo_state = IDLE and tx_fifo_empty = '0' else '0';

    p_rx_fifo_overflow : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rx_fifo_reset_n = '0' then
          rx_fifo_overflow <= '0';
        else
          if regs_out.cr_rx_fifo_purge_o = '1' then
            rx_fifo_overflow <= '0';
          elsif rx_fifo_full = '1' then
            rx_fifo_overflow <= '1';
          end if;
        end if;
      end if;
    end process;



    p_tx_fifo_fsm : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if tx_fifo_reset_n = '0' then
          tx_fifo_state <= IDLE;
          tx_fifo_rd    <= '0';
        else
          case tx_fifo_state is
            when IDLE =>
              if tx_fifo_empty = '0' then
                tx_fifo_rd    <= '1';
                tx_fifo_state <= TRANSMIT_PENDING;
              end if;

            when TRANSMIT_PENDING =>
              tx_fifo_rd <= '0';
              if phys_tx_busy = '0' then
                tx_fifo_state <= IDLE;
              end if;
          end case;
        end if;
      end if;
    end process;

    
    p_rx_fifo_fsm : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rx_fifo_reset_n = '0' then
          rx_fifo_state <= IDLE;
          regs_in.sr_rx_fifo_valid_i     <= '0';
          regs_in.sr_rx_rdy_i            <= '0';

        else
          case rx_fifo_state is
            when IDLE =>
              regs_in.sr_rx_fifo_valid_i     <= '0';
              regs_in.sr_rx_rdy_i            <= '0';

              if rx_fifo_rd = '1' then
                rx_fifo_state <= RX_READ;
              end if;

            when RX_READ =>

              regs_in.rdr_rx_data_i <= rx_fifo_rdata;
              regs_in.sr_rx_fifo_valid_i     <= '1';
              regs_in.sr_rx_rdy_i            <= '1';
              rx_fifo_state <= RX_WAIT_ACK;

            when RX_WAIT_ACK =>
              
              if( rdr_rack = '1' ) then
                regs_in.sr_rx_fifo_valid_i     <= '0';
                regs_in.sr_rx_rdy_i            <= '0';
                rx_fifo_state <= IDLE;
              end if;
          end case;
        end if;
      end if;
    end process;

    rx_fifo_rd  <= '1' when rx_fifo_state = IDLE and rx_fifo_empty = '0' else '0';

    regs_in.sr_tx_busy_i   <= tx_fifo_full;
  end generate gen_phys_fifos;

  gen_phys_nofifos : if not g_WITH_PHYSICAL_UART_FIFO generate

    phys_tx_data <= regs_out.tdr_tx_data_o;
    phys_tx_start <= regs_out.tdr_tx_data_wr_o and not phys_tx_busy;
    regs_in.sr_tx_busy_i   <= phys_tx_busy when (g_WITH_PHYSICAL_UART) else '0';

    p_drive_rx_ready : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          regs_in.sr_rx_rdy_i   <= '0';
          int_o                 <= '0';
          regs_in.rdr_rx_data_i <= (others => '0');
        else
          if rdr_rack = '1' and phys_rx_ready = '0' then
            regs_in.sr_rx_rdy_i <= '0';
            int_o               <= '0';
          elsif phys_rx_ready = '1' and g_WITH_PHYSICAL_UART then
            regs_in.sr_rx_rdy_i   <= '1';
            int_o                 <= '1';
            regs_in.rdr_rx_data_i <= phys_rx_data;
          elsif regs_out.host_tdr_data_wr_o = '1' and g_WITH_VIRTUAL_UART then
            regs_in.sr_rx_rdy_i   <= '1';
            int_o                 <= '1';
            regs_in.rdr_rx_data_i <= regs_out.host_tdr_data_o;
          end if;
        end if;
      end if;
    end process p_drive_rx_ready;


  end generate gen_phys_nofifos;




  gen_vuart : if (g_WITH_VIRTUAL_UART) generate

    vuart_fifo_wr <= not vuart_fifo_full and regs_out.tdr_tx_data_wr_o;
    vuart_fifo_rd <= not vuart_fifo_empty and not regs_in.host_rdr_rdy_i;

    U_VUART_FIFO : generic_sync_fifo
      generic map (
        g_DATA_WIDTH => 8,
        g_SIZE       => g_VUART_FIFO_SIZE,
        g_WITH_COUNT => true,
        g_SHOW_AHEAD => false)
      port map (
        rst_n_i => rst_n_i,
        clk_i   => clk_sys_i,
        d_i     => regs_out.tdr_tx_data_o,
        we_i    => vuart_fifo_wr,
        q_o     => regs_in.host_rdr_data_i,
        rd_i    => vuart_fifo_rd,
        empty_o => vuart_fifo_empty,
        full_o  => vuart_fifo_full,
        count_o => vuart_fifo_count);

    regs_in.host_rdr_count_i(vuart_fifo_count'left downto 0)    <= vuart_fifo_count;
    regs_in.host_rdr_count_i(15 downto vuart_fifo_count'length) <= (others => '0');

    p_vuart_rx_ready : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          regs_in.host_rdr_rdy_i <= '0';
        elsif vuart_fifo_rd = '1' then
          regs_in.host_rdr_rdy_i <= '1';
        elsif host_rack = '1' then
          regs_in.host_rdr_rdy_i <= '0';
        end if;
      end if;
    end process p_vuart_rx_ready;

  end generate gen_vuart;

  gen_no_vuart : if (not g_WITH_VIRTUAL_UART) generate
    regs_in.host_rdr_data_i  <= (others => '0');
    regs_in.host_rdr_count_i <= (others => '0');
    regs_in.host_rdr_rdy_i   <= '0';
  end generate gen_no_vuart;

  regs_in.host_tdr_rdy_i <= not regs_in.sr_rx_rdy_i;

end arch;
