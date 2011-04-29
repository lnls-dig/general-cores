-------------------------------------------------------------------------------
-- Title      : Simple delay line generator
-- Project    : White Rabbit
-------------------------------------------------------------------------------
-- File       : gc_delay_gen.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-02-25
-- Last update: 2011-04-29
-- Platform   : FPGA-generic
-- Standard   : VHDL '87
------------------------------------------------------------------------------
-- Description: Simple N-bit delay line with programmable delay.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2009 - 2010 CERN
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
-- Revisions  :
-- Date        Version  Author          Description
-- 2010-02-25  1.0      twlostow        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.gencores_pkg.all;

entity gc_delay_gen is
  generic(
    g_delay_cycles : in natural;
    g_data_width   : in natural
    );

  port(clk_i   : in  std_logic;  
       rst_n_i : in  std_logic;  
       d_i     : in  std_logic_vector(g_data_width - 1 downto 0);
       q_o     : out std_logic_vector(g_data_width - 1 downto 0)
       );
end gc_delay_gen;


architecture behavioral of gc_delay_gen is

  type t_dly_array is array (0 to g_delay_cycles) of std_logic_vector(g_data_width -1 downto 0);
  signal dly : t_dly_array;
begin  -- behavioral

  p_delay_proc : process (clk_i, rst_n_i)
  begin  -- process delay_proc
    if rst_n_i = '0' then               -- asynchronous reset (active low)
      genrst : for i in 1 to g_delay_cycles loop
        dly(i) <= (others => '0');
      end loop;
    elsif rising_edge(clk_i) then       -- rising clock edge
      dly(0) <= d_i;
      gendly : for i in 0 to g_delay_cycles-1 loop
        dly(i+1) <= dly(i);
      end loop;
    end if;
  end process p_delay_proc;

  q_o <= dly(g_delay_cycles);
  
end behavioral;
