-------------------------------------------------------------------------------
-- Title      : Wishbone UART for WR Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_conmax_top.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2011-02-21
-- Last update: 2011-02-21
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- Simple UART port with Wishbone interface
--
-------------------------------------------------------------------------------
-- Copyright (c) 2011 Tomasz Wlostowski
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-02-21  1.0      twlostow        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity wb_simple_uart is
  port (

    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    wb_addr_i : in  std_logic_vector(1 downto 0);
    wb_data_i : in  std_logic_vector(31 downto 0);
    wb_data_o : out std_logic_vector(31 downto 0);
    wb_cyc_i  : in  std_logic;
    wb_sel_i  : in  std_logic_vector(3 downto 0);
    wb_stb_i  : in  std_logic;
    wb_we_i   : in  std_logic;
    wb_ack_o  : out std_logic;

    uart_rxd_i : in  std_logic;
    uart_txd_o : out std_logic
    );
end wb_simple_uart;

architecture syn of wb_simple_uart is

  constant c_baud_acc_width : integer := 16;

  component uart_wb_slave
    port (
      rst_n_i                 : in  std_logic;
      wb_clk_i                : in  std_logic;
      wb_addr_i               : in  std_logic_vector(1 downto 0);
      wb_data_i               : in  std_logic_vector(31 downto 0);
      wb_data_o               : out std_logic_vector(31 downto 0);
      wb_cyc_i                : in  std_logic;
      wb_sel_i                : in  std_logic_vector(3 downto 0);
      wb_stb_i                : in  std_logic;
      wb_we_i                 : in  std_logic;
      wb_ack_o                : out std_logic;
      uart_sr_tx_busy_i       : in  std_logic;
      uart_sr_rx_rdy_i        : in  std_logic;
      uart_bcr_o              : out std_logic_vector(31 downto 0);
      uart_tdr_tx_data_o      : out std_logic_vector(7 downto 0);
      uart_tdr_tx_data_i      : in  std_logic_vector(7 downto 0);
      uart_tdr_tx_data_load_o : out std_logic;

      uart_rdr_rx_data_i : in  std_logic_vector(7 downto 0);
      rdr_rack_o         : out std_logic);
  end component;

  component uart_baud_gen
    generic (
      g_baud_acc_width : integer);
    port (
      clk_sys_i    : in  std_logic;
      rst_n_i      : in  std_logic;
      baudrate_i   : in  std_logic_vector(g_baud_acc_width  downto 0);
      baud_tick_o  : out std_logic;
      baud8_tick_o : out std_logic);
  end component;


  component uart_async_rx
    port (
      clk_sys_i    : in  std_logic;
      rst_n_i      : in  std_logic;
      baud8_tick_i : in  std_logic;
      rxd_i        : in  std_logic;
      rx_ready_o   : out  std_logic;
      rx_error_o   : out std_logic;
      rx_data_o    : out std_logic_vector(7 downto 0));
  end component;

  component uart_async_tx
    port (
      clk_sys_i    : in  std_logic;
      rst_n_i      : in  std_logic;
      baud_tick_i  : in  std_logic;
      txd_o        : out std_logic;
      tx_start_p_i : in  std_logic;
      tx_data_i    : in  std_logic_vector(7 downto 0);
      tx_busy_o    : out std_logic);
  end component;

  signal rx_ready_reg    : std_logic;
  signal rx_ready        : std_logic;
  signal uart_sr_tx_busy : std_logic;
  signal uart_sr_rx_rdy  : std_logic;
  signal uart_bcr        : std_logic_vector(31 downto 0);

  signal uart_tdr_tx_data      : std_logic_vector(7 downto 0);
  signal uart_tdr_tx_data_load : std_logic;

  signal uart_rdr_rx_data : std_logic_vector(7 downto 0);
  signal rdr_rack         : std_logic;

  signal baud_tick  : std_logic;
  signal baud_tick8 : std_logic;
  
begin  -- syn

  BAUD_GEN : uart_baud_gen
    generic map (
      g_baud_acc_width => c_baud_acc_width)
    port map (
      clk_sys_i    => clk_sys_i,
      rst_n_i      => rst_n_i,
      baudrate_i   => uart_bcr(c_baud_acc_width downto 0),
      baud_tick_o  => baud_tick,
      baud8_tick_o => baud_tick8);

  TX : uart_async_tx
    port map (
      clk_sys_i    => clk_sys_i,
      rst_n_i      => rst_n_i,
      baud_tick_i  => baud_tick,
      txd_o        => uart_txd_o,
      tx_start_p_i => uart_tdr_tx_data_load,
      tx_data_i    => uart_tdr_tx_data,
      tx_busy_o    => uart_sr_tx_busy);

  RX : uart_async_rx
    port map (
      clk_sys_i    => clk_sys_i,
      rst_n_i      => rst_n_i,
      baud8_tick_i => baud_tick8,
      rxd_i        => uart_rxd_i,
      rx_ready_o   => rx_ready,
      rx_error_o   => open,
      rx_data_o    => uart_rdr_rx_data);

  WB_SLAVE : uart_wb_slave
    port map (
      rst_n_i   => rst_n_i,
      wb_clk_i  => clk_sys_i,
      wb_addr_i => wb_addr_i,
      wb_data_i => wb_data_i,
      wb_data_o => wb_data_o,
      wb_cyc_i  => wb_cyc_i,
      wb_sel_i  => wb_sel_i,
      wb_stb_i  => wb_stb_i,
      wb_we_i   => wb_we_i,
      wb_ack_o  => wb_ack_o,

      uart_sr_tx_busy_i       => uart_sr_tx_busy,
      uart_sr_rx_rdy_i        => uart_sr_rx_rdy,
      uart_bcr_o              => uart_bcr,
      uart_tdr_tx_data_o      => uart_tdr_tx_data,
      uart_tdr_tx_data_i      => uart_tdr_tx_data,
      uart_tdr_tx_data_load_o => uart_tdr_tx_data_load,
      uart_rdr_rx_data_i      => uart_rdr_rx_data,
      rdr_rack_o              => rdr_rack);

  process(clk_sys_i, rst_n_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        uart_sr_rx_rdy <= '0';
      else
        if(rx_ready = '1') then
          uart_sr_rx_rdy <= '1';
        elsif(rdr_rack = '1') then
          uart_sr_rx_rdy <= '0';
        end if;
      end if;
    end if;
  end process;
  
end syn;
