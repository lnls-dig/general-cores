--! @file gc_big_adder.vhd
--! @brief Formerly eca_adder.vhd A pipelined adder for fast and wide arithmetic
--! @author Wesley W. Terpstra <w.terpstra@gsi.de>
--! 
--! Copyright (C) 2013 GSI Helmholtz Centre for Heavy Ion Research GmbH 
--!
--! The pipeline has three stages: partial sum, propogate carry, full sum
--! The inputs should be registers.
--! The outputs are provided at the end of each stage and should be registered.
--! The high carry bit is available one pipeline stage earlier than the full sum.
--! The high carry bit can be used to implement a comparator.
--!
--------------------------------------------------------------------------------
-- Renamed and moved to common -Mathias Kreider
-- 
--! This library is free software; you can redistribute it and/or
--! modify it under the terms of the GNU Lesser General Public
--! License as published by the Free Software Foundation; either
--! version 3 of the License, or (at your option) any later version.
--!
--! This library is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
--! Lesser General Public License for more details.
--!  
--! You should have received a copy of the GNU Lesser General Public
--! License along with this library. If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.wishbone_pkg.all;
use work.gencores_pkg.all;

-- Expects registers for inputs. Async outputs.
-- c1_o is available after 1 cycle (2 once registered)
-- c2_o, x2_o are available after 2 cycles (3 once registered)
entity gc_big_adder is
  generic(
    g_data_bits : natural := 64;
    g_parts     : natural := 4);
  port(
    clk_i   : in  std_logic;
    stall_i : in  std_logic := '0';
    a_i     : in  std_logic_vector(g_data_bits-1 downto 0);
    b_i     : in  std_logic_vector(g_data_bits-1 downto 0);
    c_i     : in  std_logic := '0';
    c1_o    : out std_logic;
    x2_o    : out std_logic_vector(g_data_bits-1 downto 0);
    c2_o    : out std_logic);
end gc_big_adder;

architecture rtl of gc_big_adder is
  -- Out of principle, tell quartus to leave my design alone.
  attribute altera_attribute : string; 
  attribute altera_attribute of rtl : architecture is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
  
  constant c_parts    : natural := g_parts; -- Must divide g_data_bits
  constant c_sub_bits : natural := g_data_bits / c_parts;
  
  subtype t_part  is std_logic_vector(c_sub_bits-1 downto 0);
  subtype t_carry is std_logic_vector(c_parts   -1 downto 0);
  type t_part_array is array(c_parts-1 downto 0) of t_part;
  
  constant c_zeros : t_part := (others => '0');
  
  -- Pipeline:
  --   s1: partial sums / prop+gen
  --   s2:                carry bits
  --   s3: full sum

  -- Registers
  signal r1_sum0 : t_part_array;
  --signal r1_sum1 : t_part_array;
  signal r1_p    : t_carry;
  signal r1_g    : t_carry;
  signal r1_c    : std_logic;
  signal r2_sum0 : t_part_array;
  --signal r2_sum1 : t_part_array;
  signal r2_c    : t_carry;
  signal r2_cH   : std_logic;
  
  -- Signals
  signal s1_r : std_logic_vector(c_parts downto 0);
  
begin
  s1_r <= f_big_ripple(r1_p, r1_g, r1_c);
  
  main : process(clk_i) is
    variable sum0, sum1 : std_logic_vector(c_sub_bits downto 0);
  begin
    if rising_edge(clk_i) then
      if stall_i = '0' then
        for i in 0 to c_parts-1 loop
          sum0 := f_big_ripple(a_i((i+1)*c_sub_bits-1 downto i*c_sub_bits),
                               b_i((i+1)*c_sub_bits-1 downto i*c_sub_bits), '0');
          sum1 := f_big_ripple(a_i((i+1)*c_sub_bits-1 downto i*c_sub_bits),
                               b_i((i+1)*c_sub_bits-1 downto i*c_sub_bits), '1');
          
          r1_sum0(i) <= sum0(c_sub_bits-1 downto 0);
          --r1_sum1(i) <= sum1(c_sub_bits-1 downto 0);
          r1_g(i)  <= sum0(c_sub_bits);
          r1_p(i)  <= sum1(c_sub_bits);
        end loop;
        
        r1_c    <= c_i;
        r2_c    <= s1_r(c_parts-1 downto 0) xor (r1_p xor r1_g);
        r2_cH   <= s1_r(c_parts);
        r2_sum0 <= r1_sum0;
        --r2_sum1 <= r1_sum1;
      end if;
    end if;
  end process;
  
  c1_o <= s1_r(c_parts);
  c2_o <= r2_cH;
  
  output : for i in 0 to c_parts-1 generate
    -- save the sum1 registers by using an adder instead of MUX
    x2_o((i+1)*c_sub_bits-1 downto i*c_sub_bits) <= 
      f_big_ripple(r2_sum0(i), c_zeros, r2_c(i))
      (c_sub_bits-1 downto 0);
    --  r2_sum1(i) when r2_c(i)='1' else r2_sum0(i);
  end generate;
  
end rtl;
