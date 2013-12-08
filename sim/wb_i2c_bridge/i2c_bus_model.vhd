--==============================================================================
-- CERN (BE-CO-HT)
-- I2C bus model
--==============================================================================
--
-- author: Theodor Stana (t.stana@cern.ch)
--
-- date of creation: 2013-11-27
--
-- version: 1.0
--
-- description:
--    A very simple I2C bus model for use in simulation, implementing the
--    wired-AND on the I2C protocol.
--
--    Masters and slaves should implement the buffers internally and connect the
--    SCL and SDA lines to the input ports of this model, as below:
--        - masters should connect to mscl_i and msda_i
--        - slaves should connect to sscl_i and ssda_i
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
--    2013-11-27   Theodor Stana     File created
--==============================================================================
-- TODO: -
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity i2c_bus_model is
  generic
  (
    g_nr_masters : positive := 1;
    g_nr_slaves  : positive := 1
  );
  port
  (
    -- Input ports from master lines
    mscl_i : in  std_logic_vector(g_nr_masters-1 downto 0);
    msda_i : in  std_logic_vector(g_nr_masters-1 downto 0);

    -- Input ports from slave lines
    sscl_i : in  std_logic_vector(g_nr_slaves-1 downto 0);
    ssda_i : in  std_logic_vector(g_nr_slaves-1 downto 0);

    -- SCL and SDA line outputs
    scl_o  : out std_logic;
    sda_o  : out std_logic
  );
end entity i2c_bus_model;


architecture behav of i2c_bus_model is

--==============================================================================
--  architecture begin
--==============================================================================
begin

  scl_o <= '1' when (mscl_i = (mscl_i'range => '1')) and
                    (sscl_i = (sscl_i'range => '1')) else
           '0';
  sda_o <= '1' when (msda_i = (msda_i'range => '1')) and
                    (ssda_i = (ssda_i'range => '1')) else
           '0';

end architecture behav;
--==============================================================================
--  architecture end
--==============================================================================
