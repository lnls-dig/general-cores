--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General cores: Simple Wishbone UART
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_simple_uart
--
-- description: A simple UART controller, providing two modes of operation
-- (both can be used simultenously):
-- - physical UART (encoding fixed to 8 data bits, no parity and one stop bit)
-- - virtual UART: TXed data is passed via a FIFO to the Wishbone host (and
--   vice versa).
--
-- This unit uses VHDL records for entity ports and acts like a wrapper around
-- wb_simple_uart.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2010-2018
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

library work;
use work.wishbone_pkg.all;

entity xwb_simple_uart is
  generic(
    g_with_virtual_uart   : boolean := true;
    g_with_physical_uart  : boolean := true;
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD;
    g_vuart_fifo_size     : integer := 1024
    );

  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    -- Wishbone
    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;
    desc_o  : out t_wishbone_device_descriptor;
    int_o   : out std_logic;

    uart_rxd_i: in std_logic;
    uart_txd_o: out std_logic

    );

end xwb_simple_uart;

architecture rtl of xwb_simple_uart is

  component wb_simple_uart
    generic (
      g_with_virtual_uart   : boolean;
      g_with_physical_uart  : boolean;
      g_interface_mode      : t_wishbone_interface_mode;
      g_address_granularity : t_wishbone_address_granularity;
      g_vuart_fifo_size     : integer);
    port (
      clk_sys_i  : in  std_logic;
      rst_n_i    : in  std_logic;
      wb_adr_i   : in  std_logic_vector(4 downto 0);
      wb_dat_i   : in  std_logic_vector(31 downto 0);
      wb_dat_o   : out std_logic_vector(31 downto 0);
      wb_cyc_i   : in  std_logic;
      wb_sel_i   : in  std_logic_vector(3 downto 0);
      wb_stb_i   : in  std_logic;
      wb_we_i    : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_stall_o : out std_logic;
      int_o      : out std_logic;
      uart_rxd_i : in  std_logic;
      uart_txd_o : out std_logic);
  end component;
  
begin  -- rtl

  U_Wrapped_UART: wb_simple_uart
    generic map (
      g_with_virtual_uart   => g_with_virtual_uart,
      g_with_physical_uart  => g_with_physical_uart,
      g_interface_mode      => g_interface_mode,
      g_address_granularity => g_address_granularity,
      g_vuart_fifo_size     => g_vuart_fifo_size)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      wb_adr_i   => slave_i.adr(4 downto 0),
      wb_dat_i   => slave_i.dat,
      wb_dat_o   => slave_o.dat,
      wb_cyc_i   => slave_i.cyc,
      wb_sel_i   => slave_i.sel,
      wb_stb_i   => slave_i.stb,
      wb_we_i    => slave_i.we,
      wb_ack_o   => slave_o.ack,
      wb_stall_o => slave_o.stall,
      int_o      => int_o,
      uart_rxd_i => uart_rxd_i,
      uart_txd_o => uart_txd_o);

  slave_o.err <= '0';
  slave_o.rty <= '0';

  desc_o <= (others => '0');
  
end rtl;
