-------------------------------------------------------------------------------
-- Title      : Cheby components
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : cheby_dpssram.vhd
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Copyright (c) 2020 CERN
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
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

--  This entity is instantiated by cheby when a dual-port RAM is used.
--  This is just a wrapper that could be changed by users.
--  The generics only use integers/logic to be compatible with verilog.

entity cheby_dpssram is
  generic (
    g_data_width : natural := 32;
    g_size       : natural := 1024;
    g_addr_width : natural := 10;
    g_dual_clock : std_logic := '1';
    g_use_bwsel  : std_logic := '1');

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

end cheby_dpssram;

architecture syn of cheby_dpssram is
begin
  wrapped_dpram: entity work.generic_dpram
    generic map (
      g_data_width               => g_data_width,
      g_size                     => g_size,
      g_with_byte_enable         => g_use_bwsel = '1',
      g_dual_clock               => g_dual_clock = '1')
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
