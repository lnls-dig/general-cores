--==============================================================================
-- CERN (BE-CO-HT)
-- Testbench for FSM Watchdog Timer
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

use work.gencores_pkg.all;

entity tb_gc_fsm_watchdog is
end entity tb_gc_fsm_watchdog;


architecture behav of tb_gc_fsm_watchdog is

  --============================================================================
  -- Type declarations
  --============================================================================
  type t_state is
  (
    IDLE,
    RUN
  );

  --============================================================================
  -- Constant declarations
  --============================================================================
  constant c_clk_per : time := 50 ns;
  constant c_reset_width : time := 112 ns;

  constant c_fsm_time : positive := 32766;

  --============================================================================
  -- Signal declarations
  --============================================================================
  signal clk, rst_n   : std_logic := '0';
  signal wdt_rst      : std_logic;
  signal rst_from_wdt : std_logic;

  signal state        : t_state;
  signal cnt          : unsigned(15 downto 0);
  signal cnt_tick_p   : std_logic;


--==============================================================================
--  architecture begin
--==============================================================================
begin

  --============================================================================
  -- Generate clock and reset signals
  --============================================================================
  -- Clock generation
  p_clk: process
  begin
    clk <= not clk;
    wait for c_clk_per/2;
  end process p_clk;

  -- Reset generation
  p_rst_n: process
  begin
    rst_n <= '0';
    wait for c_reset_width;
    rst_n <= '1';
    wait;
  end process p_rst_n;

  --============================================================================
  -- DUT instantiation
  --============================================================================
  DUT : gc_fsm_watchdog
  generic map
  (
    g_wdt_max => 32768
  )
  port map
  (
    clk_i     => clk,
    rst_n_i   => rst_n,
    wdt_rst_i => wdt_rst,
    fsm_rst_o => rst_from_wdt
  );

  --============================================================================
  -- FSM to test the Watchdog
  --============================================================================
  p_fsm : process (clk) is
  begin
    if rising_edge(clk) then
      if (rst_n = '0') or (rst_from_wdt = '1') then
        wdt_rst <= '1';
        state   <= IDLE;
      else
        case state is
          when IDLE =>
            wdt_rst <= '1';
            if (cnt_tick_p = '1') then
              state <= RUN;
              wdt_rst <= '0';
            end if;
          when RUN =>
            if (cnt_tick_p = '1') then
              state <= IDLE;
            end if;
        end case;
      end if;
    end if;
  end process p_fsm;

  p_cnt : process (clk) is
  begin
    if rising_edge(clk) then
      if (rst_n = '0') then
        cnt <= (others => '0');
        cnt_tick_p <= '0';
      else
        cnt <= cnt+1;
        cnt_tick_p <= '0';
        if (cnt = c_fsm_time) then
          cnt <= (others => '0');
          cnt_tick_p <= '1';
        end if;
      end if;
    end if;
  end process p_cnt;

end architecture behav;
--==============================================================================
--  architecture end
--==============================================================================
