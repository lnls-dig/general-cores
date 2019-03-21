-------------------------------------------------------------------------------
-- Title      : Moving average filter
-- Project    : General Cores library
-------------------------------------------------------------------------------
-- File       : gc_moving_average.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN
-- Created    : 2009-09-01
-- Last update: 2017-10-11
-- Platform   : FPGA-generic
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description:
-- Simple averaging filter.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2009-2011 CERN
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
-- 2009-09-01  0.9      twlostow        Created
-- 2011-04-18  1.0      twlostow        Added comments & header
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.NUMERIC_STD.all;

library work;
use work.gencores_pkg.all;
use work.genram_pkg.all;

entity gc_moving_average is

  generic (
    -- input/output data width
    g_data_width : natural := 24;
    -- averaging window, expressed as 2 ** g_avg_log2
    g_avg_log2 : natural range 1 to 8 := 4
    );
  port (
    rst_n_i    : in  std_logic;
    clk_i      : in  std_logic;
    din_i      : in  std_logic_vector(g_data_width-1 downto 0);
    dout_o     : out std_logic_vector(g_data_width+g_avg_log2-1 downto 0);
    dout_stb_o : out std_logic
    );

end gc_moving_average;

architecture rtl of gc_moving_average is

  constant avg_steps : natural := 2**g_avg_log2;
  signal delay_dout  : std_logic_vector(g_data_width-1 downto 0);
  signal acc         : unsigned(g_data_width+g_avg_log2+1 downto 0);
  signal dly_ready   : std_logic;
begin  -- rtl

  U_delay : gc_delay_line
    generic map (
      g_delay => avg_steps,
      g_width => g_data_width)
    port map (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      d_i     => din_i,
      q_o     => delay_dout,
      ready_o => dly_ready);


  avg : process (clk_i)
  begin  -- process avgx
    if rising_edge(clk_i) then
      if rst_n_i = '0' or dly_ready /= '1' then
        acc        <= (others => '0');
        dout_stb_o <= '0';
      else
        acc        <= acc + unsigned(din_i) - unsigned(delay_dout);
        dout_stb_o <= '1';
      end if;
    end if;
  end process;

  dout_o <= std_logic_vector(acc(g_data_width+ g_avg_log2-1 downto 0));


end rtl;

