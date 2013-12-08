--==============================================================================
-- CERN (BE-CO-HT)
-- Finite State Machine Watchdog Timer
--==============================================================================
--
-- author: Theodor Stana (t.stana@cern.ch)
--
-- date of creation: 2013-11-22
--
-- version: 1.0
--
-- description:
--
-- dependencies:
--
-- references:
--
--==============================================================================
-- GNU LESSER GENERAL PUBLIC LICENSE
--==============================================================================
-- This source file is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation; either version 2.1 of the License, or (at your
-- option) any later version. This source is distributed in the hope that it
-- will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU Lesser General Public License for more details. You should have
-- received a copy of the GNU Lesser General Public License along with this
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html
--==============================================================================
-- last changes:
--    2013-11-22   Theodor Stana     File created
--==============================================================================
-- TODO: -
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.genram_pkg.all;

entity gc_fsm_watchdog is
  generic
  (
    -- Maximum value of watchdog timer in clk_i cycles
    g_wdt_max : positive := 65535
  );
  port
  (
    -- Clock and active-low reset line
    clk_i     : in  std_logic;
    rst_n_i   : in  std_logic;

    -- Active-high watchdog timer reset line, synchronous to clk_i
    wdt_rst_i : in  std_logic;

    -- Active-high reset output, synchronous to clk_i
    fsm_rst_o : out std_logic
  );
end entity gc_fsm_watchdog;


architecture behav of gc_fsm_watchdog is

  --============================================================================
  -- Signal declarations
  --============================================================================
  signal wdt                : unsigned(f_log2_size(g_wdt_max)-1 downto 0);

--==============================================================================
--  architecture begin
--==============================================================================
begin

  --============================================================================
  -- Watchdog timer process
  --============================================================================
  p_wdt : process (clk_i) is
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') or (wdt_rst_i = '1') then
        wdt       <= (others => '0');
        fsm_rst_o <= '0';
      else
        wdt <= wdt + 1;
        if (wdt = g_wdt_max-1) then
          fsm_rst_o <= '1';
        end if;
      end if;
    end if;
  end process p_wdt;

end architecture behav;
--==============================================================================
--  architecture end
--==============================================================================
