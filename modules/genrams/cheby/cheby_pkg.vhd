-------------------------------------------------------------------------------
-- Title      : Cheby components
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : cheby_pkg.vhd
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
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

package cheby_pkg is

  
  component cheby_dpssram
    generic (
      g_data_width : natural;
      g_size       : natural;
      g_addr_width : natural;
      g_dual_clock : std_logic;
      g_use_bwsel  : std_logic);
    port (
      clk_a_i   : in  std_logic;
      clk_b_i   : in  std_logic;
      addr_a_i  : in  std_logic_vector(g_addr_width-1 downto 0);
      addr_b_i  : in  std_logic_vector(g_addr_width-1 downto 0);
      data_a_i  : in  std_logic_vector(g_data_width-1 downto 0);
      data_b_i  : in  std_logic_vector(g_data_width-1 downto 0);
      data_a_o  : out std_logic_vector(g_data_width-1 downto 0);
      data_b_o  : out std_logic_vector(g_data_width-1 downto 0);
      bwsel_a_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
      bwsel_b_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
      rd_a_i    : in  std_logic;
      rd_b_i    : in  std_logic;
      wr_a_i    : in  std_logic;
      wr_b_i    : in  std_logic);
  end component;
end cheby_pkg;
