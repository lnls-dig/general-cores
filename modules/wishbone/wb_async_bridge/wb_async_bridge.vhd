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
-- Description: An interface between AT91SAM9x-series ARM CPU External Bus Interface
-- and FPGA-internal Wishbone bus:
-- - does clock domain synchronisation
-- - provides configurable number of independent WB master ports at fixed base addresses
-- TODO:
-- - implement write queueing and read prefetching (for speed improvement)
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
-- Revisions  :
-- Date        Version  Author          Description
-- 2010-05-18  1.0      twlostow        Created
-- 2011-09-21  1.1      twlostow        Added support for pipelined mode
-------------------------------------------------------------------------------

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.log2;
use ieee.math_real.ceil;

use work.gencores_pkg.all;
use work.wishbone_pkg.all;

entity wb_async_bridge is
  generic (
    g_simulation          : integer := 0;
    g_interface_mode      : t_wishbone_interface_mode;
    g_address_granularity : t_wishbone_address_granularity;
    g_cpu_address_width   : integer := 32);
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

-- wishbone master address output (m->s, common for all slaves)
    wb_adr_o : out std_logic_vector(c_wishbone_address_width - 1 downto 0);
-- wishbone master data output (m->s common for all slaves)
    wb_dat_o : out std_logic_vector(31 downto 0);
-- wishbone cycle strobe (m->s, common for all slaves)
    wb_stb_o : out std_logic;
-- wishbone write enable (m->s, common for all slaves)
    wb_we_o  : out std_logic;
-- wishbone byte select output (m->s, common for all slaves)
    wb_sel_o : out std_logic_vector(3 downto 0);

-- wishbone cycle select (m->s)
    wb_cyc_o   : out std_logic;
-- wishbone master data input (s->m)
    wb_dat_i   : in  std_logic_vector (c_wishbone_data_width-1 downto 0);
-- wishbone ACK input (s->m)
    wb_ack_i   : in  std_logic;
    wb_stall_i : in  std_logic
    );

end wb_async_bridge;

architecture behavioral of wb_async_bridge is

  signal rw_sel, cycle_in_progress, cs_synced, rd_pulse, wr_pulse : std_logic;
  signal cpu_data_reg                                             : std_logic_vector(31 downto 0);
  signal long_cycle                                               : std_logic;

  signal wb_in  : t_wishbone_master_in;
  signal wb_out : t_wishbone_master_out;
begin

  U_Adapter : wb_slave_adapter
    generic map (
      g_master_use_struct  => false,
      g_master_mode        => g_interface_mode,
      g_master_granularity => g_address_granularity,
      g_slave_use_struct   => true,
      g_slave_mode         => CLASSIC,
      g_slave_granularity  => WORD)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      slave_i    => wb_out,
      slave_o    => wb_in,
      ma_adr_o   => wb_adr_o,
      ma_dat_o   => wb_dat_o,
      ma_sel_o   => wb_sel_o,
      ma_cyc_o   => wb_cyc_o,
      ma_stb_o   => wb_stb_o,
      ma_we_o    => wb_we_o,
      ma_dat_i   => wb_dat_i,
      ma_ack_i   => wb_ack_i,
      ma_stall_i => wb_stall_i);

  gen_sync_chains_nosim : if(g_simulation = 0) generate

    sync_ffs_cs : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map
      (rst_n_i  => rst_n_i,
       clk_i    => clk_sys_i,
       data_i   => cpu_cs_n_i,
       synced_o => cs_synced,
       npulse_o => open
       );

    sync_ffs_wr : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        rst_n_i  => rst_n_i,
        clk_i    => clk_sys_i,
        data_i   => cpu_wr_n_i,
        synced_o => open,
        npulse_o => wr_pulse
        );

    sync_ffs_rd : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        rst_n_i  => rst_n_i,
        clk_i    => clk_sys_i,
        data_i   => cpu_rd_n_i,
        synced_o => open,
        npulse_o => rd_pulse
        );

  end generate gen_sync_chains_nosim;

  gen_sim : if(g_simulation = 1) generate
    wr_pulse  <= not cpu_wr_n_i;
    rd_pulse  <= not cpu_rd_n_i;
    cs_synced <= cpu_cs_n_i;
  end generate gen_sim;

  process(clk_sys_i)
  begin
    if(rising_edge(clk_sys_i)) then
      if(rst_n_i = '0') then
        cpu_data_reg      <= (others => '0');
        cycle_in_progress <= '0';
        rw_sel            <= '0';
        cpu_nwait_o       <= '1';
        long_cycle        <= '0';

        wb_out.adr <= (others => '0');
        wb_out.dat <= (others => '0');
        wb_out.sel <= (others => '1');
        wb_out.stb <= '0';
        wb_out.we  <= '0';
        wb_out.cyc <= '0';

      else

        if(cs_synced = '0') then

          wb_out.adr <= std_logic_vector(resize(unsigned(cpu_addr_i), c_wishbone_address_width));

          if(cycle_in_progress = '1') then
            if(wb_in.ack = '1') then

              if(rw_sel = '0') then
                cpu_data_reg <= wb_in.dat;
              end if;

              cycle_in_progress <= '0';
              wb_out.cyc          <= '0';
              wb_out.sel          <= (others => '1');
              wb_out.stb          <= '0';
              wb_out.we           <= '0';
              cpu_nwait_o       <= '1';
              long_cycle        <= '0';
              
            else
              cpu_nwait_o <= not long_cycle;
              long_cycle  <= '1';
            end if;
            
          elsif(rd_pulse = '1' or wr_pulse = '1') then
            wb_out.cyc <= '1';
            wb_out.stb <= '1';
            wb_out.we  <= wr_pulse;

            long_cycle <= '0';
            rw_sel     <= wr_pulse;

            if(wr_pulse = '1') then
              wb_out.dat <= cpu_data_b;
            end if;

            cycle_in_progress <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  process(cpu_cs_n_i, cpu_rd_n_i, cpu_data_reg)
  begin
    if(cpu_cs_n_i = '0' and cpu_rd_n_i = '0') then
      cpu_data_b <= cpu_data_reg;
    else
      cpu_data_b <= (others => 'Z');
    end if;
  end process;

end behavioral;
