-------------------------------------------------------------------------------
-- Title      : Parametrizable dual-port synchronous RAM (Xilinx version)
-- Project    : Generics RAMs and FIFOs collection
-------------------------------------------------------------------------------
-- File       : generic_simple_dpram.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-03-04
-- Last update: 2022-07-25
-- Platform   : 
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: True dual-port synchronous RAM for Xilinx FPGAs with:
-- - configurable address and data bus width
-- - byte-addressing mode (data bus width restricted to multiple of 8 bits)
-- Todo:
-- - loading initial contents from file
-- - add support for read-first/write-first address conflict resulution (only
--   supported by Xilinx in VHDL templates)
-------------------------------------------------------------------------------
-- Copyright (c) 2011 CERN
--
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 0.51 (the "License") (which enables you, at your option,
-- to treat this file as licensed under the Apache License 2.0); you may not
-- use this file except in compliance with the License. You may obtain a copy
-- of the License at http://solderpad.org/licenses/SHL-0.51.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-03-04  1.0      wterpstra       Initial version: wrapper to generic_dpram
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.genram_pkg.all;
use work.memory_loader_pkg.all;

entity generic_simple_dpram is

  generic (
    -- standard parameters
    g_data_width : natural := 32;
    g_size       : natural := 16384;

    g_with_byte_enable         : boolean := false;
    g_addr_conflict_resolution : string  := "read_first";
    g_init_file                : string  := "";
    g_dual_clock               : boolean := true;
    g_fail_if_file_not_found   : boolean := true;
    g_implementation_hint      : string  := "auto"
    );

  port (
    rst_n_i : in std_logic := '1';      -- synchronous reset, active LO

    -- Port A
    clka_i : in  std_logic;
    bwea_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
    wea_i  : in  std_logic;
    aa_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    da_i   : in  std_logic_vector(g_data_width-1 downto 0);
    
    -- Port B
    clkb_i : in  std_logic;
    ab_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    qb_o   : out std_logic_vector(g_data_width-1 downto 0)
    );

end generic_simple_dpram;



architecture syn of generic_simple_dpram is

begin

  -- Works well enough until a Xilinx guru can optimize it.
  true_dp : generic_dpram
    generic map(
      g_data_width               => g_data_width,
      g_size                     => g_size,
      g_with_byte_enable         => g_with_byte_enable,
      g_addr_conflict_resolution => g_addr_conflict_resolution,
      g_init_file                => g_init_file,
      g_dual_clock               => g_dual_clock,
      g_implementation_hint      => g_implementation_hint )
    port map(
      rst_n_i => rst_n_i,
      clka_i  => clka_i,
      bwea_i  => bwea_i,
      wea_i   => wea_i,
      aa_i    => aa_i,
      da_i    => da_i,
      qa_o    => open,
      clkb_i  => clkb_i,
      bweb_i  => f_zeros((g_data_width+7)/8),
      web_i   => '0',
      ab_i    => ab_i,
      db_i    => f_zeros(g_data_width),
      qb_o    => qb_o);

end syn;
