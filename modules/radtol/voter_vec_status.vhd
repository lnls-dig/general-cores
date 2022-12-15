--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   voter_vec_status
--
-- description: 3 input majority voter with error status output for a vector
-- NOTE: in case of error, the result may be different from all the inputs
--  (if two errors appear)
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

entity voter_vec_status is
  generic (
      g_WIDTH : natural
  );
  port (
    a, b, c : in std_logic_vector(g_WIDTH - 1 downto 0);
    res : out std_logic_vector(g_WIDTH - 1 downto 0);
    err : out std_logic);
end voter_vec_status;

architecture behav of voter_vec_status is
  signal b_err : std_logic_vector(g_WIDTH - 1 downto 0);
begin
  gen_bit: for i in res'range generate
    inst_voter: entity work.voter_status
      port map (
        inp (1) => a(i),
        inp (2) => b(i),
        inp (3) => c(i),
        res => res(i),
        err => b_err(i)
      );
  end generate;
  err <= '1' when b_err /= (b_err'range => '0') else '0';
end behav;