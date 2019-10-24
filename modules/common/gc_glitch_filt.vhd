--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_glitch_filt
--
-- description: Glitch filter with selectable length, consisting of a set of
-- chained flip-flops followed by a comparator. The comparator toggles to '1'
-- when all FFs in the chain are '1' and respectively to '0' when all the FFS
-- in the chain are '0'.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2013-2018
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
use ieee.numeric_std.all;

use work.gencores_pkg.all;

entity gc_glitch_filt is
  generic
  (
    -- Length of glitch filter:
    -- g_len = 1 => data width should be > 1 clk_i cycle
    -- g_len = 2 => data width should be > 2 clk_i cycle
    -- etc.
    g_len : natural := 4
  );
  port
  (
    clk_i   : in  std_logic;
    rst_n_i : in  std_logic;

    -- Data input, synchronous to clk_i
    dat_i   : in  std_logic;

    -- Data output
    -- latency: g_len+1 clk_i cycles
    dat_o   : out std_logic
  );
end entity gc_glitch_filt;


architecture behav of gc_glitch_filt is

  signal glitch_filt : std_logic_vector(g_len downto 0);

begin

  glitch_filt(0) <= dat_i;

  -- Generate glitch filter FFs when the filter length is > 0
  gen_glitch_filt: if (g_len > 0) generate
    p_glitch_filt: process (clk_i)
    begin
      if rising_edge(clk_i) then
        if (rst_n_i = '0') then
          glitch_filt(g_len downto 1) <= (others => '0');
        else
          glitch_filt(g_len downto 1) <= glitch_filt(g_len-1 downto 0);
        end if;
      end if;
    end process p_glitch_filt;
  end generate gen_glitch_filt;

  -- and set the data output based on the state of the glitch filter
  p_output: process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        dat_o <= '0';
      elsif (unsigned(glitch_filt) = (glitch_filt'range => '1')) then
        dat_o <= '1';
      elsif (unsigned(glitch_filt) = (glitch_filt'range => '0')) then
        dat_o <= '0';
      end if;
    end if;
  end process p_output;

end architecture behav;
