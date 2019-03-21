-------------------------------------------------------------------------------
-- Title      : WBGEN components
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : wbgen2_dpssram.vhd
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

--use work.genram_pkg.all;
--use work.common_components.all;

--library wbgen2;
use work.wbgen2_pkg.all;

entity wbgen2_dpssram is

  generic (
    g_data_width : natural := 32;
    g_size       : natural := 1024;
    g_addr_width : natural := 10;
    g_dual_clock : boolean := true;
    g_use_bwsel  : boolean := true);

  port (
    clk_a_i : in std_logic;
    clk_b_i : in std_logic;

    addr_a_i : in std_logic_vector(g_addr_width-1 downto 0);
    addr_b_i : in std_logic_vector(g_addr_width-1 downto 0);

    data_a_i : in std_logic_vector(g_data_width-1 downto 0);
    data_b_i : in std_logic_vector(g_data_width-1 downto 0);

    data_a_o : out std_logic_vector(g_data_width-1 downto 0);
    data_b_o : out std_logic_vector(g_data_width-1 downto 0);

    bwsel_a_i : in std_logic_vector((g_data_width+7)/8-1 downto 0);
    bwsel_b_i : in std_logic_vector((g_data_width+7)/8-1 downto 0);

    rd_a_i : in std_logic;
    rd_b_i : in std_logic;

    wr_a_i : in std_logic;
    wr_b_i : in std_logic
    );

end wbgen2_dpssram;


architecture syn of wbgen2_dpssram is
    function f_log2_size (A : natural) return natural is
  begin
    for I in 1 to 64 loop               -- Works for up to 64 bits
      if (2**I > A) then
        return(I-1);
      end if;
    end loop;
    return(63);
  end function f_log2_size;

  component generic_dpram
    generic (
      g_data_width               : natural;
      g_size                     : natural;
      g_with_byte_enable         : boolean;
      g_addr_conflict_resolution : string := "dont_care";
      g_init_file                : string := "";
      g_dual_clock               : boolean);
    port (
      rst_n_i : in  std_logic := '1';
      clka_i  : in  std_logic;
      bwea_i  : in  std_logic_vector(g_data_width/8-1 downto 0);
      wea_i   : in  std_logic;
      aa_i    : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
      da_i    : in  std_logic_vector(g_data_width-1 downto 0);
      qa_o    : out std_logic_vector(g_data_width-1 downto 0);
      clkb_i  : in  std_logic;
      bweb_i  : in  std_logic_vector(g_data_width/8-1 downto 0);
      web_i   : in  std_logic;
      ab_i    : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
      db_i    : in  std_logic_vector(g_data_width-1 downto 0);
      qb_o    : out std_logic_vector(g_data_width-1 downto 0));
  end component;
begin

  wrapped_dpram: generic_dpram
    generic map (
      g_data_width               => g_data_width,
      g_size                     => g_size,
      g_with_byte_enable         => g_use_bwsel,
      g_dual_clock               => g_dual_clock)
    port map (
      rst_n_i => '1',
      clka_i  => clk_a_i,
      bwea_i  => bwsel_a_i,
      wea_i   => wr_a_i,
      aa_i    => addr_a_i,
      da_i    => data_a_i,
      qa_o    => data_a_o,
      clkb_i  => clk_b_i,
      bweb_i  => bwsel_b_i,
      web_i   => wr_b_i,
      ab_i    => addr_b_i,
      db_i    => data_b_i,
      qb_o    => data_b_o);
 
end syn;
