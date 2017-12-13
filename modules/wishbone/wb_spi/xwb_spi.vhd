-------------------------------------------------------------------------------
-- Title      : Wishbone SPI Master wrapper
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : xwb_spi.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Copyright (c) 2011-2017 CERN
--
-- This source file is free software; you can redistribute it
-- and/or modify it under the terms of the GNU Lesser General
-- Public License as published by the Free Software Foundation;
-- either version 2.1 of the License, or (at your option) any
-- later version.
--
-- This source is distributed in the hope that it will be
-- useful, but WITHOUT ANY WARRANTY; without even the implied
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
-- PURPOSE.  See the GNU Lesser General Public License for more
-- details.
--
-- You should have received a copy of the GNU Lesser General
-- Public License along with this source; if not, download it
-- from http://www.gnu.org/licenses/lgpl-2.1.html
-------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--  Modifications:
--      2016-08-24: by Jan Pospisil (j.pospisil@cern.ch)
--          * added assignments to (new) unspecified WB signals
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity xwb_spi is
  generic(
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD;
    g_divider_len         : integer := 16;
    g_max_char_len        : integer := 128;
    g_num_slaves          : integer := 8 
    );

  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    -- Wishbone
    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;
    desc_o  : out t_wishbone_device_descriptor;

    pad_cs_o   : out std_logic_vector(g_num_slaves-1 downto 0);
    pad_sclk_o : out std_logic;
    pad_mosi_o : out std_logic;
    pad_miso_i : in  std_logic
    );

end xwb_spi;

architecture rtl of xwb_spi is

  component wb_spi
    generic (
      g_interface_mode      : t_wishbone_interface_mode;
      g_address_granularity : t_wishbone_address_granularity;
      g_divider_len         : integer := 16;
      g_max_char_len        : integer := 128;
      g_num_slaves          : integer := 8);
    port (
      clk_sys_i  : in  std_logic;
      rst_n_i    : in  std_logic;
      wb_adr_i   : in  std_logic_vector(4 downto 0);
      wb_dat_i   : in  std_logic_vector(31 downto 0);
      wb_dat_o   : out std_logic_vector(31 downto 0);
      wb_sel_i   : in  std_logic_vector(3 downto 0);
      wb_stb_i   : in  std_logic;
      wb_cyc_i   : in  std_logic;
      wb_we_i    : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_err_o   : out std_logic;
      wb_int_o   : out std_logic;
      wb_stall_o : out std_logic;
      pad_cs_o   : out std_logic_vector(g_num_slaves-1 downto 0);
      pad_sclk_o : out std_logic;
      pad_mosi_o : out std_logic;
      pad_miso_i : in  std_logic);
  end component;
  
begin

  U_Wrapped_SPI: wb_spi
    generic map (
      g_interface_mode      => g_interface_mode,
      g_address_granularity => g_address_granularity,
      g_divider_len         => g_divider_len,
      g_max_char_len        => g_max_char_len,
      g_num_slaves          => g_num_slaves)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      wb_adr_i   => slave_i.adr(4 downto 0),
      wb_dat_i   => slave_i.dat,
      wb_dat_o   => slave_o.dat,
      wb_sel_i   => slave_i.sel,
      wb_stb_i   => slave_i.stb,
      wb_cyc_i   => slave_i.cyc,
      wb_we_i    => slave_i.we,
      wb_ack_o   => slave_o.ack,
      wb_err_o   => slave_o.err,
      wb_int_o   => slave_o.int,
      wb_stall_o => slave_o.stall,
      pad_cs_o   => pad_cs_o,
      pad_sclk_o => pad_sclk_o,
      pad_mosi_o => pad_mosi_o,
      pad_miso_i => pad_miso_i);

  slave_o.rty <= '0';
  
end rtl;
