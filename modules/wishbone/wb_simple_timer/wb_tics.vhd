-------------------------------------------------------------------------------
-- Title      : WhiteRabbit PTP Core tics
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_tics.vhd
-- Author     : Grzegorz Daniluk
-- Company    : CERN
-- Created    : 2011-04-03
-- Last update: 2013-09-13
-- Platform   : FPGA-generics
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description:
-- WB_TICS is a simple counter with wishbone interface. Each step of a counter
-- takes 1 usec. It is used by ptp-noposix as a replace of gettimeofday()
-- function.
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
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-04-03  1.0      greg.d          Created
-- 2011-10-04  1.1      twlostow        added wishbone adapter
-- 2013-09-13  1.2      greg.d          removed widhbone adapter, dat_o wired with counter
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;


entity wb_tics is

  generic (
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD;
    g_period : integer);
  port(
    rst_n_i : in std_logic;
    clk_sys_i : in std_logic;

    wb_adr_i : in  std_logic_vector(3 downto 0);
    wb_dat_i : in  std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_dat_o : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_cyc_i  : in  std_logic;
    wb_sel_i  : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0);
    wb_stb_i  : in  std_logic;
    wb_we_i   : in  std_logic;
    wb_ack_o  : out std_logic;
    wb_stall_o: out std_logic
    );
end wb_tics;

architecture behaviour of wb_tics is

  constant c_TICS_REG : std_logic_vector(1 downto 0) := "00";

  signal cntr_div      : unsigned(f_ceil_log2(g_period)-1 downto 0);
  signal cntr_tics     : unsigned(31 downto 0);
  signal cntr_overflow : std_logic;

begin

  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if(rst_n_i = '0') then
        cntr_div      <= (others => '0');
        cntr_overflow <= '0';
      else
        if(cntr_div = g_period-1) then
          cntr_div      <= (others => '0');
          cntr_overflow <= '1';
        else
          cntr_div      <= cntr_div + 1;
          cntr_overflow <= '0';
        end if;
      end if;
    end if;
  end process;

  --usec counter
  process(clk_sys_i)
  begin
    if(rising_edge(clk_sys_i)) then
      if(rst_n_i = '0') then
        cntr_tics <= (others => '0');
      elsif(cntr_overflow = '1') then
        cntr_tics <= cntr_tics + 1;
      end if;
    end if;
  end process;

  --Wishbone interface
  wb_dat_o   <= std_logic_vector(cntr_tics);
  wb_ack_o   <= wb_stb_i and wb_cyc_i;
  wb_stall_o <= '0';

  --process(clk_sys_i)
  --begin
  --  if rising_edge(clk_sys_i) then
  --    if(rst_n_i = '0') then
  --      wb_out.ack  <= '0';
  --      wb_out.dat <= (others => '0');
  --    else
  --      if(wb_in.stb = '1' and wb_in.cyc = '1') then
  --        if(wb_in.we = '0') then
  --          case wb_in.adr(1 downto 0) is
  --            when c_TICS_REG =>
  --              wb_out.dat <= std_logic_vector(cntr_tics);
  --            when others =>
  --              wb_out.dat <= (others => '0');
  --          end case;
  --        end if;
  --        wb_out.ack <= '1';
  --      else
  --        wb_out.dat <= (others => '0');
  --        wb_out.ack  <= '0';
  --      end if;
  --    end if;
  --  end if;
  --end process;

end behaviour;
