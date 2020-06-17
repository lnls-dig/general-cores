--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_frequency_meter
--
-- description: Frequency meter with internal or external timebase.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2012-2019
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

--  Principle of operation:
--
--  This block counts the number of pulses on CLK_IN_I during a period.
--  At the end of the period, the value is saved and the counter reset.
--  The saved value is available on FREQ_O, which is synchronized with
--  CLK_SYS_I if G_SYNC_OUT is True.
--  The width of the counter is defined by G_COUNTER_BITS.
--
--  - If g_WITH_INTERNAL_TIMEBASE is True:
--    The period is defined by an internal counter that generates a pulse
--    every G_CLK_SYS_FREQ CLK_SYS_I ticks.
--
--  - If g_WITH_INTERNAL_TIMEBASE is False:
--    The period is defined by PPS_P1_I

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gencores_pkg.all;

entity gc_frequency_meter is
  generic (
    g_WITH_INTERNAL_TIMEBASE : boolean := TRUE;
    g_CLK_SYS_FREQ           : integer;
    -- if true, sync freq_o to the clk_sys domain
    g_SYNC_OUT               : boolean := FALSE;
    g_COUNTER_BITS           : integer := 32);
  port (
    clk_sys_i    : in  std_logic;
    clk_in_i     : in  std_logic;
    rst_n_i      : in  std_logic;  -- not used, kept for backward compatibility
    pps_p1_i     : in  std_logic;
    -- synced to clk_in_i or clk_sys_i, depending on g_SYNC_OUT value
    freq_o       : out std_logic_vector(g_COUNTER_BITS-1 downto 0);
    -- synced to clk_sys_i, always
    freq_valid_o : out std_logic);

end gc_frequency_meter;

architecture arch of gc_frequency_meter is

  signal gate_pulse, gate_pulse_synced : std_logic := '0';

  signal cntr_gate : unsigned(g_COUNTER_BITS-1 downto 0) := (others => '0');
  signal cntr_meas : unsigned(g_COUNTER_BITS-1 downto 0) := (others => '0');

  signal freq_reg : std_logic_vector(g_COUNTER_BITS-1 downto 0) := (others => '0');

begin

  gen_internal_timebase : if g_WITH_INTERNAL_TIMEBASE = TRUE generate

    p_gate_counter : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if cntr_gate = g_CLK_SYS_FREQ-1 then
          cntr_gate  <= (others => '0');
          gate_pulse <= '1';
        else
          cntr_gate  <= cntr_gate + 1;
          gate_pulse <= '0';
        end if;
      end if;
    end process;

    U_Sync_Gate : gc_pulse_synchronizer
      port map (
        clk_in_i  => clk_sys_i,
        clk_out_i => clk_in_i,
        rst_n_i   => '1',
        d_ready_o => freq_valid_o,
        d_p_i     => gate_pulse,
        q_p_o     => gate_pulse_synced);

  end generate gen_internal_timebase;

  gen_external_timebase : if g_WITH_INTERNAL_TIMEBASE = FALSE generate

    U_Sync_Gate : gc_pulse_synchronizer
      port map (
        clk_in_i  => clk_sys_i,
        clk_out_i => clk_in_i,
        rst_n_i   => '1',
        d_ready_o => freq_valid_o,
        d_p_i     => pps_p1_i,
        q_p_o     => gate_pulse_synced);

  end generate gen_external_timebase;

  p_freq_counter : process (clk_in_i)
  begin
    if rising_edge(clk_in_i) then

      if gate_pulse_synced = '1' then
        freq_reg  <= std_logic_vector(cntr_meas);
        cntr_meas <= (others => '0');
      else
        cntr_meas <= cntr_meas + 1;
      end if;
    end if;
  end process p_freq_counter;

  gen_with_sync_out : if g_SYNC_OUT generate
    cmp_gc_sync_word_wr : gc_sync_word_wr
      generic map (
        g_AUTO_WR => TRUE,
        g_WIDTH   => g_COUNTER_BITS)
      port map (
        clk_in_i    => clk_in_i,
        rst_in_n_i  => '1',
        clk_out_i   => clk_sys_i,
        rst_out_n_i => '1',
        data_i      => freq_reg,
        data_o      => freq_o);
  end generate gen_with_sync_out;

  gen_without_sync_out : if not g_SYNC_OUT generate
    freq_o <= freq_reg;
  end generate gen_without_sync_out;

end arch;
