--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_sync_word_rd
--
-- description: Synchronizer for reading a word with an ack.
--
--   Used to transfer a word from the output clock domain to the input clock
--   domain.  The user provided data is constantly read.  When a read request
--   arrives (on the output side), the user data is frozen (not read anymore),
--   and sent to the output side.  A pulse is generated on the output side
--   when the transfer is done, and the data is unfrozen.  A pulse is also
--   generated on the input side.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2019
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

entity gc_sync_word_rd is
  generic (
    g_WIDTH   : positive := 8);
  port (
    --  Output clock and reset (wishbone side)
    clk_out_i   : in  std_logic;
    rst_out_n_i : in  std_logic;
    --  Input clock and reset (user side)
    clk_in_i    : in  std_logic;
    rst_in_n_i  : in  std_logic;
    --  Input data (user side)
    data_in_i   : in  std_logic_vector (g_WIDTH - 1 downto 0);
    --  Trigger a read (wishbone side)
    rd_out_i    : in  std_logic := '0';
    --  Pulse when the read is available (wishbone side)
    ack_out_o   : out std_logic;
    --  Output data (wishbone side)
    data_out_o  : out std_logic_vector (g_WIDTH - 1 downto 0);
    --  Pulse when a data is transfered (user side)
    rd_in_o     : out std_logic);
end entity;

architecture arch of gc_sync_word_rd is
  signal gc_sync_word_data :
    std_logic_vector (g_WIDTH - 1 downto 0) := (others => '0');

  attribute keep : string;

  attribute keep of gc_sync_word_data : signal is "true";

  signal d_ready : std_logic;
  signal wr_in   : std_logic;
  signal rd_out  : std_logic;

begin
  cmp_pulse_sync : entity work.gc_pulse_synchronizer2
    port map (
      clk_in_i    => clk_out_i,
      rst_in_n_i  => rst_out_n_i,
      clk_out_i   => clk_in_i,
      rst_out_n_i => rst_in_n_i,
      d_ready_o   => d_ready,
      d_ack_p_o   => wr_in,
      d_p_i       => rd_out_i,
      q_p_o       => rd_out);

  p_reader : process(clk_in_i)
  begin
    if rising_edge(clk_in_i) then
      if rd_out = '1' then
        gc_sync_word_data <= data_in_i;
      end if;
    end if;
  end process;

  p_writer : process(clk_out_i)
  begin
    if rising_edge(clk_out_i) then
      if wr_in = '1' then
        --  Data is stable.
        data_out_o <= gc_sync_word_data;
        ack_out_o  <= '1';
      else
        ack_out_o <= '0';
      end if;

      if rst_out_n_i = '0' then
        ack_out_o <= '0';
      end if;
    end if;
  end process;
end arch;
