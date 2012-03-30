----------------------------------------------------------------------
----                                                              ----
---- Ultimate CRC.                                                ----
----                                                              ----
---- This file is part of the ultimate CRC projectt               ----
---- http://www.opencores.org/cores/ultimate_crc/                 ----
----                                                              ----
---- Description                                                  ----
---- CRC generator/checker, parallel implementation.              ----
----                                                              ----
----                                                              ----
---- To Do:                                                       ----
---- -                                                            ----
----                                                              ----
---- Author(s):                                                   ----
---- - Geir Drange, gedra@opencores.org                           ----
----                                                              ----
----------------------------------------------------------------------
----                                                              ----
---- Copyright (C) 2005 Authors and OPENCORES.ORG                 ----
----                                                              ----
---- This source file may be used and distributed without         ----
---- restriction provided that this copyright statement is not    ----
---- removed from the file and that any derivative work contains  ----
---- the original copyright notice and the associated disclaimer. ----
----                                                              ----
---- This source file is free software; you can redistribute it   ----
---- and/or modify it under the terms of the GNU General          ----
---- Public License as published by the Free Software Foundation; ----
---- either version 2.0 of the License, or (at your option) any   ----
---- later version.                                               ----
----                                                              ----
---- This source is distributed in the hope that it will be       ----
---- useful, but WITHOUT ANY WARRANTY; without even the implied   ----
---- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ----
---- PURPOSE. See the GNU General Public License for more details.----
----                                                              ----
---- You should have received a copy of the GNU General           ----
---- Public License along with this source; if not, download it   ----
---- from http://www.gnu.org/licenses/gpl.txt                     ----
----                                                              ----
----------------------------------------------------------------------
--
-- CVS Revision History
--
-- $Log: ucrc_par.vhd,v $
-- Revision 1.1  2005/05/09 15:58:38  gedra
-- Parallel implementation
--
-- Modified by T.W. for use in WhiteRabbit endpoint
-- 

library ieee;
use ieee.std_logic_1164.all;

entity crc_gen is
  generic (
-- polynomial of our CRC generator
    g_polynomial : std_logic_vector       := x"04C11DB7";
-- initial (after-reset) value of CRC
    g_init_value : std_logic_vector       := x"ffffffff";
-- residual value of CRC when matched
    g_residue    : std_logic_vector       := x"38fb2284";
-- width of full data input word 
    g_data_width : integer range 2 to 256 := 16;
-- width of smaller-than-full data input word
    g_half_width : integer range 2 to 256 := 8;
-- use synchronous reset when 1
    g_sync_reset : integer range 0 to 1   := 0;
-- dual-width mode (g_data_width - wide input word when 1 and g_half_width input
-- word when 0)
    g_dual_width : integer range 0 to 1   := 0);  -- use sync./async reset
  port (
    clk_i  : in std_logic;              -- clock
    rst_i  : in std_logic;              -- reset, active high
    en_i   : in std_logic;              -- enable input, active high
    half_i : in std_logic;              -- 1: input word has g_half_width bits
                                        -- 0: input word has g_data_width bits

    data_i : in std_logic_vector(g_data_width - 1 downto 0);  -- data input

    match_o : out std_logic;            -- CRC match flag: 1 - CRC matches

    crc_o : out std_logic_vector(g_polynomial'length - 1 downto 0));  -- CRC
                                                                      -- output value
end crc_gen;

architecture rtl of crc_gen is

  function f_reverse_vector (a : in std_logic_vector)
    return std_logic_vector is
    variable v_result : std_logic_vector(a'reverse_range);
  begin
    for i in a'range loop
      v_result(i) := a(i);
    end loop;
    return v_result;
  end;

  constant msb      : integer                        := g_polynomial'length - 1;
  constant init_msb : integer                        := g_init_value'length - 1;
  constant p        : std_logic_vector(msb downto 0) := g_polynomial;
  constant dw       : integer                        := g_data_width;
  constant pw       : integer                        := g_polynomial'length;
  type fb_array is array (dw downto 1) of std_logic_vector(msb downto 0);
  type dmsb_array is array (dw downto 1) of std_logic_vector(msb downto 1);
  signal crca       : fb_array;
  signal da, ma     : dmsb_array;
  signal crc, zero  : std_logic_vector(msb downto 0);
  signal arst, srst : std_logic;

  signal a, b    : std_logic_vector(g_polynomial'length - 1 downto 0);
  signal data_i2 : std_logic_vector(15 downto 0);
  signal en_d0   : std_logic;
  signal half_d0 : std_logic;
  signal crc_tmp : std_logic_vector(31 downto 0);
  signal crc_int : std_logic_vector(31 downto 0);
    

    
begin

  a <= g_init_value;
  b <= g_polynomial;

-- Parameter checking: Invalid generics will abort simulation/synthesis
  PCHK1 : if msb /= init_msb generate
    process
    begin
      report "g_polynomial and g_init_value vectors must be equal length!"
        severity failure;
      wait;
    end process;
  end generate PCHK1;

  PCHK2 : if (msb < 3) or (msb > 31) generate
    process
    begin
      report "g_polynomial must be of order 4 to 32!"
        severity failure;
      wait;
    end process;
  end generate PCHK2;

  PCHK3 : if p(0) /= '1' generate       -- LSB must be 1
    process
    begin
      report "g_polynomial must have lsb set to 1!"
        severity failure;
      wait;
    end process;
  end generate PCHK3;

  data_i2(15 downto 0) <= (data_i(7 downto 0) & data_i(15 downto 8));
--  data_i2(15 downto 0) <= f_reverse_vector(data_i(15 downto 0));

-- Generate vector of each data bit
  CA : for i in 1 to dw generate        -- data bits
    DAT : for j in 1 to msb generate
      da(i)(j) <= data_i2(i - 1);
    end generate DAT;
  end generate CA;

-- Generate vector of each CRC MSB
  MS0 : for i in 1 to msb generate
    ma(1)(i) <= crc(msb);
  end generate MS0;
  MSP : for i in 2 to dw generate
    MSU : for j in 1 to msb generate
      ma(i)(j) <= crca(i - 1)(msb);
    end generate MSU;
  end generate MSP;

-- Generate feedback matrix
  crca(1)(0)            <= da(1)(1) xor crc(msb);
  crca(1)(msb downto 1) <= crc(msb - 1 downto 0) xor ((da(1) xor ma(1)) and p(msb downto 1));
  FB : for i in 2 to dw generate
    crca(i)(0)            <= da(i)(1) xor crca(i - 1)(msb);
    crca(i)(msb downto 1) <= crca(i - 1)(msb - 1 downto 0) xor
                             ((da(i) xor ma(i)) and p(msb downto 1));
  end generate FB;

-- Reset signal
  SR : if g_sync_reset = 1 generate
    srst <= rst_i;
    arst <= '0';
  end generate SR;
  AR : if g_sync_reset = 0 generate
    srst <= '0';
    arst <= rst_i;
  end generate AR;

-- CRC process
  crc_tmp <= f_reverse_vector(not crc);
  crc_int <= crc_tmp(7 downto 0) & crc_tmp(15 downto 8) & crc_tmp(23 downto 16) & crc_tmp(31 downto 24);
  zero  <= (others => '0');

  crc_o <= crc_int;
  
  CRCP : process (clk_i, arst)
  begin
    if arst = '1' then                  -- async. reset
      crc     <= g_init_value;
      half_d0 <= '0';
    elsif rising_edge(clk_i) then
      if srst = '1' then                -- sync. reset
        crc <= g_init_value;
      elsif en_i = '1' then
        
        if(half_i = '1' and g_dual_width = 1) then
          crc <= crca(g_half_width);
        else
          crc <= crca(g_data_width);
        end if;
      end if;
    end if;
  end process;

  match_gen : process (clk_i, arst)
  begin
    if arst = '1' then                  -- async. reset
      match_o <= '0';
      en_d0 <= '0';
    elsif rising_edge(clk_i) then
      if srst = '1' then                -- sync. reset
        match_o <= '0';
        en_d0 <= '0';
      else
        en_d0 <= en_i;

        if(en_d0 = '1') then
          if crc_int = g_residue then
            match_o <= '1';
          else
            match_o <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;
  

  
end rtl;

