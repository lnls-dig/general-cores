-------------------------------------------------------------------------------
-- Title      : General cores VHDL package
-- Project    : General Cores library
-------------------------------------------------------------------------------
-- File       : gencores_pkg.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN
-- Created    : 2009-09-01
-- Last update: 2012-03-12
-- Platform   : FPGA-generic
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description:
-- Package incorporating simple VHDL modules, which are used 
-- in the WR and other OHWR projects.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2009-2012 CERN
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

use work.genram_pkg.all;

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
      g_polynomial              : std_logic_vector       := x"04C11DB7";
      g_init_value              : std_logic_vector       := x"ffffffff";
      g_residue                 : std_logic_vector       := x"38fb2284";
      g_data_width              : integer range 2 to 256 := 16;
      g_half_width              : integer range 2 to 256 := 8;
      g_sync_reset              : integer range 0 to 1   := 1;
      g_dual_width              : integer range 0 to 1   := 0;
      g_registered_match_output : boolean                := true);
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
      g_sync_edge : string := "positive");
    port (
      clk_i    : in  std_logic;
      rst_n_i  : in  std_logic;
      data_i   : in  std_logic;
      synced_o : out std_logic;
      npulse_o : out std_logic;
      ppulse_o : out std_logic);
  end component;

  component gc_pulse_synchronizer
    port (
      clk_in_i  : in  std_logic;
      clk_out_i : in  std_logic;
      rst_n_i   : in  std_logic;
      d_ready_o : out std_logic;
      d_p_i     : in  std_logic;
      q_p_o     : out std_logic);
  end component;

  component gc_frequency_meter
    generic (
      g_with_internal_timebase : boolean;
      g_clk_sys_freq           : integer;
      g_counter_bits           : integer);
    port (
      clk_sys_i    : in  std_logic;
      clk_in_i     : in  std_logic;
      rst_n_i      : in  std_logic;
      pps_p1_i     : in  std_logic;
      freq_o       : out std_logic_vector(g_counter_bits-1 downto 0);
      freq_valid_o : out std_logic);
  end component;

  component gc_arbitrated_mux
    generic (
      g_num_inputs : integer;
      g_width      : integer);
    port (
      clk_i        : in  std_logic;
      rst_n_i      : in  std_logic;
      d_i          : in  std_logic_vector(g_num_inputs * g_width-1 downto 0);
      d_valid_i    : in  std_logic_vector(g_num_inputs-1 downto 0);
      d_req_o      : out std_logic_vector(g_num_inputs-1 downto 0);
      q_o          : out std_logic_vector(g_width-1 downto 0);
      q_valid_o    : out std_logic;
      q_input_id_o : out std_logic_vector(f_log2_size(g_num_inputs)-1 downto 0));
  end component;
  
  -- Read during write has an undefined result
  component gc_dual_clock_ram is
    generic(
      addr_width : natural := 4;
      data_width : natural := 32);
    port(
      -- write port
      w_clk_i  : in  std_logic;
      w_en_i   : in  std_logic;
      w_addr_i : in  std_logic_vector(addr_width-1 downto 0);
      w_data_i : in  std_logic_vector(data_width-1 downto 0);
      -- read port
      r_clk_i  : in  std_logic;
      r_en_i   : in  std_logic;
      r_addr_i : in  std_logic_vector(addr_width-1 downto 0);
      r_data_o : out std_logic_vector(data_width-1 downto 0));
  end component;
  
  -- A 'Wes' FIFO. Generic FIFO using inferred memory.
  -- Supports clock domain crossing 
  -- Should be safe from fast->slow or reversed
  -- Set sync_depth := 0 and gray_code := false if only one clock
  component gc_wfifo is
    generic(
      sync_depth : natural := 3;
      gray_code  : boolean := true;
      addr_width : natural := 4;
      data_width : natural := 32);
    port(
      rst_n_i  : in  std_logic;
      -- write port, only set w_en when w_rdy
      w_clk_i  : in  std_logic;
      w_rdy_o  : out std_logic;
      w_en_i   : in  std_logic;
      w_data_i : in  std_logic_vector(data_width-1 downto 0);
      -- (pre)alloc port, can be unused
      a_clk_i  : in  std_logic;
      a_rdy_o  : out std_logic;
      a_en_i   : in  std_logic;
      -- read port, only set r_en when r_rdy
      -- data is valid the cycle after r_en raised
      r_clk_i  : in  std_logic;
      r_rdy_o  : out std_logic;
      r_en_i   : in  std_logic;
      r_data_o : out std_logic_vector(data_width-1 downto 0));
  end component;
 
  procedure f_rr_arbitrate (
    signal req       : in  std_logic_vector;
    signal pre_grant : in  std_logic_vector;
    signal grant     : out std_logic_vector);

end package;

package body gencores_pkg is

-- Simple round-robin arbiter:
-- req = requests (1 = pending request),
-- pre_grant = previous grant vector (1 cycle delay)
-- grant = new grant vector
  
  procedure f_rr_arbitrate (
    signal req       : in  std_logic_vector;
    signal pre_grant : in  std_logic_vector;
    signal grant     : out std_logic_vector)is

    variable reqs  : std_logic_vector(req'length - 1 downto 0);
    variable gnts  : std_logic_vector(req'length - 1 downto 0);
    variable gnt   : std_logic_vector(req'length - 1 downto 0);
    variable gntM  : std_logic_vector(req'length - 1 downto 0);
    variable zeros : std_logic_vector(req'length - 1 downto 0);
    
  begin
    zeros := (others => '0');

    -- bit twiddling magic :
    gnt  := req and std_logic_vector(unsigned(not req) + 1);
    reqs := req and not (std_logic_vector(unsigned(pre_grant) - 1) or pre_grant);
    gnts := reqs and std_logic_vector(unsigned(not reqs)+1);

    if(reqs = zeros) then
      gntM := gnt;
    else
      gntM := gnts;
    end if;

    if((req and pre_grant) = zeros) then
      grant <= gntM;
    else
      grant <= pre_grant;
    end if;
    
  end f_rr_arbitrate;

end gencores_pkg;

