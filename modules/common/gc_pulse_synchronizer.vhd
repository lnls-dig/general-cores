--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_pulse_synchronizer
--
-- description: Full feedback pulse synchronizer (works independently of the
-- input/output clock domain frequency ratio)
--
--------------------------------------------------------------------------------
-- Copyright CERN 2012-2018
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

library ieee;
use ieee.std_logic_1164.all;

use work.gencores_pkg.all;

entity gc_pulse_synchronizer is

  port (
    -- pulse input clock
    clk_in_i  : in  std_logic;
    -- pulse output clock
    clk_out_i : in  std_logic;
    -- system reset (clk_in_i domain)
    rst_n_i   : in  std_logic;
    -- pulse input ready (clk_in_i domain). When HI, a pulse
    -- coming to d_p_i will be correctly transferred to q_p_o.
    d_ready_o : out std_logic;
    -- pulse input (clk_in_i domain)
    d_p_i     : in  std_logic;
    -- pulse output (clk_out_i domain)
    q_p_o     : out std_logic);

end gc_pulse_synchronizer;

architecture rtl of gc_pulse_synchronizer is

begin  -- rtl

  -- Just wrap around gc_pulse_synchronizer2
  -- using the same reset on both domains
  cmp_gc_pulse_sync : gc_pulse_synchronizer2
    port map (
      clk_in_i    => clk_in_i,
      rst_in_n_i  => rst_n_i,
      clk_out_i   => clk_out_i,
      rst_out_n_i => rst_n_i,
      d_ready_o   => d_ready_o,
      d_p_i       => d_p_i,
      q_p_o       => q_p_o);

end rtl;
