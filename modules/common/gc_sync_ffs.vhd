--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_sync_ffs
--
-- description: Synchronizer chain and edge detector.
--   All the registers in the chain are cleared at reset.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2010-2020
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

entity gc_sync_ffs is
  generic(
    -- valid values are "positive" and "negative"
    g_SYNC_EDGE : string := "positive");
  port(
    clk_i    : in  std_logic;   -- clock from the destination clock domain
    rst_n_i  : in  std_logic;   -- async reset
    data_i   : in  std_logic;   -- async input
    synced_o : out std_logic;   -- synchronized output
    npulse_o : out std_logic;   -- negative edge detect output
    ppulse_o : out std_logic);  -- positive edge detect output
end entity gc_sync_ffs;

architecture arch of gc_sync_ffs is

  signal sync, npulse, ppulse : std_logic;

begin

  cmp_gc_sync : entity work.gc_sync
    generic map (
      g_SYNC_EDGE => g_SYNC_EDGE)
    port map (
      clk_i     => clk_i,
      rst_n_a_i => rst_n_i,
      d_i       => data_i,
      q_o       => sync);

  cmp_gc_posedge : entity work.gc_edge_detect
    generic map (
      g_ASYNC_RST  => TRUE,
      g_PULSE_EDGE => "positive",
      g_CLOCK_EDGE => g_SYNC_EDGE)
    port map (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      data_i  => sync,
      pulse_o => ppulse);

  cmp_gc_negedge : entity work.gc_edge_detect
    generic map (
      g_ASYNC_RST  => TRUE,
      g_PULSE_EDGE => "negative",
      g_CLOCK_EDGE => g_SYNC_EDGE)
    port map (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      data_i  => sync,
      pulse_o => npulse);

  sync_posedge : if (g_SYNC_EDGE = "positive") generate
    process(clk_i, rst_n_i)
    begin
      if(rst_n_i = '0') then
        synced_o <= '0';
        npulse_o <= '0';
        ppulse_o <= '0';
      elsif rising_edge(clk_i) then
        synced_o <= sync;
        npulse_o <= npulse;
        ppulse_o <= ppulse;
      end if;
    end process;
  end generate sync_posedge;

  sync_negedge : if(g_SYNC_EDGE = "negative") generate
    process(clk_i, rst_n_i)
    begin
      if(rst_n_i = '0') then
        synced_o <= '0';
        npulse_o <= '0';
        ppulse_o <= '0';
      elsif falling_edge(clk_i) then
        synced_o <= sync;
        npulse_o <= npulse;
        ppulse_o <= ppulse;
      end if;
    end process;
  end generate sync_negedge;

end architecture arch;
