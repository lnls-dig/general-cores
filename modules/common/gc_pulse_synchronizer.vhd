--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   gc_pulse_synchronizer
--
-- description: Full feedback pulse synchronizer (works independently of the
-- input/output clock domain frequency ratio)
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

entity gc_pulse_synchronizer is
  
  port (
    -- pulse input clock
    clk_in_i  : in  std_logic;
    -- pulse output clock
    clk_out_i : in  std_logic;
    -- system reset (clk_in_i domain)
    rst_n_i   : in  std_logic;
    -- pulse input ready (clk_in_i domain). When HI, a pulse coming to d_p_i will be
    -- correctly transferred to q_p_o.
    d_ready_o : out std_logic;
    -- pulse input (clk_in_i domain)
    d_p_i     : in  std_logic;
    -- pulse output (clk_out_i domain)
    q_p_o     : out std_logic);

end gc_pulse_synchronizer;

architecture rtl of gc_pulse_synchronizer is

  constant c_sync_stages : integer := 3;

  signal ready, d_p_d0 : std_logic;

  signal in_ext, out_ext : std_logic;
  signal out_feedback    : std_logic;

  signal d_in2out : std_logic_vector(c_sync_stages-1 downto 0);
  signal d_out2in : std_logic_vector(c_sync_stages-1 downto 0);

begin  -- rtl

  process(clk_out_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      d_in2out <= (others => '0');
      out_ext <= '0';
    elsif rising_edge(clk_out_i) then
      d_in2out <= d_in2out(c_sync_stages-2 downto 0) & in_ext;
      out_ext <= d_in2out(c_sync_stages-1);
    end if;
  end process;


  process(clk_in_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      d_out2in <= (others => '0');
    elsif rising_edge(clk_in_i) then
      d_out2in <= d_out2in(c_sync_stages-2 downto 0) & out_ext;
    end if;
  end process;

  out_feedback <= d_out2in(c_sync_stages-1);

  p_input_ack : process(clk_in_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      ready  <= '1';
      in_ext <= '0';
      d_p_d0 <= '0';
    elsif rising_edge(clk_in_i) then

      d_p_d0 <= d_p_i;
      
      if(ready = '1' and d_p_i = '1' and d_p_d0 = '0') then
        in_ext <= '1';
        ready  <= '0';
      elsif(in_ext = '1' and out_feedback = '1') then
        in_ext <= '0';
      elsif(in_ext = '0' and out_feedback = '0') then
        ready <= '1';
      end if;
    end if;
  end process;

  p_drive_output : process(clk_out_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      q_p_o <= '0';
    elsif rising_edge(clk_out_i) then
      q_p_o <= not out_ext and d_in2out(c_sync_stages-1);
    end if;
  end process;

  d_ready_o <= ready;

end rtl;
