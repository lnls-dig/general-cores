-------------------------------------------------------------------------------
-- Title      : Simple Wishbone PWM Controller
-- Project    : General Cores Collection (gencores) library
-------------------------------------------------------------------------------
-- File       : xwb_simple_pwm.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2012-12-18
-- Last update: 2013-09-10
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: A simple PWM controller, supporting up to 8 channels. Aside from
-- duty cycle control, all channels share period and base frequency settings,
-- contrillable via Wishbone
-------------------------------------------------------------------------------
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
--
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.wishbone_pkg.all;



entity xwb_simple_pwm is
  generic (
    g_num_channels        : integer range 1 to 8;
    g_regs_size           : integer range 1 to 16 := 16;
    g_default_period      : integer range 0 to 255 := 0;
    g_default_presc       : integer range 0 to 255 := 0;
    g_default_val         : integer range 0 to 255 := 0;
    g_interface_mode      : t_wishbone_interface_mode      := PIPELINED;
    g_address_granularity : t_wishbone_address_granularity := BYTE);
  port(
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    -- Wishbone
    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;

    pwm_o : out std_logic_vector(g_num_channels-1 downto 0)
    );

end xwb_simple_pwm;

architecture wrapper of xwb_simple_pwm is

  component wb_simple_pwm
    generic (
      g_num_channels        : integer range 1 to 8;
      g_regs_size           : integer range 1 to 16 := 16;
      g_default_period      : integer range 0 to 255;
      g_default_presc       : integer range 0 to 255;
      g_default_val         : integer range 0 to 255;
      g_interface_mode      : t_wishbone_interface_mode;
      g_address_granularity : t_wishbone_address_granularity);
    port (
      clk_sys_i  : in  std_logic;
      rst_n_i    : in  std_logic;
      wb_adr_i   : in  std_logic_vector(5 downto 0);
      wb_dat_i   : in  std_logic_vector(31 downto 0);
      wb_dat_o   : out std_logic_vector(31 downto 0);
      wb_cyc_i   : in  std_logic;
      wb_sel_i   : in  std_logic_vector(3 downto 0);
      wb_stb_i   : in  std_logic;
      wb_we_i    : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_stall_o : out std_logic;
      pwm_o      : out std_logic_vector(g_num_channels-1 downto 0));
  end component;
  
begin  -- rtl

  U_Wrapped_PWM : wb_simple_pwm
    generic map (
      g_num_channels        => g_num_channels,
      g_regs_size           => g_regs_size,
      g_default_period      => g_default_period,
      g_default_presc       => g_default_presc,
      g_default_val         => g_default_val,
      g_interface_mode      => g_interface_mode,
      g_address_granularity => g_address_granularity)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      wb_adr_i   => slave_i.adr(5 downto 0),
      wb_dat_i   => slave_i.dat,
      wb_dat_o   => slave_o.dat,
      wb_cyc_i   => slave_i.cyc,
      wb_sel_i   => slave_i.sel,
      wb_stb_i   => slave_i.stb,
      wb_we_i    => slave_i.we,
      wb_ack_o   => slave_o.ack,
      wb_stall_o => slave_o.stall,
      pwm_o      => pwm_o);

  slave_o.err <= '0';
  slave_o.rty <= '0';
  slave_o.int <= '0';
  
end wrapper;
