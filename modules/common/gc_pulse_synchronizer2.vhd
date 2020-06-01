--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_pulse_synchronizer2
--
-- description: Full feedback pulse synchronizer (works independently of the
-- input/output clock domain frequency ratio) with separate resets per domain
--
--------------------------------------------------------------------------------
-- Copyright CERN 2012-2018
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

use work.gencores_pkg.all;

entity gc_pulse_synchronizer2 is

  port (
    -- pulse input clock
    clk_in_i    : in  std_logic;
    rst_in_n_i  : in  std_logic;
    -- pulse output clock
    clk_out_i   : in  std_logic;
    rst_out_n_i : in  std_logic;
    -- pulse input ready (clk_in_i domain). When HI, a pulse
    -- coming to d_p_i will be correctly transferred to q_p_o.
    d_ready_o   : out std_logic;
    -- last pulse input acknowledged. This is an alternative
    -- status flag to d_ready_o for applications that work better
    -- with a pulsed ACK instead of a "ready" flag.
    d_ack_p_o   : out std_logic;
    -- pulse input (clk_in_i domain)
    d_p_i       : in  std_logic;
    -- pulse output (clk_out_i domain)
    q_p_o       : out std_logic);

end gc_pulse_synchronizer2;

architecture rtl of gc_pulse_synchronizer2 is

  signal ready        : std_logic := '1';
  signal d_ack        : std_logic := '1';
  signal d_ack_d0     : std_logic := '0';
  signal d_p_d0       : std_logic := '0';
  signal in_ext       : std_logic := '0';
  signal out_ext      : std_logic := '0';
  signal out_feedback : std_logic := '0';

begin  -- rtl

  cmp_in2out_sync : gc_sync_ffs
    port map (
      clk_i    => clk_out_i,
      rst_n_i  => rst_out_n_i,
      data_i   => in_ext,
      synced_o => out_ext,
      npulse_o => open,
      ppulse_o => q_p_o);

  cmp_out2in_sync : gc_sync_ffs
    port map (
      clk_i    => clk_in_i,
      rst_n_i  => rst_in_n_i,
      data_i   => out_ext,
      synced_o => out_feedback,
      npulse_o => open,
      ppulse_o => open);

  p_input_ack : process(clk_in_i)
  begin
    if rising_edge(clk_in_i) then

      d_p_d0   <= d_p_i;
      d_ack_d0 <= d_ack;

      if ready = '1' and d_p_i = '1' and d_p_d0 = '0'then
        --  Incoming pulse detected and the system is ready.
        --  Transfer it.
        in_ext <= '1';
        --  Clear ack and ready!
        d_ack  <= '0';
        ready  <= '0';
      elsif in_ext = '1' and out_feedback = '1' then
        --  Pulse has been transfered, clear the input.
        in_ext <= '0';
      elsif in_ext = '0' and out_feedback = '0' then
        --  Clear transfered.  Done.
        --  This is also the steady state.
        d_ack <= '1';
        ready <= '1';
      end if;

      if ready = '0' then
        assert d_p_i = '0' or (d_p_i = '1' and d_p_d0 = '1')
          report "request while previous one not completed"
          severity ERROR;
      end if;
    end if;
  end process p_input_ack;

  d_ack_p_o <= d_ack and not d_ack_d0;
  d_ready_o <= ready;

end rtl;
