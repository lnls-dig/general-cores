--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_edge_detect
--
-- description: Simple edge detector.  Combinatorial.
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
use ieee.std_logic_1164.all;

entity gc_edge_detect is
  generic(
    g_ASYNC_RST  : boolean := FALSE;
    -- Positive/negative edge detection for pulse_o output.
    -- Valid values are "positive" and "negative".
    g_PULSE_EDGE : string  := "positive";
    -- Clock edge sensitivity of edge detection flip-flop.
    -- Valid values are "positive" and "negative".
    g_CLOCK_EDGE : string  := "positive");
  port(
    clk_i   : in  std_logic;   -- clock
    rst_n_i : in  std_logic;   -- reset
    data_i  : in  std_logic;   -- input
    pulse_o : out std_logic);  -- positive edge detect output
end entity gc_edge_detect;

architecture arch of gc_edge_detect is

  signal dff : std_logic;

begin

  assert g_PULSE_EDGE = "positive" or g_PULSE_EDGE = "negative" severity FAILURE;
  assert g_CLOCK_EDGE = "positive" or g_CLOCK_EDGE = "negative" severity FAILURE;

  gen_pos_pulse : if g_PULSE_EDGE = "positive" generate
    pulse_o <= data_i and not dff;
  end generate gen_pos_pulse;

  gen_neg_pulse : if g_PULSE_EDGE = "negative" generate
    pulse_o <= not data_i and dff;
  end generate gen_neg_pulse;

  gen_async_rst : if g_ASYNC_RST = TRUE generate

    sync_posedge : if g_CLOCK_EDGE = "positive" generate
      process (clk_i, rst_n_i)
      begin
        if rst_n_i = '0' then
          dff <= '0';
        elsif rising_edge (clk_i) then
          dff <= data_i;
        end if;
      end process;
    end generate sync_posedge;

    sync_negedge : if g_CLOCK_EDGE = "negative" generate
      process (clk_i, rst_n_i)
      begin
        if rst_n_i = '0' then
          dff <= '0';
        elsif falling_edge (clk_i) then
          dff <= data_i;
        end if;
      end process;
    end generate sync_negedge;

  end generate gen_async_rst;

  gen_sync_rst : if g_ASYNC_RST = FALSE generate

    sync_posedge : if g_CLOCK_EDGE = "positive" generate
      process (clk_i)
      begin
        if rising_edge (clk_i) then
          if rst_n_i = '0' then
            dff <= '0';
          else
            dff <= data_i;
          end if;
        end if;
      end process;
    end generate sync_posedge;

    sync_negedge : if g_CLOCK_EDGE = "negative" generate
      process (clk_i)
      begin
        if falling_edge (clk_i) then
          if rst_n_i = '0' then
            dff <= '0';
          else
            dff <= data_i;
          end if;
        end if;
      end process;
    end generate sync_negedge;

  end generate gen_sync_rst;

end architecture arch;
