-------------------------------------------------------------------------------
-- Title      : WhiteRabbit PTP Core tics wrapper
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : xwb_tics.vhd
-- Author     : Grzegorz Daniluk
-- Company    : CERN
-- Created    : 2011-04-03
-- Last update: 2013-09-13
-- Platform   : FPGA-generics
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Copyright (c) 2011-2013 CERN
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
-- todo: configurable interrupt, output compare, PWM?

library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity xwb_tics is
  generic(
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD;
    g_period              : integer
    );

  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    -- Wishbone
    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;
    desc_o  : out t_wishbone_device_descriptor

    );

end xwb_tics;

architecture rtl of xwb_tics is

  component wb_tics
    generic (
      g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
      g_address_granularity : t_wishbone_address_granularity := WORD;
      g_period : integer);
    port (
      rst_n_i    : in  std_logic;
      clk_sys_i  : in  std_logic;
      wb_adr_i   : in  std_logic_vector(3 downto 0);
      wb_dat_i   : in  std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_dat_o   : out std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_cyc_i   : in  std_logic;
      wb_sel_i   : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0);
      wb_stb_i   : in  std_logic;
      wb_we_i    : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_stall_o : out std_logic);
  end component;
  
begin

  U_Tics : wb_tics
    generic map (
      g_interface_mode      => g_interface_mode,
      g_address_granularity => g_address_granularity,
      g_period              => g_period)
    port map (
      rst_n_i    => rst_n_i,
      clk_sys_i  => clk_sys_i,
      wb_adr_i   => slave_i.adr(3 downto 0),
      wb_dat_i   => slave_i.Dat,
      wb_dat_o   => slave_o.dat,
      wb_cyc_i   => slave_i.cyc,
      wb_sel_i   => slave_i.sel,
      wb_stb_i   => slave_i.stb,
      wb_we_i    => slave_i.we,
      wb_ack_o   => slave_o.ack,
      wb_stall_o => slave_o.stall);

  slave_o.err <= '0';
  slave_o.int <= '0';
  slave_o.rty <= '0';
  
end rtl;
