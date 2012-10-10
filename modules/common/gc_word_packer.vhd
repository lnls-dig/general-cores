-------------------------------------------------------------------------------
-- Title      : Word packer/unpacker
-- Project    : General Cores Collection library
-------------------------------------------------------------------------------
-- File       : gc_word_packer.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN
-- Created    : 2012-09-13
-- Last update: 2012-09-13
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Packs/unpacks g_input_width-sized word(s) into g_output_width-
-- sized word(s). Data is packed starting from the least significant word.
-- Packet width must be integer multiple of the unpacked width.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2012 CERN / BE-CO-HT
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
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.genram_pkg.all;

entity gc_word_packer is

  generic(
    -- width of the input words
    g_input_width  : integer;
    -- width of the output words
    g_output_width : integer);

  port(
    clk_i   : in std_logic;
    rst_n_i : in std_logic;

    -- input data
    d_i       : in  std_logic_vector(g_input_width-1 downto 0);
    -- input data valid
    d_valid_i : in  std_logic;
    -- synchronous input data request, when active, the source
    -- is allowed to assert d_valid_i in next clock cycle.
    d_req_o   : out std_logic;

    -- flushes packer input, immediately outputting (incomplete) packed word to q_o
    -- even if the number of input words is less than g_output_width.
    -- Unused when g_input_width > g_output_width (unpacking)
    flush_i : in std_logic := '0';

    -- data output
    q_o       : out std_logic_vector(g_output_width-1 downto 0);
    -- data output valid
    q_valid_o : out std_logic;
    -- synchronous data request: if active, packer can output data in following
    -- clock cycle.
    q_req_i   : in  std_logic
    );

end gc_word_packer;

architecture rtl of gc_word_packer is

  function f_max(a : integer; b : integer) return integer is
  begin
    if(a > b) then
      return a;
    else
      return b;
    end if;
  end f_max;

  function f_min(a : integer; b : integer) return integer is
  begin
    if(a < b) then
      return a;
    else
      return b;
    end if;
  end f_min;

  constant c_sreg_size    : integer := f_max(g_input_width, g_output_width);
  constant c_sreg_entries : integer := c_sreg_size / f_min(g_input_width, g_output_width);

  signal sreg  : std_logic_vector(c_sreg_size-1 downto 0);
  signal count : unsigned(f_log2_size(c_sreg_entries + 1) - 1 downto 0);
  signal empty : std_logic;

  signal q_valid_comb, q_valid_reg, q_req_d0 : std_logic;
  
begin  -- rtl

-- Fixme: flush functionality.
  
  gen_grow : if(g_output_width > g_input_width) generate
    p_grow : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if rst_n_i = '0' then
          count <= (others => '0');
        else

          if(d_valid_i = '1') then
            if(q_valid_reg = '0') then
              sreg(to_integer(count) * g_input_width + g_input_width-1 downto to_integer(count) * g_input_width) <= d_i;
            else
              sreg(g_input_width-1 downto 0) <= d_i;
            end if;
          end if;

          if(q_valid_comb = '1') then
            count <= (others => '0');
          elsif(d_valid_i = '1') then
            count <= count + 1;
          end if;

          q_valid_reg <= q_valid_comb;
          
        end if;
      end if;
    end process;

    q_valid_o    <= q_valid_reg;
    q_valid_comb <= '1' when (q_req_i = '1' and (count = c_sreg_entries or (count = c_sreg_entries-1 and d_valid_i = '1'))) else '0';

    d_req_o <= '1' when q_req_i = '1' and (count /= c_sreg_entries) else '0';
    q_o     <= sreg;
  end generate gen_grow;

  gen_shrink : if(g_output_width < g_input_width) generate

    p_shrink : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if rst_n_i = '0' then
          count    <= (others => '0');
          empty    <= '1';
          q_req_d0 <= '0';
        else

          q_req_d0 <= q_req_i;

          if(d_valid_i = '1') then
            sreg <= d_i;
          end if;

          if(count = c_sreg_entries-1 and d_valid_i = '0' and q_valid_comb = '1') then
            empty <= '1';
          elsif(d_valid_i = '1') then
            empty <= '0';
          end if;

          if(q_valid_comb = '1') then
            if(count = c_sreg_entries-1) then
              count <= (others => '0');
            else
              count <= count + 1;
            end if;
          end if;

        end if;
      end if;
    end process;

    q_valid_o <= q_valid_comb;

    d_req_o <= '1' when d_valid_i = '0' and (empty = '1' or (q_req_i = '1' and count = c_sreg_entries-1)) else '0';
    p_gen_output : process(count, sreg, empty, d_i, d_valid_i, q_req_d0)
    begin
      if (q_req_d0 = '1' and empty = '0') then
        q_valid_comb <= '1';
        q_o          <= sreg(to_integer(count) * g_output_width + g_output_width-1 downto to_integer(count) * g_output_width);
      elsif (empty = '1' and d_valid_i = '1' and q_req_d0 = '1') then
        q_valid_comb <= '1';
        q_o          <= d_i(g_output_width-1 downto 0);
      else
        q_valid_comb <= '0';
        q_o          <= (others => 'X');
      end if;
    end process;
  end generate gen_shrink;

  gen_equal : if(g_output_width = g_input_width) generate
    q_o       <= d_i;
    q_valid_o <= d_valid_i;
    d_req_o   <= q_req_i;
  end generate gen_equal;

end rtl;
