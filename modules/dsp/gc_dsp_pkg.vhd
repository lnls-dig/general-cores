--------------------------------------------------------------------------------
-- CERN SY-RF-FB
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_dsp_pkg
--
-- author:      Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
--
-- description: Shared definitions & types for the DSP core collection.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2020
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
use ieee.std_logic_1164.All;
use ieee.numeric_std.All;

package gc_dsp_pkg is

  constant c_MAX_COEF_BITS : integer := 32;
  constant c_FIR_MAX_COEFS : integer := 128;
  
  type t_FIR_COEF_ARRAY is array(c_FIR_MAX_COEFS-1 downto 0) of signed(c_MAX_COEF_BITS-1 downto 0);

end package;
