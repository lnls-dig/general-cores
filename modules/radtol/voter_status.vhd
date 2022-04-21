--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   voter_status
--
-- description: 3 input majority voter with error status output
--
--------------------------------------------------------------------------------
-- Copyright CERN 2022
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

entity voter_status is
  port (
    inp : in  std_logic_vector(1 to 3);
    res : out std_logic;
    err : out std_logic);
end voter_status;

architecture behav of voter_status is
begin
  res <= (inp(1) and inp(2)) or (inp(1) and inp(3)) or (inp(2) and inp(3));
  err <= (not (inp(1) and inp(2) and inp(3))) and (not (not inp(1) and not inp(2) and not inp(3)));
end behav;