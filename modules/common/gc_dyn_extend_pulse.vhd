--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_dyn_extend_pulse
--
-- description: Synchronous pulse extender. Generates a pulse of programmable
-- width upon detection of a rising edge in the input.
--
--------------------------------------------------------------------------------
-- Copyright CERN 209-2018
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.NUMERIC_STD.all;

library work;
use work.gencores_pkg.all;

entity gc_dyn_extend_pulse is
  generic
    (
      -- Number of bits of the  len_i input
      g_len_width : natural := 10
      );
  port (
    clk_i      : in  std_logic;
    rst_n_i    : in  std_logic;
    -- input pulse (synchronous to clk_i)
    pulse_i    : in  std_logic;
    -- output pulse length in clk_i cycles
    len_i      : in std_logic_vector(g_len_width-1 downto 0);
    -- extended output pulse
    extended_o : out std_logic := '0');
end gc_dyn_extend_pulse;

architecture rtl of gc_dyn_extend_pulse is

  signal cntr : unsigned(g_len_width-1 downto 0);
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
        cntr       <= unsigned(len_i) - 2;
      elsif cntr /= to_unsigned(0, cntr'length) then
        cntr <= cntr - 1;
      else
        extended_int <= '0';
      end if;
    end if;
  end process extend;

  extended_o <= pulse_i or extended_int;

end rtl;

