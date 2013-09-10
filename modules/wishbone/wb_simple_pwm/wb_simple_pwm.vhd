-------------------------------------------------------------------------------
-- Title      : Simple Wishbone PWM Controller
-- Project    : General Cores Collection (gencores) library
-------------------------------------------------------------------------------
-- File       : wb_simple_pwm.vhd
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
use ieee.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;

use work.wishbone_pkg.all;
use work.spwm_wbgen2_pkg.all;

entity wb_simple_pwm is
  generic(
    g_num_channels        : integer range 1 to 8;
    g_regs_size           : integer range 1 to 16 := 16;
    g_default_period      : integer range 0 to 255 := 0;
    g_default_presc       : integer range 0 to 255 := 0;
    g_default_val         : integer range 0 to 255 := 0;
    g_interface_mode      : t_wishbone_interface_mode      := PIPELINED;
    g_address_granularity : t_wishbone_address_granularity := BYTE
    );
  port (

    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    wb_adr_i   : in  std_logic_vector(5 downto 0);
    wb_dat_i   : in  std_logic_vector(31 downto 0);
    wb_dat_o   : out std_logic_vector(31 downto 0);
    wb_cyc_i   : in  std_logic;
    wb_sel_i   : in  std_logic_vector(3 downto 0);
    wb_stb_i   : in  std_logic;
    wb_we_i    : in  std_logic;
    wb_ack_o   : out std_logic;
    wb_stall_o : out std_logic;

    pwm_o : out std_logic_vector(g_num_channels-1 downto 0)
    );
end wb_simple_pwm;

architecture behavioral of wb_simple_pwm is

  type t_drive_array is array(0 to g_num_channels-1) of std_logic_vector(g_regs_size-1 downto 0);

  procedure f_handle_dr_writes(index :     integer; data : std_logic_vector; load : std_logic;
  signal d                           : out t_drive_array) is
  begin
    if(index <= g_num_channels and load = '1') then
      d(index-1) <= data(g_regs_size-1 downto 0);
    end if;
  end f_handle_dr_writes;

  function f_expand_data(dat : std_logic_vector(g_regs_size-1 downto 0))
    return std_logic_vector is
    variable ret  : std_logic_vector(15 downto 0);
  begin
    if g_regs_size = 16 then
      ret := dat;
    else
      ret(g_regs_size-1 downto 0) := dat;
      ret(15 downto g_regs_size)  := (others=>'0');
    end if;
    return ret;
  end function;

  component simple_pwm_wb
    port (
      rst_n_i    : in  std_logic;
      clk_sys_i  : in  std_logic;
      wb_adr_i   : in  std_logic_vector(3 downto 0);
      wb_dat_i   : in  std_logic_vector(31 downto 0);
      wb_dat_o   : out std_logic_vector(31 downto 0);
      wb_cyc_i   : in  std_logic;
      wb_sel_i   : in  std_logic_vector(3 downto 0);
      wb_stb_i   : in  std_logic;
      wb_we_i    : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_stall_o : out std_logic;
      regs_i     : in  t_spwm_in_registers;
      regs_o     : out t_spwm_out_registers);
  end component;

  signal drive : t_drive_array;

  signal regs_in  : t_spwm_in_registers;
  signal regs_out : t_spwm_out_registers;

  signal tick                : std_logic;
  signal cntr_pre, cntr_main : unsigned(g_regs_size-1 downto 0);
  signal presc_val   : std_logic_vector(g_regs_size-1 downto 0);
  signal period_val  : std_logic_vector(g_regs_size-1 downto 0);
  
begin  -- behavioral

  U_WB_Slave : simple_pwm_wb
    port map (
      rst_n_i    => rst_n_i,
      clk_sys_i  => clk_sys_i,
      wb_adr_i   => wb_adr_i(5 downto 2),
      wb_dat_i   => wb_dat_i,
      wb_dat_o   => wb_dat_o,
      wb_cyc_i   => wb_cyc_i,
      wb_sel_i   => wb_sel_i,
      wb_stb_i   => wb_stb_i,
      wb_we_i    => wb_we_i,
      wb_ack_o   => wb_ack_o,
      wb_stall_o => wb_stall_o,
      regs_i     => regs_in,
      regs_o     => regs_out);

-------------------------------------------------------------------------------
-- FIXME: this is ugly. Add register array support in wbgen2!
-------------------------------------------------------------------------------
  p_drive_readback : process(drive)
  begin
    regs_in.dr0_i <= f_expand_data(drive(0));

    if(g_num_channels >= 2) then
      regs_in.dr1_i <= f_expand_data(drive(1));
    end if;
    if(g_num_channels >= 3) then
      regs_in.dr2_i <= f_expand_data(drive(2));
    end if;
    if(g_num_channels >= 4) then
      regs_in.dr3_i <= f_expand_data(drive(3));
    end if;
    if(g_num_channels >= 5) then
      regs_in.dr4_i <= f_expand_data(drive(4));
    end if;
    if(g_num_channels >= 6) then
      regs_in.dr5_i <= f_expand_data(drive(5));
    end if;
    if(g_num_channels >= 7) then
      regs_in.dr6_i <= f_expand_data(drive(6));
    end if;
    if(g_num_channels >= 8) then
      regs_in.dr7_i <= f_expand_data(drive(7));
    end if;
  end process;

  p_drive_write : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        for i in 0 to g_num_channels-1 loop
          drive(i) <= std_logic_vector(to_unsigned(g_default_val, g_regs_size));
        end loop;  -- i
      else
        f_handle_dr_writes(1, regs_out.dr0_o, regs_out.dr0_load_o, drive);
        f_handle_dr_writes(2, regs_out.dr1_o, regs_out.dr1_load_o, drive);
        f_handle_dr_writes(3, regs_out.dr2_o, regs_out.dr2_load_o, drive);
        f_handle_dr_writes(4, regs_out.dr3_o, regs_out.dr3_load_o, drive);
        f_handle_dr_writes(5, regs_out.dr4_o, regs_out.dr4_load_o, drive);
        f_handle_dr_writes(6, regs_out.dr5_o, regs_out.dr5_load_o, drive);
        f_handle_dr_writes(7, regs_out.dr6_o, regs_out.dr6_load_o, drive);
        f_handle_dr_writes(8, regs_out.dr7_o, regs_out.dr7_load_o, drive);
      end if;
    end if;
  end process;

  regs_in.cr_presc_i  <= f_expand_data(presc_val);
  regs_in.cr_period_i <= f_expand_data(period_val);
  load_cr: process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if(rst_n_i = '0') then
        presc_val  <= std_logic_vector(to_unsigned(g_default_presc, g_regs_size));
      elsif(regs_out.cr_presc_load_o = '1') then
        presc_val <= regs_out.cr_presc_o(g_regs_size-1 downto 0);
      end if;

      if(rst_n_i = '0') then
        period_val <= std_logic_vector(to_unsigned(g_default_period, g_regs_size));
      elsif(regs_out.cr_period_load_o = '1') then
        period_val <= regs_out.cr_period_o(g_regs_size-1 downto 0);
      end if;
    end if;
  end process;

  p_prescaler : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' or std_logic_vector(cntr_pre) = presc_val then
        cntr_pre <= (others => '0');
        tick     <= '1';
      else
        cntr_pre <= cntr_pre + 1;
        tick     <= '0';
      end if;
    end if;
  end process;

  p_main_counter : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if (tick = '1' and std_logic_vector(cntr_main) = period_val) or rst_n_i = '0' then
        cntr_main <= (others => '0');
      elsif(tick = '1') then
        cntr_main <= cntr_main + 1;
      end if;
    end if;
  end process;

  p_comparators : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        pwm_o <= (others => '0');
      else
        for i in 0 to g_num_channels-1 loop
          if(cntr_main < unsigned(drive(i))) then
            pwm_o(i) <= '1';
          else
            pwm_o(i) <= '0';
          end if;
        end loop;  -- i 
      end if;
    end if;
  end process;

end behavioral;
