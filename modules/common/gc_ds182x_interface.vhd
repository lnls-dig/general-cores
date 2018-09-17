--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_ds182x_interface
--
-- description: one wire temperature & unique id interface for
-- DS1822 and DS1820.
--
-- Deprecated! Kept for backward compatibility.
-- Please use gc_ds182x_readout instead.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2013-2018
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;

use work.gencores_pkg.all;

entity gc_ds182x_interface is
  generic (
    freq               : integer := 40;      -- clk_i frequency in MHz
    g_USE_INTERNAL_PPS : boolean := false);
  port (
    clk_i     : in    std_logic;
    rst_n_i   : in    std_logic;
    pps_p_i   : in    std_logic;                     -- pulse per second (for temperature read)
    onewire_b : inout std_logic;                     -- IO to be connected to the chip(DS1820/DS1822)
    id_o      : out   std_logic_vector(63 downto 0); -- id_o value
    temper_o  : out   std_logic_vector(15 downto 0); -- temperature value (refreshed every second)
    id_read_o : out   std_logic;                     -- id_o value is valid_o
    id_ok_o   : out   std_logic);                    -- Same as id_read_o, but not reset with rst_n_i
end gc_ds182x_interface;

architecture arch of gc_ds182x_interface is

  constant c_CLOCK_FREQ_KHZ = freq * 1000;

begin

  gc_ds182x_readout_wrapper: gc_ds182x_readout
    generic map (
      g_CLOCK_FREQ_KHZ   => c_CLOCK_FREQ_KHZ,
      g_USE_INTERNAL_PPS => g_USE_INTERNAL_PPS)
    port map (
      clk_i     => clk_i,
      rst_n_i   => rst_n_i,
      pps_p_i   => pps_p_i,
      onewire_b => onewire_b,
      id_o      => id_o,
      temper_o  => temper_o,
      id_read_o => id_read_o,
      id_ok_o   => id_ok_o);

end arch;
