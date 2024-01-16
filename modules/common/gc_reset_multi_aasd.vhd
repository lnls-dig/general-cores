--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_reset_multi_aasd
--
-- description: Multiple clock domain reset generator and synchronizer with
-- Asynchronous Assert and Syncrhonous Deassert (AASD).
--
--------------------------------------------------------------------------------
-- Copyright CERN 2018
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

entity gc_reset_multi_aasd is
  generic(
    -- number of clock domains
    g_CLOCKS  : natural := 1;
    -- Number of clock ticks (per domain) that the input reset must remain
    -- deasserted and stable before deasserting the reset output(s)
    g_RST_LEN : natural := 16);
  port(
    -- all async resets OR'ed together, active high
    arst_i  : in  std_logic := '1';
    -- one clock signal per domain
    clks_i  : in  std_logic_vector(g_CLOCKS-1 downto 0);
    -- one syncrhonous, active low reset output per domain
    rst_n_o : out std_logic_vector(g_CLOCKS-1 downto 0));
end gc_reset_multi_aasd;

architecture arch of gc_reset_multi_aasd is

  subtype t_rst_chain is std_logic_vector(g_RST_LEN-1 downto 0);
  type t_rst_chains is array(natural range <>) of t_rst_chain;

  signal rst_chains : t_rst_chains(g_CLOCKS-1 downto 0) := (others => (others => '0'));

  signal gc_reset_async_in : std_logic;

  attribute keep : string;

  attribute keep of gc_reset_async_in : signal is "TRUE";
  attribute keep of rst_chains : signal is "TRUE";
  
begin

  gc_reset_async_in <= arst_i;

  gen_rst_sync : for I in g_CLOCKS-1 downto 0 generate
    sync : process(clks_i, gc_reset_async_in)
    begin
      if gc_reset_async_in = '1' then
        rst_chains(i) <= (others => '0');
      elsif rising_edge(clks_i(i)) then
        rst_chains(i) <= '1' & rst_chains(i)(g_RST_LEN-1 downto 1);
      end if;
    end process;
    rst_n_o(i) <= rst_chains(i)(0);
  end generate gen_rst_sync;

end architecture arch;
