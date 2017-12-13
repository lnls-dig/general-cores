-------------------------------------------------------------------------------
-- Title      : Parametrized delay block
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : gc_delay_line.vhd
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Copyright (c) 2011-2017 CERN
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
use ieee.numeric_std.all;

use work.genram_pkg.all;

entity gc_delay_line is
  generic (
    g_delay : integer;
    g_width : integer);
  port (
    clk_i   : in std_logic;
    rst_n_i : in std_logic;

    d_i : in  std_logic_vector(g_width -1 downto 0);
    q_o : out std_logic_vector(g_width -1 downto 0);

    ready_o : out std_logic);

end gc_delay_line;

architecture rtl of gc_delay_line is

  constant c_counter_width : integer := f_log2_size(g_delay+1);

  signal rd_ptr : unsigned(c_counter_width-1 downto 0) := (others => '0');
  signal wr_ptr : unsigned(c_counter_width-1 downto 0) := (others => '0');

  signal init : std_logic;

  signal wr_data, rd_data : std_logic_vector(g_width-1 downto 0);
begin

  U_DPRAM : generic_dpram
    generic map (
      g_data_width => g_width,
      g_size       => 2**c_counter_width,
      g_dual_clock => FALSE)
    port map (
      rst_n_i => rst_n_i,
      clka_i  => clk_i,
      bwea_i  => (others => '0'),
      wea_i   => '1',
      aa_i    => std_logic_vector(wr_ptr),
      da_i    => wr_data,
      clkb_i  => clk_i,
      bweb_i  => (others => '0'),
      web_i   => '0',
      ab_i    => std_logic_vector(rd_ptr),
      db_i    => (others => '0'),
      qb_o    => rd_data);


  wr_data <= (others => '0') when init = '1' else d_i;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        wr_ptr  <= (others => '0');
        rd_ptr  <= (others => '0');
        init    <= '1';
        ready_o <= '0';
      else
        if (init = '1') then
          if (wr_ptr = 2**c_counter_width-1) then
            wr_ptr  <= to_unsigned(g_delay-1, c_counter_width);
            rd_ptr  <= (others => '0');
            init    <= '0';
            ready_o <= '1';
          else
            wr_ptr <= wr_ptr + 1;
          end if;

        else
          wr_ptr <= wr_ptr + 1;
          rd_ptr <= rd_ptr + 1;
        end if;
      end if;
    end if;

  end process;

  q_o <= rd_data;

end rtl;
