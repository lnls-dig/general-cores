-------------------------------------------------------------------------------
-- Title      : Serial DAC interface
-- Project    : White Rabbit
-------------------------------------------------------------------------------
-- File       : gc_serial_dac.vhd
-- Author     : Pablo Alvarez Sanchez
-- Company    : CERN BE-Co-HT
-- Created    : 2010-02-25
-- Last update: 2011-04-29
-- Platform   : FPGA-generic
-- Standard   : VHDL '87
-------------------------------------------------------------------------------
-- Description: The DAC unit provides an interface to a 16 bit serial Digital
-- to Analogue converter (MAX5441, AD5662, SPI/QSPI/MICROWIRE compatible) 
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
-- 2009-01-24  1.0      paas            Created
-- 2010-02-25  1.1      twlostow        Modified for rev 1.1 switch
-- 2016-08-24  1.2      jpospisi        removed synchronous reset from
--                                        sensitivity lists
-------------------------------------------------------------------------------

library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity gc_serial_dac is

  generic (
    -- number of DAC data word bits (LSBs)
    g_num_data_bits  : integer := 16;
    -- number of padding MSBs, sent as zeros
    g_num_extra_bits : integer := 8;
    -- number of chip select inputs
    g_num_cs_select  : integer := 2;
    -- serial clock polarity: 0 - data is outputted on rising-,
    -- 1 - on falling edge of SCLK
    g_sclk_polarity  : integer := 1
    );

  port (
-- clock & reset
    clk_i   : in std_logic;
    rst_n_i : in std_logic;

-- value to be written to the DAC
    value_i  : in std_logic_vector(g_num_data_bits-1 downto 0);
-- chip select vector. Setting bits to 1 enables writing to the corresponding
-- DAC
    cs_sel_i : in std_logic_vector(g_num_cs_select-1 downto 0);

-- when 1, value_i is valid.
    load_i : in std_logic;

-- SCLK divider: 000 = clk_i/8 ... 111 = clk_i/1024
    sclk_divsel_i : in std_logic_vector(2 downto 0);

-- DAC I/F
    dac_cs_n_o  : out std_logic_vector(g_num_cs_select-1 downto 0);
    dac_sclk_o  : out std_logic;
    dac_sdata_o : out std_logic;

-- when 1, the SPI interface is busy sending data to the DAC.
    busy_o : out std_logic
    );
end gc_serial_dac;


architecture syn of gc_serial_dac is

  signal divider        : unsigned(11 downto 0);
  signal dataSh         : std_logic_vector(g_num_data_bits + g_num_extra_bits-1 downto 0);
  signal bitCounter     : std_logic_vector(g_num_data_bits + g_num_extra_bits+1 downto 0);
  signal endSendingData : std_logic;
  signal sendingData    : std_logic;
  signal iDacClk        : std_logic;
  signal iValidValue    : std_logic;

  signal divider_muxed : std_logic;

  signal cs_sel_reg : std_logic_vector(g_num_cs_select-1 downto 0);
  
begin

  select_divider : process (divider, sclk_divsel_i)
  begin  -- process
    case sclk_divsel_i is
      when "000"  => divider_muxed <= divider(1);  -- sclk = clk_i/8
      when "001"  => divider_muxed <= divider(2);  -- sclk = clk_i/16
      when "010"  => divider_muxed <= divider(3);  -- sclk = clk_i/32
      when "011"  => divider_muxed <= divider(4);  -- sclk = clk_i/64
      when "100"  => divider_muxed <= divider(5);  -- sclk = clk_i/128
      when "101"  => divider_muxed <= divider(6);  -- sclk = clk_i/256
      when "110"  => divider_muxed <= divider(7);  -- sclk = clk_i/512
      when "111"  => divider_muxed <= divider(8);  -- sclk = clk_i/1024
      when others => null;
    end case;
  end process;


  iValidValue <= load_i;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        sendingData <= '0';
      else
        if iValidValue = '1' and sendingData = '0' then
          sendingData <= '1';
        elsif endSendingData = '1' then
          sendingData <= '0';
        end if;
      end if;
    end if;
  end process;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if iValidValue = '1' then
        divider <= (others => '0');
      elsif sendingData = '1' then
        if(divider_muxed = '1') then
          divider <= (others => '0');
        else
          divider <= divider + 1;
        end if;
      elsif endSendingData = '1' then
        divider <= (others => '0');
      end if;
    end if;
  end process;


  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        iDacClk <= '1';                 -- 0
      else
        if iValidValue = '1' then
          iDacClk <= '1';               -- 0
        elsif divider_muxed = '1' then
          iDacClk <= not(iDacClk);
        elsif endSendingData = '1' then
          iDacClk <= '1';               -- 0
        end if;
      end if;
    end if;
  end process;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        dataSh <= (others => '0');
      else
        if iValidValue = '1' and sendingData = '0' then
          cs_sel_reg                                 <= cs_sel_i;
          dataSh(g_num_data_bits-1 downto 0)         <= value_i;
          dataSh(dataSh'left downto g_num_data_bits) <= (others => '0');
        elsif sendingData = '1' and divider_muxed = '1' and iDacClk = '0' then
          dataSh(0)                    <= dataSh(dataSh'left);
          dataSh(dataSh'left downto 1) <= dataSh(dataSh'left - 1 downto 0);
        end if;
      end if;
    end if;
  end process;

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if iValidValue = '1' and sendingData = '0' then
        bitCounter(0)                        <= '1';
        bitCounter(bitCounter'left downto 1) <= (others => '0');
      elsif sendingData = '1' and to_integer(divider) = 0 and iDacClk = '1' then
        bitCounter(0)                        <= '0';
        bitCounter(bitCounter'left downto 1) <= bitCounter(bitCounter'left - 1 downto 0);
      end if;
    end if;
  end process;

  endSendingData <= bitCounter(bitCounter'left);

  busy_o <= SendingData;

  dac_sdata_o <= dataSh(dataSh'left);

  gen_cs_out : for i in 0 to g_num_cs_select-1 generate
    dac_cs_n_o(i) <= not(sendingData) or (not cs_sel_reg(i));
  end generate gen_cs_out;

  p_drive_sclk : process(iDacClk)
  begin
    if(g_sclk_polarity = 0) then
      dac_sclk_o <= iDacClk;
    else
      dac_sclk_o <= not iDacClk;
    end if;
  end process;

end syn;
