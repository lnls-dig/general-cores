-------------------------------------------------------------------------------
-- Title      : Generic input stage for asynchronous input signals
-------------------------------------------------------------------------------
-- File       : gc_async_signals_input_stage.vhd
-- Author     : Maciej Lipinski
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
--
-- A generic input stage for digital asynchronous input signals.
-- It implements a number of stages that might be generally useful/needed
-- before using such signals in a synchronous FPGA-base applications.
--
-- It includes the following input stages:
-- 1. synchronisation with clock domain with taking care for metastability
-- 2. choice of HIGH/LOW active
-- 3. degliching with a filter width set through generic
-- 4. single-clock pulse generation on edge detection
--    * rising edge if HIGH active set
--    * falling edge if LOW actvie set
-- 5. extension of pulse with width set through generic
--
-- The output provides three outputs, any of them can be used at will
--   signals_o    : synchronised and deglichted signal active LOW or HIGH,
--                  depending on conifg
--   signals_p_o  : single-clock pulse on rising/faling edge of the synchronised
--                  and degliched signal
--   signals_pN_o : the single-clock pulse extended
--
-------------------------------------------------------------------------------
--
-- Copyright (c) 2016 CERN/TE-MS-MM
--
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 0.51 (the “License”) (which enables you, at your option,
-- to treat this file as licensed under the Apache License 2.0); you may not
-- use this file except in compliance with the License. You may obtain a copy
-- of the License at http://solderpad.org/licenses/SHL-0.51.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2016-08-25  1.0      mlipinsk        created
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use work.gencores_pkg.all;

entity gc_async_signals_input_stage is
  generic (
    -- number of input signals to be synchronised
    g_signal_num                 : integer := 2;

    -- number of clock cycles (N) for the extended output pulse signal
    g_extended_pulse_width       : integer := 0;

    -- number of cycles that filter out glitches
    g_dglitch_filter_len         : integer := 2
  );
  port (
    clk_i                        : in std_logic;
    rst_n_i                      : in std_logic;

    -- input asynchronous signals
    signals_a_i                  : in  std_logic_vector(g_signal_num-1 downto 0);

    --- Configuration of each input signal
    --- '0': active LOW:  deglitcher works for '0s' and pulses are produced on falling edge
    --- '1': active HIGH: deglitcher works for '1s' and pulses are produced on rising edge
    config_active_i              : in  std_logic_vector(g_signal_num-1 downto 0);

    -- synchronised and deglitched signal
    signals_o                    : out std_logic_vector(g_signal_num-1 downto 0);

    -- single-clock pulse on rising or falling edge of the input signal (depends on the config)
    signals_p1_o                 : out std_logic_vector(g_signal_num-1 downto 0);

    -- N-cycle pulse on rising or falling edge of the input signal (depends on the config)
    -- N=g_extended_pulse_width
    signals_pN_o                 : out std_logic_vector(g_signal_num-1 downto 0)
  );
end entity gc_async_signals_input_stage;

architecture behav of gc_async_signals_input_stage is

  
  signal signals_synched         : std_logic_vector(g_signal_num-1 downto 0);
  signal signals_high_or_low     : std_logic_vector(g_signal_num-1 downto 0);
  signal signals_deglitched      : std_logic_vector(g_signal_num-1 downto 0);
  signal signals_deglitched_d1   : std_logic_vector(g_signal_num-1 downto 0);
  signal signals_pulse_p1        : std_logic_vector(g_signal_num-1 downto 0);
  signal signals_pulse_pN        : std_logic_vector(g_signal_num-1 downto 0);

begin

  gen_synced_signals: for i in 0 to g_signal_num-1 generate

    -----------------------------------------------------------------------------------------
    -- 1 stage: synchronzie with clock domain
    -----------------------------------------------------------------------------------------
    cmp_sync_with_clk : gc_sync_ffs
      port map (
        clk_i          => clk_i,
        rst_n_i        => rst_n_i,
        data_i         => signals_a_i(i),
        synced_o       => signals_synched(i));

    -----------------------------------------------------------------------------------------
    -- 2 stage: configure active low or high
    -----------------------------------------------------------------------------------------
    signals_high_or_low(i) <= not signals_synched(i) when config_active_i(i) = '0' else
                                  signals_synched(i);

    -----------------------------------------------------------------------------------------
    -- 3 stage: deglitch signals where the active is HIGH
    -----------------------------------------------------------------------------------------
    cmp_deglitch : gc_glitch_filt
      generic map (
        g_len          => g_dglitch_filter_len)
      port map (
        clk_i          => clk_i,
        rst_n_i        => rst_n_i,
        dat_i          => signals_high_or_low(i),
        dat_o          => signals_deglitched(i));

    -----------------------------------------------------------------------------------------
    -- 4 stage: produce pulse on rising edge
    -----------------------------------------------------------------------------------------
    p_pulse_gen : process (clk_i)
    begin
    if rising_edge (clk_i) then
      if rst_n_i = '0' then
        signals_deglitched_d1(i) <= '0';
        signals_pulse_p1(i)      <= '0';
      else
        if(signals_deglitched(i) =  '1' and signals_deglitched_d1(i) = '0') then
          signals_pulse_p1(i)    <= '1';
        else
          signals_pulse_p1(i)    <= '0';
        end if;
        signals_deglitched_d1(i) <= signals_deglitched(i);
      end if;
     end if;
    end process;

    -----------------------------------------------------------------------------------------
    -- 5 stage: extended the pulse (if configured to do so)
    -----------------------------------------------------------------------------------------
    gen_no_pulse_extender: if(g_extended_pulse_width = 0) generate
      signals_pulse_pN(i) <= signals_pulse_p1(i);
    end generate gen_no_pulse_extender;

    gen_pulse_extender: if(g_extended_pulse_width > 0) generate
      cmp_extend_pulse: gc_extend_pulse
        generic map (
          g_width        => g_extended_pulse_width)
        port map(
          clk_i          => clk_i,
          rst_n_i        => rst_n_i,
          pulse_i        => signals_pulse_p1(i),
          extended_o     => signals_pulse_pN(i));
      end generate gen_pulse_extender;

  end generate gen_synced_signals;

  -------------------------------------------------------------------------------------------
  -- outputs:
  -------------------------------------------------------------------------------------------
  signals_o            <= signals_deglitched;
  signals_p1_o         <= signals_pulse_p1;
  signals_pN_o         <= signals_pulse_pN;
  
end architecture behav;
