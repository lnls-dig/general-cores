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

entity gc_sync_ffs is
  generic(
    g_sync_edge : string := "positive");
  port(
    clk_i    : in  std_logic;   -- clock from the destination clock domain
    rst_n_i  : in  std_logic;   -- reset
    data_i   : in  std_logic;   -- async input
    synced_o : out std_logic;   -- synchronized output
    npulse_o : out std_logic;   -- negative edge detect output
    ppulse_o : out std_logic);  -- positive edge detect output
end entity gc_sync_ffs;

-- make Altera Quartus quiet regarding unknown attributes:
-- altera message_off 10335

architecture arch of gc_sync_ffs is

  signal sync0, sync1, sync2 : std_logic;

  signal gc_sync_ffs_in : std_logic;

  attribute shreg_extract          : string;
  attribute shreg_extract of sync0 : signal is "no";
  attribute shreg_extract of sync1 : signal is "no";
  attribute shreg_extract of sync2 : signal is "no";

  attribute keep          : string;
  attribute keep of sync0 : signal is "true";
  attribute keep of sync1 : signal is "true";

  attribute rloc          : string;
  attribute rloc of sync0 : signal is "X0Y0";
  attribute rloc of sync1 : signal is "X0Y0";

  attribute keep of gc_sync_ffs_in : signal is "true";

  -- synchronizer attribute for Vivado
  attribute ASYNC_REG          : string;
  attribute ASYNC_REG of sync0 : signal is "true";
  attribute ASYNC_REG of sync1 : signal is "true";
  attribute ASYNC_REG of sync2 : signal is "true";

begin

  -- rename data_i to something we can use as wildcard
  -- in timing constraints
  gc_sync_ffs_in <= data_i;

  sync_posedge : if (g_sync_edge = "positive") generate
    process(clk_i, rst_n_i)
    begin
      if(rst_n_i = '0') then
        sync0    <= '0';
        sync1    <= '0';
        sync2    <= '0';
        synced_o <= '0';
        npulse_o <= '0';
        ppulse_o <= '0';
      elsif rising_edge(clk_i) then
        sync0    <= gc_sync_ffs_in;
        sync1    <= sync0;
        sync2    <= sync1;
        synced_o <= sync1;
        npulse_o <= sync2 and not sync1;
        ppulse_o <= not sync2 and sync1;
      end if;
    end process;
  end generate sync_posedge;

  sync_negedge : if(g_sync_edge = "negative") generate
    process(clk_i, rst_n_i)
    begin
      if(rst_n_i = '0') then
        sync0    <= '0';
        sync1    <= '0';
        sync2    <= '0';
        synced_o <= '0';
        npulse_o <= '0';
        ppulse_o <= '0';
      elsif falling_edge(clk_i) then
        sync0    <= gc_sync_ffs_in;
        sync1    <= sync0;
        sync2    <= sync1;
        synced_o <= sync1;
        npulse_o <= sync2 and not sync1;
        ppulse_o <= not sync2 and sync1;
      end if;
    end process;
  end generate sync_negedge;

end architecture arch;
