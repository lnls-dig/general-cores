--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_sync_word_wr
--
-- description: Synchronizer for writing a word with an ack.
--
--   Used to transfer a word from the input clock domain to the output clock
--   domain.  User provides the data and a pulse write signal to transfer the
--   data.  When the data are transfered, a write pulse is generated on the
--   output side along with the data, and an acknowledge is generated on the
--   input side.  Once the user requests a transfer, no new data should be
--   requested for a transfer until the ack is received. A busy flag is also
--   available for this purpose (user should not push new data if busy).
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

entity gc_sync_word_wr is
  generic (
    -- Automatically write next word when not busy.
    g_AUTO_WR : boolean  := FALSE;
    g_WIDTH   : positive := 8);
  port (
    --  Input clock and reset
    clk_in_i    : in  std_logic;
    rst_in_n_i  : in  std_logic;
    --  Output clock and reset
    clk_out_i   : in  std_logic;
    rst_out_n_i : in  std_logic;
    --  Input data (from clk_in_i domain)
    data_i      : in  std_logic_vector (g_WIDTH - 1 downto 0);
    --  Input control (from clk_in_i domain)
    --  wr_i is ignored if g_AUTO_WR is set
    wr_i        : in  std_logic := '0';
    --  Transfer in progress (clk_in_i domain).
    busy_o      : out std_logic;
    --  Input wr_i has been used (clk_in_i domain).
    ack_o       : out std_logic;
    --  Output data
    data_o      : out std_logic_vector (g_WIDTH - 1 downto 0);
    --  Output status.  Pulse set when the data has been transfered (clk_out_i domain).
    wr_o        : out std_logic);
end entity;

architecture arch of gc_sync_word_wr is

  signal gc_sync_word_data :
    std_logic_vector (g_WIDTH - 1 downto 0) := (others => '0');

  attribute keep : string;

  attribute keep of gc_sync_word_data : signal is "true";

  signal d_ready : std_logic;
  signal wr_in   : std_logic;
  signal wr_out  : std_logic;
  signal dat_out : std_logic_vector(g_WIDTH -1 downto 0) := (others => '0');

begin

  wr_in <= d_ready when g_AUTO_WR else wr_i;

  cmp_pulse_sync : gc_pulse_synchronizer2
    port map (
      clk_in_i    => clk_in_i,
      rst_in_n_i  => rst_in_n_i,
      clk_out_i   => clk_out_i,
      rst_out_n_i => rst_out_n_i,
      d_ready_o   => d_ready,
      d_ack_p_o   => ack_o,
      d_p_i       => wr_in,
      q_p_o       => wr_out);

  busy_o <= not d_ready;

  p_writer : process(clk_in_i)
  begin
    if rising_edge(clk_in_i) then
      if d_ready = '1' and wr_in = '1' then
        --  Write requested, save the input data
        gc_sync_word_data <= data_i;
      end if;
    end if;
  end process p_writer;

  p_reader : process (clk_out_i)
  begin
    if rising_edge(clk_out_i) then
      if wr_out = '1' then
        --  Data is stable.
        dat_out <= gc_sync_word_data;
        wr_o    <= '1';
      else
        wr_o <= '0';
      end if;
    end if;
  end process p_reader;

  data_o <= dat_out;

end arch;
