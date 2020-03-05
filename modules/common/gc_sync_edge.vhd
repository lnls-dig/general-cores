--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_sync_edge
--
-- description: Synchronizer chain and edge detector.
--   All the registers in the chain are cleared at reset.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2010-2018
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

entity gc_sync_edge is
  generic(
    g_edge : string := "positive");
  port(
    clk_i     : in  std_logic;   -- clock from the destination clock domain
    rst_n_a_i : in  std_logic;   -- async reset
    data_i    : in  std_logic;   -- async input
    synced_o  : out std_logic;   -- synchronized output
    pulse_o   : out std_logic);  -- edge detect output
end entity gc_sync_edge;

architecture arch of gc_sync_edge is
  signal sync : std_logic;
begin

  inst_sync : entity work.gc_sync
    port map (
      clk_i     => clk_i,
      rst_n_a_i => rst_n_a_i,
      d_i       => data_i,
      q_o       => sync);

  assert g_edge = "positive" or g_edge = "negative" severity FAILURE;

  sync_posedge : if g_edge = "positive" generate
    inst_pedge : entity work.gc_posedge
      port map (
        clk_i   => clk_i,
        rst_n_i => rst_n_a_i,
        data_i  => sync,
        pulse_o => pulse_o);
  end generate;

  sync_negedge : if g_edge = "negative" generate
    inst_pedge : entity work.gc_negedge
      port map (
        clk_i   => clk_i,
        rst_n_i => rst_n_a_i,
        data_i  => sync,
        pulse_o => pulse_o);
  end generate;
end architecture arch;
