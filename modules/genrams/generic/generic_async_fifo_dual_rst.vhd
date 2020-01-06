
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   generic_async_fifo_dual_rst
--
-- description: Parametrizable asynchronous FIFO (Generic version).
-- Dual-clock asynchronous FIFO.
-- - configurable data width and size
-- - configurable full/empty/almost full/almost empty/word count signals
-- - dual sunchronous reset
--
--------------------------------------------------------------------------------
-- Copyright CERN 2011-2018
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

entity generic_async_fifo_dual_rst is

  generic (
    g_data_width             : natural;
    g_size                   : natural;
    g_show_ahead             : boolean := FALSE;
    g_with_rd_empty          : boolean := TRUE;
    g_with_rd_full           : boolean := FALSE;
    g_with_rd_almost_empty   : boolean := FALSE;
    g_with_rd_almost_full    : boolean := FALSE;
    g_with_rd_count          : boolean := FALSE;
    g_with_wr_empty          : boolean := FALSE;
    g_with_wr_full           : boolean := TRUE;
    g_with_wr_almost_empty   : boolean := FALSE;
    g_with_wr_almost_full    : boolean := FALSE;
    g_with_wr_count          : boolean := FALSE;
    g_almost_empty_threshold : integer := 0;
    g_almost_full_threshold  : integer := 0);
  port (
    -- write port
    rst_wr_n_i        : in  std_logic := '1';
    clk_wr_i          : in  std_logic;
    d_i               : in  std_logic_vector(g_data_width-1 downto 0);
    we_i              : in  std_logic;
    wr_empty_o        : out std_logic;
    wr_full_o         : out std_logic;
    wr_almost_empty_o : out std_logic;
    wr_almost_full_o  : out std_logic;
    wr_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0);
    -- read port
    rst_rd_n_i        : in  std_logic := '1';
    clk_rd_i          : in  std_logic;
    q_o               : out std_logic_vector(g_data_width-1 downto 0);
    rd_i              : in  std_logic;
    rd_empty_o        : out std_logic;
    rd_full_o         : out std_logic;
    rd_almost_empty_o : out std_logic;
    rd_almost_full_o  : out std_logic;
    rd_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0));

end generic_async_fifo_dual_rst;


architecture arch of generic_async_fifo_dual_rst is

begin  -- arch

  U_Inferred_FIFO : entity work.inferred_async_fifo_dual_rst
    generic map (
      g_data_width             => g_data_width,
      g_size                   => g_size,
      g_show_ahead             => g_show_ahead,
      g_with_rd_empty          => g_with_rd_empty,
      g_with_rd_full           => g_with_rd_full,
      g_with_rd_almost_empty   => g_with_rd_almost_empty,
      g_with_rd_almost_full    => g_with_rd_almost_full,
      g_with_rd_count          => g_with_rd_count,
      g_with_wr_empty          => g_with_wr_empty,
      g_with_wr_full           => g_with_wr_full,
      g_with_wr_almost_empty   => g_with_wr_almost_empty,
      g_with_wr_almost_full    => g_with_wr_almost_full,
      g_with_wr_count          => g_with_wr_count,
      g_almost_empty_threshold => g_almost_empty_threshold,
      g_almost_full_threshold  => g_almost_full_threshold)
    port map (
      rst_wr_n_i        => rst_wr_n_i,
      clk_wr_i          => clk_wr_i,
      d_i               => d_i,
      we_i              => we_i,
      wr_empty_o        => wr_empty_o,
      wr_full_o         => wr_full_o,
      wr_almost_empty_o => wr_almost_empty_o,
      wr_almost_full_o  => wr_almost_full_o,
      wr_count_o        => wr_count_o,
      rst_rd_n_i        => rst_rd_n_i,
      clk_rd_i          => clk_rd_i,
      q_o               => q_o,
      rd_i              => rd_i,
      rd_empty_o        => rd_empty_o,
      rd_full_o         => rd_full_o,
      rd_almost_empty_o => rd_almost_empty_o,
      rd_almost_full_o  => rd_almost_full_o,
      rd_count_o        => rd_count_o);

end arch;
