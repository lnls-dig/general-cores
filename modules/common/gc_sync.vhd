--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_sync
--
-- description: Elementary synchronizer chain using two flip-flops.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2014-2020
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

entity gc_sync is
  generic(
    -- valid values are "positive" and "negative"
    g_SYNC_EDGE : string := "positive");
  port (
    clk_i     : in  std_logic;
    rst_n_a_i : in  std_logic;
    d_i       : in  std_logic;
    q_o       : out std_logic);
end gc_sync;

-- make Altera Quartus quiet regarding unknown attributes:
-- altera message_off 10335

architecture arch of gc_sync is

  --  Use an intermediate signal with a particular name and a keep attribute
  --  so that it can be referenced in the constraints in order to ignore
  --  timing (TIG) on that signal.
  signal gc_sync_ffs_in : std_logic;

  signal sync0, sync1 : std_logic;

  attribute rloc          : string;
  attribute rloc of sync0 : signal is "X0Y0";
  attribute rloc of sync1 : signal is "X0Y0";

  attribute shreg_extract          : string;
  attribute shreg_extract of sync0 : signal is "no";
  attribute shreg_extract of sync1 : signal is "no";

  attribute keep                   : string;
  attribute keep of clk_i          : signal is "true";
  attribute keep of gc_sync_ffs_in : signal is "true";
  attribute keep of sync0          : signal is "true";
  attribute keep of sync1          : signal is "true";

  attribute keep_hierarchy         : string;
  attribute keep_hierarchy of arch : architecture is "true";

  attribute async_reg          : string;
  attribute async_reg of sync0 : signal is "true";
  attribute async_reg of sync1 : signal is "true";

begin

  assert g_SYNC_EDGE = "positive" or g_SYNC_EDGE = "negative" severity failure;

  gc_sync_ffs_in <= d_i;

  sync_posedge : if (g_SYNC_EDGE = "positive") generate
    process(clk_i, rst_n_a_i)
    begin
      if rst_n_a_i = '0' then
        sync1 <= '0';
        sync0 <= '0';
      elsif rising_edge(clk_i) then
        sync0 <= gc_sync_ffs_in;
        sync1 <= sync0;
      end if;
    end process;
  end generate sync_posedge;

  sync_negedge : if(g_SYNC_EDGE = "negative") generate
    process(clk_i, rst_n_a_i)
    begin
      if rst_n_a_i = '0' then
        sync1 <= '0';
        sync0 <= '0';
      elsif falling_edge(clk_i) then
        sync0 <= gc_sync_ffs_in;
        sync1 <= sync0;
      end if;
    end process;
  end generate sync_negedge;

  q_o <= sync1;

end arch;
