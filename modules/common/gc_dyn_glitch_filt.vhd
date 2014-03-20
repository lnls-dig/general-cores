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
  -- Signal declarations
  --============================================================================
  signal filt_cnt    : unsigned(g_len_width-1 downto 0);

--==============================================================================
--  architecture begin
--==============================================================================
begin


  -- Glitch filter
  p_glitch_filt : process (clk_i)
  begin
    if rising_edge (clk_i) then
      if rst_n_i = '0' then
        filt_cnt <= unsigned(len_i) srl 1;  -- middle value
        dat_o    <= '0';
      else
        -- Arrival of a '0'
        if dat_i = '0' then
          if filt_cnt /= 0 then             -- counter updated
            filt_cnt <= filt_cnt - 1;
          else
            dat_o <= '0';                   -- output updated
          end if;
          -- Arrival of a '1'
        elsif dat_i = '1' then
          if filt_cnt /= unsigned(len_i) then
            filt_cnt <= filt_cnt + 1;       -- counter updated
          else
            dat_o <= '1';                   -- output updated
          end if;
        end if;
      end if;
    end if;
  end process p_glitch_filt;

end architecture behav;
--==============================================================================
--  architecture end
--==============================================================================
