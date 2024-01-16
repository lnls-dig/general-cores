--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   generic_sync_fifo
--
-- description: Parametrizable synchronous FIFO (Generic version).
-- Single-clock FIFO.
-- - configurable data width and size
-- - configurable full/empty/almost full/almost empty/word count signals
--
--------------------------------------------------------------------------------
-- Copyright CERN 2011-2020
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

use work.genram_pkg.all;

entity generic_sync_fifo is

  generic (
    g_data_width : natural;
    g_size       : natural;
    g_show_ahead : boolean := false;

    -- Previously, the full flag was asserted at g_size-1 when using g_show_ahead.
    -- The new implementation solves this. However, for backward compatibility,
    -- the default is to still use the previous behaviour. Set this to false to
    -- switch to the new one.
    g_show_ahead_legacy_mode : boolean := true;

      -- Read-side flag selection
    g_with_empty        : boolean := true;   -- with empty flag
    g_with_full         : boolean := true;   -- with full flag
    g_with_almost_empty : boolean := false;
    g_with_almost_full  : boolean := false;
    g_with_count        : boolean := false;  -- with words counter

    g_almost_empty_threshold : integer := 0;  -- threshold for almost empty flag
    g_almost_full_threshold  : integer := 0;  -- threshold for almost full flag
    g_register_flag_outputs  : boolean := true;
    g_memory_implementation_hint : string := "auto"
    );

  port (
    rst_n_i : in std_logic := '1';

    clk_i : in std_logic;
    d_i   : in std_logic_vector(g_data_width-1 downto 0);
    we_i  : in std_logic;

    q_o  : out std_logic_vector(g_data_width-1 downto 0);
    rd_i : in  std_logic;

    empty_o        : out std_logic;
    full_o         : out std_logic;
    almost_empty_o : out std_logic;
    almost_full_o  : out std_logic;
    count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0)
    );

end generic_sync_fifo;

architecture syn of generic_sync_fifo is
begin  -- syn
  U_Inferred_FIFO : entity work.inferred_sync_fifo
      generic map (
        g_data_width             => g_data_width,
        g_size                   => g_size,
        g_show_ahead             => g_show_ahead,
        g_show_ahead_legacy_mode => g_show_ahead_legacy_mode,
        g_with_empty             => g_with_empty,
        g_with_full              => g_with_full,
        g_with_almost_empty      => g_with_almost_empty,
        g_with_almost_full       => g_with_almost_full,
        g_with_count             => g_with_count,
        g_almost_empty_threshold => g_almost_empty_threshold,
        g_almost_full_threshold  => g_almost_full_threshold,
        g_register_flag_outputs  => g_register_flag_outputs,
        g_memory_implementation_hint => g_memory_implementation_hint )
      port map (
        rst_n_i        => rst_n_i,
        clk_i          => clk_i,
        d_i            => d_i,
        we_i           => we_i,
        q_o            => q_o,
        rd_i           => rd_i,
        empty_o        => empty_o,
        full_o         => full_o,
        almost_empty_o => almost_empty_o,
        almost_full_o  => almost_full_o,
        count_o        => count_o);
end syn;
