--==============================================================================
-- CERN (BE-CO-HT)
-- Glitch filter with selectable length
--==============================================================================
--
-- author: Theodor Stana (t.stana@cern.ch)
--
-- date of creation: 2013-03-12
--
-- version: 1.0
--
-- description:
--
-- dependencies:
--
-- references:
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
-- last changes:
--    2013-03-12   Theodor Stana     t.stana@cern.ch     File created
--==============================================================================
-- TODO: -
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

entity gc_glitch_filt is
  generic
  (
    -- Length of glitch filter:
    -- g_len = 1 => data width should be > 1 clk_i cycle
    -- g_len = 2 => data width should be > 2 clk_i cycle
    -- etc.
    g_len : natural := 4
  );
  port
  (
    clk_i   : in  std_logic;
    rst_n_i : in  std_logic;

    -- Data input
    dat_i   : in  std_logic;

    -- Data output
    -- latency: g_len+1 clk_i cycles
    dat_o   : out std_logic
  );
end entity gc_glitch_filt;


architecture behav of gc_glitch_filt is

  --============================================================================
  -- Component declarations
  --============================================================================
  component gc_sync_ffs is
    generic(
      g_sync_edge : string := "positive"
      );
    port(
      clk_i    : in  std_logic;  -- clock from the destination clock domain
      rst_n_i  : in  std_logic;           -- reset
      data_i   : in  std_logic;           -- async input
      synced_o : out std_logic;           -- synchronized output
      npulse_o : out std_logic;  -- negative edge detect output (single-clock
      -- pulse)
      ppulse_o : out std_logic   -- positive edge detect output (single-clock
     -- pulse)
      );
  end component gc_sync_ffs;

  --============================================================================
  -- Signal declarations
  --============================================================================
  signal gc_glitch_filt : std_logic_vector(g_len downto 0);
  signal dat_synced  : std_logic;

--==============================================================================
--  architecture begin
--==============================================================================
begin

  --============================================================================
  -- Glitch filtration logic
  --============================================================================
  -- First, synchronize the data input in the clk_i domain
  cmp_sync : gc_sync_ffs
    port map
    (
      clk_i    => clk_i,
      rst_n_i  => rst_n_i,
      data_i   => dat_i,
      synced_o => dat_synced,
      npulse_o => open,
      ppulse_o => open
    );

  -- Then, assign the current sample of the glitch filter
  gc_glitch_filt(0) <= dat_synced;

  -- Generate glitch filter FFs when the filter length is > 0
  gen_glitch_filt: if (g_len > 0) generate
    p_glitch_filt: process (clk_i)
    begin
      if rising_edge(clk_i) then
        if (rst_n_i = '0') then
          gc_glitch_filt(g_len downto 1) <= (others => '0');
        else
          gc_glitch_filt(g_len downto 1) <= gc_glitch_filt(g_len-1 downto 0);
        end if;
      end if;
    end process p_glitch_filt;
  end generate gen_glitch_filt;

  -- and set the data output based on the state of the glitch filter
  p_output: process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        dat_o <= '0';
      elsif (gc_glitch_filt = (gc_glitch_filt'range => '1')) then
        dat_o <= '1';
      elsif (gc_glitch_filt = (gc_glitch_filt'range => '0')) then
        dat_o <= '0';
      end if;
    end if;
  end process p_output;

end architecture behav;
--==============================================================================
--  architecture end
--==============================================================================
