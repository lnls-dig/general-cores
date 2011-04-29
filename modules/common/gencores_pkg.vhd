-------------------------------------------------------------------------------
-- Title      : General cores VHDL package
-- Project    : General Cores library
-------------------------------------------------------------------------------
-- File       : gencores_pkg.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN
-- Created    : 2009-09-01
-- Last update: 2011-04-29
-- Platform   : FPGA-generic
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description:
-- Package incorporating simple VHDL modules, which are used 
-- in the WR and other OHWR projects.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2009-2011 CERN
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
-- 2009-09-01  0.9      twlostow        Created
-- 2011-04-18  1.0      twlostow        Added comments & header
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package gencores_pkg is

  component gc_extend_pulse
    generic (
      g_width : natural);
    port (
      clk_i      : in  std_logic;
      rst_n_i    : in  std_logic;
      pulse_i    : in  std_logic;
      extended_o : out std_logic);
  end component;

  component gc_crc_gen
    generic (
      g_polynomial : std_logic_vector;
      g_init_value : std_logic_vector;
      g_residue    : std_logic_vector;
      g_data_width : integer range 2 to 256;
      g_half_width : integer range 2 to 256;
      g_sync_reset : integer range 0 to 1;
      g_dual_width : integer range 0 to 1);
    port (
      clk_i   : in  std_logic;
      rst_i   : in  std_logic;
      en_i    : in  std_logic;
      half_i  : in  std_logic;
      data_i  : in  std_logic_vector(g_data_width - 1 downto 0);
      match_o : out std_logic;
      crc_o   : out std_logic_vector(g_polynomial'length - 1 downto 0));
  end component;

  component gc_moving_average
    generic (
      g_data_width : natural;
      g_avg_log2   : natural range 1 to 8);
    port (
      rst_n_i    : in  std_logic;
      clk_i      : in  std_logic;
      din_i      : in  std_logic_vector(g_data_width-1 downto 0);
      din_stb_i  : in  std_logic;
      dout_o     : out std_logic_vector(g_data_width-1 downto 0);
      dout_stb_o : out std_logic);
  end component;

  component gc_dual_pi_controller
    generic (
      g_error_bits          : integer;
      g_dacval_bits         : integer;
      g_output_bias         : integer;
      g_integrator_fracbits : integer;
      g_integrator_overbits : integer;
      g_coef_bits           : integer);
    port (
      clk_sys_i         : in  std_logic;
      rst_n_sysclk_i    : in  std_logic;
      phase_err_i       : in  std_logic_vector(g_error_bits-1 downto 0);
      phase_err_stb_p_i : in  std_logic;
      freq_err_i        : in  std_logic_vector(g_error_bits-1 downto 0);
      freq_err_stb_p_i  : in  std_logic;
      mode_sel_i        : in  std_logic;
      dac_val_o         : out std_logic_vector(g_dacval_bits-1 downto 0);
      dac_val_stb_p_o   : out std_logic;
      pll_pcr_enable_i  : in  std_logic;
      pll_pcr_force_f_i : in  std_logic;
      pll_fbgr_f_kp_i   : in  std_logic_vector(g_coef_bits-1 downto 0);
      pll_fbgr_f_ki_i   : in  std_logic_vector(g_coef_bits-1 downto 0);
      pll_pbgr_p_kp_i   : in  std_logic_vector(g_coef_bits-1 downto 0);
      pll_pbgr_p_ki_i   : in  std_logic_vector(g_coef_bits-1 downto 0));
  end component;

    
  component gc_serial_dac
    generic (
      g_num_data_bits  : integer;
      g_num_extra_bits : integer;
      g_num_cs_select  : integer;
      g_sclk_polarity  : integer);
    port (
      clk_i         : in  std_logic;
      rst_n_i       : in  std_logic;
      value_i       : in  std_logic_vector(g_num_data_bits-1 downto 0);
      cs_sel_i      : in  std_logic_vector(g_num_cs_select-1 downto 0);
      load_i        : in  std_logic;
      sclk_divsel_i : in  std_logic_vector(2 downto 0);
      dac_cs_n_o    : out std_logic_vector(g_num_cs_select-1 downto 0);
      dac_sclk_o    : out std_logic;
      dac_sdata_o   : out std_logic;
      busy_o        : out std_logic);
  end component;        

  component gc_sync_ffs
    generic (
      g_sync_edge : string);
    port (
      clk_i    : in  std_logic;
      rst_n_i  : in  std_logic;
      data_i   : in  std_logic;
      synced_o : out std_logic;
      npulse_o : out std_logic;
      ppulse_o : out std_logic);
  end component;
  
end package;

