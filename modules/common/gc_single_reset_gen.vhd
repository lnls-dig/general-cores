-------------------------------------------------------------------------------
-- Title      : Generic generation of synchronous reset for one clock domain
-------------------------------------------------------------------------------
-- File       : gc_single_reset_gen.vhd
-- Author     : Tomasz Wlostowski, Maciej Lipinski
-- Company    : CERN
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description:
--
-- This module generates a synchronous negative pulse reset from a vector of
-- asynchronous inputs (e.g. the PCIe bus powerup reset and SPEC button reset).
--
-- It was importent from wr-cores/top/spec_1_1/wr_core_demo/spec_reset_gen.vhd
--
-------------------------------------------------------------------------------
--
-- Copyright (c) 2016 CERN/BE-CO-HT
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
-- details
--
-- You should have received a copy of the GNU Lesser General
-- Public License along with this source; if not, download it
-- from http://www.gnu.org/licenses/lgpl-2.1.html
--
-------------------------------------------------------------------------------

library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.NUMERIC_STD.all;

use work.gencores_pkg.all;

entity gc_single_reset_gen is
  generic(
    -- number of flip-flops before the final signals' output
    g_out_reg_depth   : natural :=2;

    -- number of input asynchronous reset signals
    g_rst_in_num     : natural :=2);
  port (
    -- clock with which the output reset signal is synchronised
    clk_i                  : in std_logic;

    -- input asynch reset signals
    rst_signals_n_a_i      : in std_logic_vector(g_rst_in_num-1 downto 0);

    -- synchronous output reset signal
    rst_n_o                : out std_logic
    );

end gc_single_reset_gen;

architecture behavioral of gc_single_reset_gen is

  signal powerup_cnt          : unsigned(7 downto 0)                            := x"00";
  signal rst_signals_synced_n : std_logic_vector(g_rst_in_num-1 downto 0)   := (others => '0');
  signal ones                 : std_logic_vector(g_rst_in_num-1 downto 0)   := (others => '1');
  signal rst_powerup_n        : std_logic                                   := '0';
  signal rst_n                : std_logic;
  signal rst_n_shifter        : std_logic_vector(g_out_reg_depth-1 downto 0):= (others => '0');

begin  -- behavioral

  -- we all love VHDL...
  ones <= (others=>'1');

  -------------------------------------------------------------------------------------------
  -- synchronise input reset signals with the system clock domain
  -------------------------------------------------------------------------------------------
  gen_synch_inputs:  for i in 0 to g_rst_in_num-1  generate
    U_EdgeDet_PCIe : gc_sync_ffs port map (
      clk_i    => clk_i,
      rst_n_i  => '1',
      data_i   => rst_signals_n_a_i(i),
      synced_o => rst_signals_synced_n(i));
  end generate gen_synch_inputs;

  -------------------------------------------------------------------------------------------
  -- produce a powerup reset
  -------------------------------------------------------------------------------------------
  p_powerup_reset : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if(powerup_cnt /= x"ff") then
        powerup_cnt <= powerup_cnt + 1;
        rst_powerup_n   <= '0';
      else
        rst_powerup_n <= '1';
      end if;
    end if;
  end process;

  -------------------------------------------------------------------------------------------
  -- final reset signal
  -------------------------------------------------------------------------------------------
  rst_n    <= '1' when (rst_powerup_n = '1' and rst_signals_synced_n = ones) else '0';

  -------------------------------------------------------------------------------------------
  -- Pass through few flip-flops before it goes into an FPGA-wide fun-out
  -- (a configurable number of register)
  -------------------------------------------------------------------------------------------
  p_out_rst_shift_reg: process(clk_i)
  begin
    if rising_edge(clk_i) then
      rst_n_shifter <= rst_n & rst_n_shifter(g_out_reg_depth-1 downto 1);
    end if;
  end process;

  -------------------------------------------------------------------------------------------
  -- final output negative active reset
  -------------------------------------------------------------------------------------------
  rst_n_o<=rst_n_shifter(0);


end behavioral;
