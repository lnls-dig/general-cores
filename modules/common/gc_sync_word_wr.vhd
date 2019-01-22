--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_sync_word_wr
--
-- description: Synchronizer for writing a word with an ack.
--   Used to transfer a word from the input clock domain to the output clock
--   domain.  User provides the data and a pulse write signal to transfer the
--   data.  When the data are transfered, a write pulse is generated on the
--   output side along with the data, and an acknowledge is geenrated on the
--   input side.  Once the user request a transfer, no new data should be
--   requested for a transfer until the ack was received.
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

entity gc_sync_word_wr is
  generic (
    width : positive := 8);
  port (
    --  Input clock and reset
    clk_in_i    : in  std_logic;
    rst_in_n_i  : in  std_logic;
    --  Output clock.
    clk_out_i   : in  std_logic;
    rst_out_n_i : in std_logic;
    --  Input data
    data_i      : in  std_logic_vector (width - 1 downto 0);
    --  Input wr
    wr_i        : in  std_logic;
    ack_o       : out std_logic;
    --  Output data
    data_o      : out std_logic_vector (width - 1 downto 0);
    wr_o        : out std_logic);
end entity;

architecture behav of gc_sync_word_wr is
  signal data : std_logic_vector (width - 1 downto 0);
  signal in_busy : std_logic;
  signal in_progress : std_logic;

  signal ack_start, ack_done : std_logic;

  --  Synchronized extended wr_i signal.
  signal wr_out   : std_logic;
  --  Internal pulse for wr_o, active one cycle before wr_o.
  signal wr_out_p : std_logic;
begin
  --  Handle incoming request.
  process(clk_in_i)
  begin
    if rising_edge(clk_in_i) then
      if rst_in_n_i = '0' then
        in_progress <= '0';
        in_busy <= '0';
        data <= (others => '0');
        ack_o <= '0';
      else
        ack_o <= '0';
        if in_busy = '0' then
          if wr_i = '1' then
            in_progress <= '1';
            in_busy <= '1';
            data <= data_i;
          end if;
        else
          assert wr_i = '0' report "request while previous one not completed"
            severity error;
          if ack_start = '1' then
            in_progress <= '0';
          end if;
          if ack_done = '1' then
            assert in_progress = '0';
            in_busy <= '0';
            ack_o <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  cmp_wr_sync : entity work.gc_sync_ffs
    port map (
      clk_i => clk_out_i,
      rst_n_i => rst_out_n_i,
      data_i => in_progress,
      synced_o => wr_out,
      ppulse_o => wr_out_p);

  --  Outputs.
  process (clk_out_i)
  begin
    if rising_edge(clk_out_i) then
      if rst_out_n_i = '0' then
        data_o <= (others => '0');
        wr_o <= '0';
      else
        if wr_out_p = '1' then
          --  Data are stable.
          data_o <= data;
          wr_o <= '1';
        else
          wr_o <= '0';
        end if;
      end if;
    end if;
  end process;

  --  Ack.
  cmp_ack_sync : entity work.gc_sync_ffs
    port map (
      clk_i => clk_in_i,
      rst_n_i => rst_in_n_i,
      data_i => wr_out,
      ppulse_o => ack_start,
      npulse_o => ack_done);
end behav;
