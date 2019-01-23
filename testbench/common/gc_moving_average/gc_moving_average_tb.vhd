--------------------------------------------------------------------------------
-- CERN (BE-CO-HT)
-- Moving average testbench
--------------------------------------------------------------------------------
--
-- unit name: gc_moving_average_tb
--
-- author: Dimitris Lampridis (dimitris.lampridis@cern.ch)
--
-- date: 10-10-2017
--
-- description: very simple testbench which waits for the the delay line to be
-- filled with zeroes and then it sets data input to 0x10 for 16 cycles, which
-- causes the output to increment by 0x10 every cycle, until it reaches 0x100.
-- After a 1us pause, the input will be set to zero, which causes the output
-- to decrement by 0x10 every cycle, until it reaches zero again.
--
--------------------------------------------------------------------------------
-- GNU LESSER GENERAL PUBLIC LICENSE
--------------------------------------------------------------------------------
-- This source file is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation; either version 2.1 of the License, or (at your
-- option) any later version. This source is distributed in the hope that it
-- will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
-- of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU Lesser General Public License for more details. You should have
-- received a copy of the GNU Lesser General Public License along with this
-- source; if not, download it from http://www.gnu.org/licenses/lgpl-2.1.html
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
--use IEEE.NUMERIC_STD.all;

library work;
use work.gencores_pkg.all;

-- A testbench has no ports
entity gc_moving_average_tb is
  generic (
    -- input/output data width
    g_data_width : natural := 8;
    -- averaging window, expressed as 2 ** g_avg_log2
    g_avg_log2 : natural range 1 to 8 := 4
    );
end gc_moving_average_tb;


architecture tb of gc_moving_average_tb is

  ------------------------------------------------------------------------------
  -- Signals declaration
  ------------------------------------------------------------------------------
  signal tb_rst_n_i    : std_logic := '1';
  signal tb_clk_i      : std_logic := '0';
  signal tb_din_i      : std_logic_vector(g_data_width-1 downto 0);
  signal tb_dout_o     : std_logic_vector(g_data_width+g_avg_log2-1 downto 0);
  signal tb_dout_stb_o : std_logic;
  signal tb_end_sim    : std_logic := '0';

begin

  -- Instantiate the Unit Under Test (UUT)
  uut : gc_moving_average
    generic map (
      g_data_width => g_data_width,
      g_avg_log2   => g_avg_log2)
    port map (
      rst_n_i    => tb_rst_n_i,
      clk_i      => tb_clk_i,
      din_i      => tb_din_i,
      dout_o     => tb_dout_o,
      dout_stb_o => tb_dout_stb_o);

  -- Clock process definitions
  clk_i_process : process
  begin
    while tb_end_sim /= '1' loop
      tb_clk_i <= '0';
      wait for 5 NS;
      tb_clk_i <= '1';
      wait for 5 NS;
    end loop;
    wait;
  end process;


  -- Stimulus process
  stim_proc : process
  begin
    -- initial values
    tb_din_i <= X"00";

    -- hold reset state for 1 us.
    tb_rst_n_i <= '0';
    wait for 1 US;
    tb_rst_n_i <= '1';

    wait until rising_edge(tb_clk_i);

    wait until tb_dout_stb_o = '1';

    wait for 1 US;
    wait until falling_edge(tb_clk_i);
    tb_din_i <= X"10";
    wait for 1 US;
    wait until falling_edge(tb_clk_i);
    tb_din_i <= X"00";
    wait for 1 US;

    tb_end_sim <= '1';

    wait;

  end process;


end tb;
