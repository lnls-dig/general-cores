
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://gitlab.com/ohwr/project/general-cores
-------------------------------------------------------------------------------
-- File       : generic_async_fifo_dual_rst.vhd
-- Company    : CERN BE-CO-HT
-------------------------------------------------------------------------------
-- Description: Dual-clock asynchronous FIFO. 
-- - configurable data width and size
-- - configurable full/empty/almost full/almost empty/word count signals
-- - dual synchronous reset
-------------------------------------------------------------------------------
-- Copyright (c) 2011-2018 CERN
-------------------------------------------------------------------------------
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
use work.v6_fifo_pkg.all;

entity generic_async_fifo_dual_rst is

  generic (
    g_data_width : natural;
    g_size       : natural;
    g_show_ahead : boolean := false;

    -- Read-side flag selection
    g_with_rd_empty        : boolean := true;   -- with empty flag
    g_with_rd_full         : boolean := false;  -- with full flag
    g_with_rd_almost_empty : boolean := false;
    g_with_rd_almost_full  : boolean := false;
    g_with_rd_count        : boolean := false;  -- with words counter

    g_with_wr_empty        : boolean := false;
    g_with_wr_full         : boolean := true;
    g_with_wr_almost_empty : boolean := false;
    g_with_wr_almost_full  : boolean := false;
    g_with_wr_count        : boolean := false;

    g_almost_empty_threshold : integer;  -- threshold for almost empty flag
    g_almost_full_threshold  : integer   -- threshold for almost full flag
    );

  port (
    -- write port
    rst_wr_n_i        : in std_logic;
    clk_wr_i          : in std_logic;
    d_i               : in std_logic_vector(g_data_width-1 downto 0);
    we_i              : in std_logic;
    wr_empty_o        : out std_logic;
    wr_full_o         : out std_logic;
    wr_almost_empty_o : out std_logic;
    wr_almost_full_o  : out std_logic;
    wr_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0);
    -- read port
    rst_rd_n_i        : in std_logic;
    clk_rd_i          : in  std_logic;
    q_o               : out std_logic_vector(g_data_width-1 downto 0);
    rd_i              : in  std_logic;
    rd_empty_o        : out std_logic;
    rd_full_o         : out std_logic;
    rd_almost_empty_o : out std_logic;
    rd_almost_full_o  : out std_logic;
    rd_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0)
    );

end generic_async_fifo_dual_rst;


architecture syn of generic_async_fifo_dual_rst is

  component inferred_async_fifo_dual_rst
    generic (
      g_data_width             : natural;
      g_size                   : natural;
      g_show_ahead             : boolean;
      g_with_rd_empty          : boolean;
      g_with_rd_full           : boolean;
      g_with_rd_almost_empty   : boolean;
      g_with_rd_almost_full    : boolean;
      g_with_rd_count          : boolean;
      g_with_wr_empty          : boolean;
      g_with_wr_full           : boolean;
      g_with_wr_almost_empty   : boolean;
      g_with_wr_almost_full    : boolean;
      g_with_wr_count          : boolean;
      g_almost_empty_threshold : integer;
      g_almost_full_threshold  : integer);
    port (
      rst_wr_n_i        : in  std_logic;
      clk_wr_i          : in  std_logic;
      d_i               : in  std_logic_vector(g_data_width-1 downto 0);
      we_i              : in  std_logic;
      wr_empty_o        : out std_logic;
      wr_full_o         : out std_logic;
      wr_almost_empty_o : out std_logic;
      wr_almost_full_o  : out std_logic;
      wr_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0);
      rst_rd_n_i        : in  std_logic;
      clk_rd_i          : in  std_logic;
      q_o               : out std_logic_vector(g_data_width-1 downto 0);
      rd_i              : in  std_logic;
      rd_empty_o        : out std_logic;
      rd_full_o         : out std_logic;
      rd_almost_empty_o : out std_logic;
      rd_almost_full_o  : out std_logic;
      rd_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0));
  end component;
  
  component v6_hwfifo_wraper
    generic (
      g_data_width             : natural;
      g_size                   : natural;
      g_dual_clock             : boolean;
      g_almost_empty_threshold : integer;
      g_almost_full_threshold  : integer);
    port (
      rst_n_i           : in  std_logic := '1';
      clk_wr_i          : in  std_logic;
      clk_rd_i          : in  std_logic;
      d_i               : in  std_logic_vector(g_data_width-1 downto 0);
      we_i              : in  std_logic;
      q_o               : out std_logic_vector(g_data_width-1 downto 0);
      rd_i              : in  std_logic;
      rd_empty_o        : out std_logic;
      wr_full_o         : out std_logic;
      rd_almost_empty_o : out std_logic;
      wr_almost_full_o  : out std_logic;
      rd_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0);
      wr_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0));
  end component;

  constant m : t_v6_fifo_mapping := f_v6_fifo_find_mapping(g_data_width, g_size);

  -- Xilinx defines almost full threshold as number of available empty words in
  -- FIFO (UG363 - Virtex 6 FPGA Memory Resources
  constant c_virtex_almost_full_thr : integer := g_size - g_almost_full_threshold;

  signal rst_n : std_logic;

begin  -- syn

  rst_n <= rst_wr_n_i and rst_rd_n_i;

   gen_inferred : if(m.d_width = 0 or g_with_wr_count or g_with_rd_count) generate
    assert false report "generic_async_fifo_dual_rst[xilinx]: using inferred BRAM-based FIFO." severity note;

    U_Inferred_FIFO: inferred_async_fifo_dual_rst
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

    
   end generate gen_inferred;

  gen_native : if(m.d_width > 0 and not g_with_wr_count and not g_with_rd_count) generate

    U_Native_FIFO: v6_hwfifo_wraper
      generic map (
        g_data_width             => g_data_width,
        g_size                   => g_size,
        g_dual_clock             => true,
        g_almost_empty_threshold => f_empty_thr(g_with_rd_almost_empty, g_almost_empty_threshold, g_size),
        g_almost_full_threshold  => f_empty_thr(g_with_wr_almost_full, c_virtex_almost_full_thr, g_size))
      port map (
        rst_n_i           => rst_n,
        clk_wr_i          => clk_wr_i,
        clk_rd_i          => clk_rd_i,
        d_i               => d_i,
        we_i              => we_i,
        q_o               => q_o,
        rd_i              => rd_i,
        rd_empty_o        => rd_empty_o,
        wr_full_o         => wr_full_o,
        rd_almost_empty_o => rd_almost_empty_o,
        wr_almost_full_o  => wr_almost_full_o,
        rd_count_o        => rd_count_o,
        wr_count_o        => wr_count_o);
  end generate gen_native;


   
end syn;
