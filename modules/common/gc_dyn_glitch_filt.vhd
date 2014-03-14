--==============================================================================
-- CERN (BE-CO-HT)
-- Glitch filter with dynamically selectable length
--==============================================================================
--
-- author: Theodor Stana (t.stana@cern.ch)
--         Matthieu Cattin (matthieu.cattin@cern.ch)
--
-- date of creation: 2014-03-13
--
-- version: 1.0
--
-- description:
--    Glitch filter consisting of a set of chained flip-flops followed by a
--    comparator. The comparator toggles to '1' when all FFs in the chain are
--    '1' and respectively to '0' when all the FFS in the chain are '0'.
--    Latency = len_i + 1.
--
-- dependencies:
--
-- references:
--    Based on gc_glitch_filter.vhd
--
--==============================================================================
-- GNU LESSER GENERAL PUBLIC LICENSE
--==============================================================================
-- This source file is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation; either version 2.1 of the License, or (at your
-- option) any later version. This source is distributed in the hope that it
-- will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU Lesser General Public License for more details. You should have
-- received a copy of the GNU Lesser General Public License along with this
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html
--==============================================================================
-- TODO: -
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

entity gc_dyn_glitch_filt is
  generic
    (
      -- Number of bit of the glitch filter length input
      g_len_width : natural := 8
      );
  port
    (
      clk_i   : in std_logic;
      rst_n_i : in std_logic;

      -- Glitch filter length
      len_i : in std_logic_vector(g_len_width-1 downto 0);

      -- Data input, synchronous to clk_i
      dat_i : in std_logic;

      -- Data output
      -- latency: g_len+1 clk_i cycles
      dat_o : out std_logic
      );
end entity gc_dyn_glitch_filt;


architecture behav of gc_dyn_glitch_filt is

  --============================================================================
  -- Constants declarations
  --============================================================================
  constant c_glitch_filt_width : natural := 2**g_len_width;

  --============================================================================
  -- Signal declarations
  --============================================================================
  signal glitch_filt : std_logic_vector(c_glitch_filt_width-1 downto 0);

--==============================================================================
--  architecture begin
--==============================================================================
begin

  --============================================================================
  -- Glitch filtration logic
  --============================================================================
  glitch_filt(0) <= dat_i;

  -- Glitch filter FFs
  p_glitch_filt : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        glitch_filt(c_glitch_filt_width-1 downto 1) <= (others => '0');
      else
        glitch_filt(c_glitch_filt_width-1 downto 1) <= glitch_filt(c_glitch_filt_width-2 downto 0);
      end if;
    end if;
  end process p_glitch_filt;


  -- Set the data output based on the state of the glitch filter
  p_output : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        dat_o <= '0';
      elsif (glitch_filt(to_integer(unsigned(len_i)) downto 0) = f_gen_dummy_vec('1', to_integer(unsigned(len_i))+1)) then
        dat_o <= '1';
      elsif (glitch_filt(to_integer(unsigned(len_i)) downto 0) = f_gen_dummy_vec('0', to_integer(unsigned(len_i))+1)) then
        dat_o <= '0';
      end if;
    end if;
  end process p_output;

end architecture behav;
--==============================================================================
--  architecture end
--==============================================================================
