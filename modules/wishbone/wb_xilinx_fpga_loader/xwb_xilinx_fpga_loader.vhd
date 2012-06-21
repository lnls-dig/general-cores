-------------------------------------------------------------------------------
-- Title        : Xilinx FPGA Loader
-- Project      : General Cores Library
-------------------------------------------------------------------------------
-- File         : xwb_xilinx_fpga_loader.vhd
-- Author       : Tomasz Włostowski
-- Company      : CERN BE-CO-HT
-- Created      : 2012-01-30
-- Last update  : 2012-01-30
-- Platform     : FPGA-generic
-- Standard     : VHDL '93
-- Dependencies : wishbone_pkg, wb_xilinx_fpga_loader
-------------------------------------------------------------------------------
-- Description: Wishbone compatible Xilinx serial port bitstream loader
-- (structized ports wrapper)
-------------------------------------------------------------------------------
--
-- Copyright (c) 2012 CERN
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
-- Revisions  :
-- Date        Version  Author          Description
-- 2012-01-30  1.0      twlostow        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.STD_LOGIC_1164.all;

use work.wishbone_pkg.all;

entity xwb_xilinx_fpga_loader is

  generic (
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD;
    g_idr_value           : std_logic_vector(31 downto 0)  := x"626f6f74"
    );

  port (
    clk_sys_i : in  std_logic;
    rst_n_i   : in  std_logic;
    slave_i   : in  t_wishbone_slave_in;
    slave_o   : out t_wishbone_slave_out;
    desc_o    : out t_wishbone_device_descriptor;

    xlx_cclk_o      : out std_logic := '0';
    xlx_din_o       : out std_logic;
    xlx_program_b_o : out std_logic := '1';
    xlx_init_b_i    : in  std_logic;
    xlx_done_i      : in  std_logic;
    xlx_suspend_o   : out std_logic;

    xlx_m_o : out std_logic_vector(1 downto 0);

    -- 1-pulse: boot trigger sequence detected
    boot_trig_p1_o : out std_logic;

    -- 1-pulse: exit bootloader mode
    boot_exit_p1_o : out std_logic;

    -- 1: enable bootloader
    -- 0: disable bootloader (all WB writes except for the trigger register are
    -- ignored)
    boot_en_i : in std_logic;

    gpio_o : out std_logic_vector(7 downto 0)
    );

end xwb_xilinx_fpga_loader;

architecture rtl of xwb_xilinx_fpga_loader is

  component wb_xilinx_fpga_loader
    generic (
      g_interface_mode      : t_wishbone_interface_mode;
      g_address_granularity : t_wishbone_address_granularity;
      g_idr_value           : std_logic_vector(31 downto 0)
      );
    port (
      clk_sys_i       : in  std_logic;
      rst_n_i         : in  std_logic;
      wb_cyc_i        : in  std_logic;
      wb_stb_i        : in  std_logic;
      wb_we_i         : in  std_logic;
      wb_adr_i        : in  std_logic_vector(c_wishbone_address_width - 1 downto 0);
      wb_sel_i        : in  std_logic_vector((c_wishbone_data_width + 7) / 8 - 1 downto 0);
      wb_dat_i        : in  std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_dat_o        : out std_logic_vector(c_wishbone_data_width-1 downto 0);
      wb_ack_o        : out std_logic;
      wb_stall_o      : out std_logic;
      xlx_cclk_o      : out std_logic := '0';
      xlx_din_o       : out std_logic;
      xlx_program_b_o : out std_logic := '1';
      xlx_init_b_i    : in  std_logic;
      xlx_done_i      : in  std_logic;
      xlx_suspend_o   : out std_logic;
      xlx_m_o         : out std_logic_vector(1 downto 0);
      boot_trig_p1_o  : out std_logic;
      boot_exit_p1_o  : out std_logic;
      boot_en_i       : in  std_logic;
      gpio_o          : out std_logic_vector(7 downto 0)
      );
  end component;

begin  -- rtl


  U_Wrapped_XLDR : wb_xilinx_fpga_loader
    generic map (
      g_address_granularity => g_address_granularity,
      g_interface_mode      => g_interface_mode,
      g_idr_value           => g_idr_value)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      wb_cyc_i   => slave_i.cyc,
      wb_stb_i   => slave_i.stb,
      wb_we_i    => slave_i.we,
      wb_adr_i   => slave_i.adr,
      wb_sel_i   => slave_i.sel,
      wb_dat_i   => slave_i.dat,
      wb_dat_o   => slave_o.dat,
      wb_ack_o   => slave_o.ack,
      wb_stall_o => slave_o.stall,

      xlx_cclk_o      => xlx_cclk_o,
      xlx_din_o       => xlx_din_o,
      xlx_program_b_o => xlx_program_b_o,
      xlx_init_b_i    => xlx_init_b_i,
      xlx_done_i      => xlx_done_i,
      xlx_suspend_o   => xlx_suspend_o,
      xlx_m_o         => xlx_m_o,
      boot_trig_p1_o  => boot_trig_p1_o,
      boot_exit_p1_o  => boot_exit_p1_o,
      boot_en_i       => boot_en_i,
      gpio_o          => gpio_o);

  slave_o.int <= '0';
  slave_o.err <= '0';
  slave_o.rty <= '0';
end rtl;
