--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_negedge
--
-- description: Simple falling edge detector.  Combinatorial.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2020
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

entity gc_negedge is
  generic(
    g_ASYNC_RST : boolean := FALSE;
    -- Clock edge sensitivity of edge detection flip-flop.
    -- Valid values are "positive" and "negative".
    g_CLOCK_EDGE : string  := "positive");
  port(
    clk_i   : in  std_logic;   -- clock
    rst_n_i : in  std_logic;   -- reset
    data_i  : in  std_logic;   -- input
    pulse_o : out std_logic);  -- falling edge detect output
end entity gc_negedge;

architecture arch of gc_negedge is

begin

  inst_gc_edge_detect : entity work.gc_edge_detect
    generic map (
      g_ASYNC_RST  => g_ASYNC_RST,
      g_PULSE_EDGE => "negative",
      g_CLOCK_EDGE => g_CLOCK_EDGE)
    port map (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      data_i  => data_i,
      pulse_o => pulse_o);

end architecture arch;
