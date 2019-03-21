-------------------------------------------------------------------------------
-- Title      : WBGEN components
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : wbgen2_fifo_async.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Copyright (c) 2011 CERN
--
-- This source file is free software; you can redistribute it
-- and/or modify it under the terms of the GNU Lesser General
-- Public License as published by the Free Software Foundation;
-- either version 2.1 of the License, or (at your option) any
-- later version.
--
-- This source is distributed in the hope that it will be
-- useful, but WITHOUT ANY WARRANTY; without even the implied
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
-- PURPOSE.  See the GNU Lesser General Public License for more
-- details.
--
-- You should have received a copy of the GNU Lesser General
-- Public License along with this source; if not, download it
-- from http://www.gnu.org/licenses/lgpl-2.1.html
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.genram_pkg.all;
use work.wbgen2_pkg.all;

entity wbgen2_fifo_async is
  generic (
    g_size       : integer;
    g_width      : integer;
    g_usedw_size : integer
    );

  port
    (
      rst_n_i : in std_logic := '1';

      rd_clk_i  : in  std_logic;
      rd_req_i  : in  std_logic;
      rd_data_o : out std_logic_vector(g_width-1 downto 0);

      rd_empty_o : out std_logic;
      rd_full_o  : out std_logic;
      rd_usedw_o : out std_logic_vector(g_usedw_size -1 downto 0);


      wr_clk_i  : in std_logic;
      wr_req_i  : in std_logic;
      wr_data_i : in std_logic_vector(g_width-1 downto 0);

      wr_empty_o : out std_logic;
      wr_full_o  : out std_logic;
      wr_usedw_o : out std_logic_vector(g_usedw_size -1 downto 0)
      );
end wbgen2_fifo_async;

architecture rtl of wbgen2_fifo_async is

  component generic_async_fifo
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
      rst_n_i           : in  std_logic := '1';
      clk_wr_i          : in  std_logic;
      d_i               : in  std_logic_vector(g_data_width-1 downto 0);
      we_i              : in  std_logic;
      wr_empty_o        : out std_logic;
      wr_full_o         : out std_logic;
      wr_almost_empty_o : out std_logic;
      wr_almost_full_o  : out std_logic;
      wr_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0);
      clk_rd_i          : in  std_logic;
      q_o               : out std_logic_vector(g_data_width-1 downto 0);
      rd_i              : in  std_logic;
      rd_empty_o        : out std_logic;
      rd_full_o         : out std_logic;
      rd_almost_empty_o : out std_logic;
      rd_almost_full_o  : out std_logic;
      rd_count_o        : out std_logic_vector(f_log2_size(g_size)-1 downto 0));
  end component;

begin

  wrapped_fifo : generic_async_fifo
    generic map (
      g_data_width             => g_width,
      g_size                   => g_size,
      g_show_ahead             => false,
      g_with_rd_empty          => true,
      g_with_rd_full           => true,
      g_with_rd_almost_empty   => false,
      g_with_rd_almost_full    => false,
      g_with_rd_count          => true,
      g_with_wr_empty          => true,
      g_with_wr_full           => true,
      g_with_wr_almost_empty   => false,
      g_with_wr_almost_full    => false,
      g_with_wr_count          => true,
      g_almost_empty_threshold => 0,
      g_almost_full_threshold  => 0)
    port map (
      rst_n_i           => rst_n_i,
      clk_wr_i          => wr_clk_i,
      d_i               => wr_data_i,
      we_i              => wr_req_i,
      wr_empty_o        => wr_empty_o,
      wr_full_o         => wr_full_o,
      wr_almost_empty_o => open,
      wr_almost_full_o  => open,
      wr_count_o        => wr_usedw_o,
      clk_rd_i          => rd_clk_i,
      q_o               => rd_data_o,
      rd_i              => rd_req_i,
      rd_empty_o        => rd_empty_o,
      rd_full_o         => rd_full_o,
      rd_almost_empty_o => open,
      rd_almost_full_o  => open,
      rd_count_o        => rd_usedw_o);

end rtl;
