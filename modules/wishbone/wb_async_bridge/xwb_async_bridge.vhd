------------------------------------------------------------------------------
-- Title      : Atmel EBI asynchronous bus <-> Wishbone bridge
-- Project    : White Rabbit Switch
------------------------------------------------------------------------------
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-05-18
-- Last update: 2011-09-23
-- Platform   : FPGA-generic
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Copyright (c) 2010 CERN
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

library ieee;
use ieee.std_logic_1164.all;
use work.wishbone_pkg.all;

entity xwb_async_bridge is
  generic (
    g_simulation          : integer := 0;
    g_interface_mode      : t_wishbone_interface_mode;
    g_address_granularity : t_wishbone_address_granularity;
    g_cpu_address_width: integer := 32);
  port(
    rst_n_i   : in std_logic;           -- global reset
    clk_sys_i : in std_logic;           -- system clock

-------------------------------------------------------------------------------
-- Atmel EBI bus
-------------------------------------------------------------------------------

    cpu_cs_n_i : in std_logic;
-- async write, active LOW
    cpu_wr_n_i : in std_logic;
-- async read, active LOW
    cpu_rd_n_i : in std_logic;
-- byte select, active  LOW (not used due to weird CPU pin layout - NBS2 line is
-- shared with 100 Mbps Ethernet PHY)
    cpu_bs_n_i : in std_logic_vector(3 downto 0);

-- address input
    cpu_addr_i : in std_logic_vector(g_cpu_address_width-1 downto 0);

-- data bus (bidirectional)
    cpu_data_b : inout std_logic_vector(31 downto 0);

-- async wait, active LOW
    cpu_nwait_o : out std_logic;

-------------------------------------------------------------------------------
-- Wishbone master I/F 
-------------------------------------------------------------------------------
    master_o : out t_wishbone_master_out;
    master_i : in  t_wishbone_master_in
    );

end xwb_async_bridge;

architecture wrapper of xwb_async_bridge is

begin

  U_Wrapped_Bridge : wb_async_bridge
    generic map (
      g_simulation          => g_simulation,
      g_interface_mode      => g_interface_mode,
      g_address_granularity => g_address_granularity,
      g_cpu_address_width => g_cpu_address_width)
    port map (
      rst_n_i     => rst_n_i,
      clk_sys_i   => clk_sys_i,
      cpu_cs_n_i  => cpu_cs_n_i,
      cpu_wr_n_i  => cpu_wr_n_i,
      cpu_rd_n_i  => cpu_rd_n_i,
      cpu_bs_n_i  => cpu_bs_n_i,
      cpu_addr_i  => cpu_addr_i,
      cpu_data_b  => cpu_data_b,
      cpu_nwait_o => cpu_nwait_o,
      wb_adr_o    => master_o.adr,
      wb_dat_o    => master_o.dat,
      wb_stb_o    => master_o.stb,
      wb_we_o     => master_o.we,
      wb_sel_o    => master_o.sel,
      wb_cyc_o    => master_o.cyc,
      wb_dat_i    => master_i.dat,
      wb_ack_i    => master_i.ack);

end wrapper;
