------------------------------------------------------------------------------
-- Title      : Wishbone GPIO port wrapper
-- Project    : General Core Collection (gencores) Library
------------------------------------------------------------------------------
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-05-18
-- Last update: 2017-10-11
-- Platform   : FPGA-generic
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Copyright (c) 2010 - 2017 CERN
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

entity xwb_gpio_port is
  generic(
    g_interface_mode         : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity    : t_wishbone_address_granularity := WORD;
    g_num_pins               : natural range 1 to 256         := 32;
    g_with_builtin_tristates : boolean                        := false
    );

  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    -- Wishbone
    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;
    desc_o  : out t_wishbone_device_descriptor;

    gpio_b : inout std_logic_vector(g_num_pins-1 downto 0);

    gpio_out_o : out std_logic_vector(g_num_pins-1 downto 0);
    gpio_in_i  : in  std_logic_vector(g_num_pins-1 downto 0);
    gpio_oen_o : out std_logic_vector(g_num_pins-1 downto 0)

    );

end xwb_gpio_port;

architecture rtl of xwb_gpio_port is

  component wb_gpio_port
    generic (
      g_interface_mode         : t_wishbone_interface_mode;
      g_address_granularity    : t_wishbone_address_granularity;
      g_num_pins               : natural range 1 to 256;
      g_with_builtin_tristates : boolean);
    port (
      clk_sys_i  : in    std_logic;
      rst_n_i    : in    std_logic;
      wb_sel_i   : in    std_logic_vector(c_wishbone_data_width/8-1 downto 0);
      wb_cyc_i   : in    std_logic;
      wb_stb_i   : in    std_logic;
      wb_we_i    : in    std_logic;
      wb_adr_i   : in    std_logic_vector(7 downto 0);
      wb_dat_i   : in    std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_dat_o   : out   std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_ack_o   : out   std_logic;
      wb_stall_o : out   std_logic;
      gpio_b     : inout std_logic_vector(g_num_pins-1 downto 0);
      gpio_out_o : out   std_logic_vector(g_num_pins-1 downto 0);
      gpio_in_i  : in    std_logic_vector(g_num_pins-1 downto 0);
      gpio_oen_o : out   std_logic_vector(g_num_pins-1 downto 0));
  end component;
begin  -- rtl
  

  Wrapped_GPIO : wb_gpio_port
    generic map (
      g_num_pins               => g_num_pins,
      g_with_builtin_tristates => g_with_builtin_tristates,
      g_interface_mode         => g_interface_mode,
      g_address_granularity    => g_address_granularity)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      wb_sel_i   => slave_i.sel,
      wb_cyc_i   => slave_i.cyc,
      wb_stb_i   => slave_i.stb,
      wb_we_i    => slave_i.we,
      wb_adr_i   => slave_i.adr(7 downto 0),
      wb_dat_i   => slave_i.dat(31 downto 0),
      wb_dat_o   => slave_o.dat(31 downto 0),
      wb_ack_o   => slave_o.ack,
      wb_stall_o => slave_o.stall,

      gpio_b     => gpio_b,
      gpio_out_o => gpio_out_o,
      gpio_in_i  => gpio_in_i,
      gpio_oen_o => gpio_oen_o);

  slave_o.err   <= '0';
  slave_o.int   <= '0';
  slave_o.rty   <= '0';
  
end rtl;
