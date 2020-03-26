--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_sync_register
--
-- description: Parametrized synchronizer.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2014-2018
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

entity gc_sync_register is
  generic (
    g_width : integer);
  port (
    clk_i     : in  std_logic;
    rst_n_a_i : in  std_logic;
    d_i       : in  std_logic_vector(g_width-1 downto 0);
    q_o       : out std_logic_vector(g_width-1 downto 0));

end gc_sync_register;

-- make Altera Quartus quiet regarding unknown attributes:
-- altera message_off 10335

architecture rtl of gc_sync_register is

  signal gc_sync_register_in : std_logic_vector(g_width-1 downto 0);
  signal sync0, sync1        : std_logic_vector(g_width-1 downto 0);

  attribute shreg_extract                        : string;
  attribute shreg_extract of gc_sync_register_in : signal is "no";
  attribute shreg_extract of sync0               : signal is "no";
  attribute shreg_extract of sync1               : signal is "no";

  attribute keep                        : string;
  attribute keep of gc_sync_register_in : signal is "true";
  attribute keep of sync0               : signal is "true";
  attribute keep of sync1               : signal is "true";

  attribute keep_hierarchy        : string;
  attribute keep_hierarchy of rtl : architecture is "true";

  attribute async_reg                        : string;
  attribute async_reg of gc_sync_register_in : signal is "true";
  attribute async_reg of sync0               : signal is "true";
  attribute async_reg of sync1               : signal is "true";

begin

  process(clk_i, rst_n_a_i)
  begin
    if(rst_n_a_i = '0') then
      sync1 <= (others => '0');
      sync0 <= (others => '0');
    elsif rising_edge(clk_i) then
      sync0 <= gc_sync_register_in;
      sync1 <= sync0;
    end if;
  end process;

  gc_sync_register_in <= d_i;
  q_o                 <= sync1;
  
end rtl;
