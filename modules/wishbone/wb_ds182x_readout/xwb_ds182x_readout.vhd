--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_ds182x_readout
--
-- description: one wire temperature & unique id interface for
-- DS1822 and DS1820.
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
use work.wishbone_pkg.all;

entity xwb_ds182x_readout is
  generic (
    g_CLOCK_FREQ_KHZ   : integer := 40000;           -- clk_i frequency in KHz
    g_USE_INTERNAL_PPS : boolean := false);
  port (
    clk_i     : in    std_logic;
    rst_n_i   : in    std_logic;

    wb_i                 : in    t_wishbone_slave_in;
    wb_o                 : out   t_wishbone_slave_out;

    pps_p_i   : in    std_logic;                     -- pulse per second (for temperature read)
    onewire_b : inout std_logic);                    -- Same as id_read_o, but not reset with rst_n_i
end xwb_ds182x_readout;

architecture arch of xwb_ds182x_readout is
  signal id      :  std_logic_vector(63 downto 0); -- id_o value
  signal temper  :  std_logic_vector(15 downto 0); -- temperature value (refreshed every second)
  signal id_read :  std_logic;                     -- id_o value is valid_o
  signal id_ok   :  std_logic;                    -- Same as id_read_o, but not reset with rst_n_i
  signal temp_ok :  std_logic;
  signal temp_err : std_logic;
begin
  i_readout: entity work.gc_ds182x_readout
    generic map (
      g_CLOCK_FREQ_KHZ => g_CLOCK_FREQ_KHZ,
      g_USE_INTERNAL_PPS => g_USE_INTERNAL_PPS)
    port map (
      clk_i => clk_i,
      rst_n_i => rst_n_i,
      pps_p_i => pps_p_i,
      onewire_b => onewire_b,
      id_o => id,
      temper_o => temper,
      temp_ok_o => temp_ok,
      id_read_o => id_read,
      id_ok_o => id_ok);

  temp_err <= not temp_ok;

  i_regs: entity work.wb_ds182x_regs
    port map (
      rst_n_i => rst_n_i,
      clk_i => clk_i,
      wb_i => wb_i,
      wb_o => wb_o,

      id_i => id,
      temperature_data_i => temper,
      temperature_error_i => temp_err,
      status_id_read_i => id_read,
      status_id_ok_i => id_ok,
      status_temp_ok_i => temp_ok
    );
end arch;
