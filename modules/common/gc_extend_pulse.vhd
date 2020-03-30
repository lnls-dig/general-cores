-------------------------------------------------------------------------------
-- Title      : Pulse width extender
-- Project    : General Cores library
-------------------------------------------------------------------------------
-- File       : gc_extend_pulse.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN
-- Created    : 2009-09-01
-- Last update: 2020-03-30
-- Platform   : FPGA-generic
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description:
-- Synchronous pulse extender. Generates a pulse of programmable width upon
-- detection of a rising edge in the input.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2009-2011 CERN
--
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 0.51 (the "License") (which enables you, at your option,
-- to treat this file as licensed under the Apache License 2.0); you may not
-- use this file except in compliance with the License. You may obtain a copy
-- of the License at http://solderpad.org/licenses/SHL-0.51.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
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

entity gc_extend_pulse is
  
  generic (
    -- output pulse width in clk_i cycles
    g_width : natural := 1000
    );
  port (
    clk_i      : in  std_logic;
    rst_n_i    : in  std_logic;
    -- input pulse (synchronou to clk_i)
    pulse_i    : in  std_logic;
    -- extended output pulse
    extended_o : out std_logic := '0');
end gc_extend_pulse;

architecture rtl of gc_extend_pulse is

  signal cntr : unsigned(f_log2_ceil(g_width)-1 downto 0);
  signal extended_int : std_logic;
  
begin  -- rtl

  extend : process (clk_i, rst_n_i)
  begin  -- process extend
    if rst_n_i = '0' then                   -- asynchronous reset (active low)
      extended_int <= '0';
      cntr       <= (others => '0');
    elsif clk_i'event and clk_i = '1' then  -- rising clock edge
      if(pulse_i = '1') then
        extended_int <= '1';
        cntr       <= to_unsigned(g_width - 2, cntr'length);
      elsif cntr /= to_unsigned(0, cntr'length) then
        cntr <= cntr - 1;
      else
        extended_int <= '0';
      end if;
    end if;
  end process extend;

  extended_o <= pulse_i or extended_int;

end rtl;

