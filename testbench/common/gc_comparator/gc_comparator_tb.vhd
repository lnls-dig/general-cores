--------------------------------------------------------------------------------
-- CERN (BE-CO-HT)
-- General-Purpose Comparator Testbench
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:     gc_comparator_tb
--
-- description:
--
--   Simple testbench for the gc_comparator unit.
--
--------------------------------------------------------------------------------
-- Copyright (c) 2017 CERN / BE-CO-HT
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- A testbench has no ports
entity gc_comparator_tb is
  generic (
    g_IN_WIDTH : natural := 16);
end entity gc_comparator_tb;

architecture tb of gc_comparator_tb is

  signal tb_end_sim : std_logic := '0';

  signal tb_rst_n_i : std_logic := '1';
  signal tb_clk_i   : std_logic := '0';

  signal tb_pol_inv_i : std_logic;
  signal tb_inp_i     : std_logic_vector(g_IN_WIDTH-1 downto 0) := (others => '0');
  signal tb_inn_i     : std_logic_vector(g_IN_WIDTH-1 downto 0) := (others => '0');
  signal tb_hys_i     : std_logic_vector(g_IN_WIDTH-1 downto 0) := (others => '0');
  signal tb_enable_i  : std_logic;
  signal tb_out_o     : std_logic;
  signal tb_out_p_o   : std_logic;

begin  -- architecture tb

  -- Instantiate the Unit Under Test (UUT)
  uut : entity work.gc_comparator
    generic map (
      g_IN_WIDTH => g_IN_WIDTH)
    port map (
      clk_i     => tb_clk_i,
      rst_n_i   => tb_rst_n_i,
      pol_inv_i => tb_pol_inv_i,
      enable_i  => tb_enable_i,
      inp_i     => tb_inp_i,
      inn_i     => tb_inn_i,
      hys_i     => tb_hys_i,
      out_o     => tb_out_o,
      out_p_o   => tb_out_p_o);

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

    procedure wait_clock_rising (
      constant cycles : in integer) is
    begin
      for i in 1 to cycles loop
        wait until rising_edge(tb_clk_i);
      end loop;
    end procedure wait_clock_rising;

    procedure assign_inp (
      constant value       : in integer;
      constant wait_cycles : in integer) is
    begin
      wait_clock_rising(wait_cycles);
      wait until falling_edge(tb_clk_i);
      tb_inp_i <= std_logic_vector(to_signed(value, g_IN_WIDTH));
    end procedure assign_inp;

    procedure check_output (
      constant out_state   : in std_logic;
      constant out_p_state : in std_logic;
      constant wait_cycles : in integer) is
    begin
      wait_clock_rising(wait_cycles);
      assert tb_out_o = out_state and tb_out_p_o = out_p_state
        report "CHECK FAIL" severity FAILURE;
    end procedure check_output;

  begin
    -- initial values
    tb_end_sim   <= '0';
    tb_pol_inv_i <= '0';
    tb_enable_i  <= '1';
    tb_inp_i     <= std_logic_vector(to_signed(256, g_IN_WIDTH));
    tb_inn_i     <= std_logic_vector(to_signed(128, g_IN_WIDTH));
    tb_hys_i     <= std_logic_vector(to_signed(16, g_IN_WIDTH));

    -- hold reset state for 1 us.
    tb_rst_n_i <= '0';
    wait_clock_rising(10);
    tb_rst_n_i <= '1';

    -- Input is above threshold but all outputs
    -- should remain low after reset.
    check_output('0', '0', 0);

    -- Set input to a value below threshold but above
    -- hysteresis. All outputs should remain low.
    assign_inp (118, 10);
    check_output('0', '0', 2);

    -- Set input to a value below threshold and hysteresis.
    -- All outputs should remain low.
    assign_inp (100, 10);
    check_output('0', '0', 2);

    -- Set input to a value above threshold.
    -- out_p should pulse and normal out should stay high.
    assign_inp (512, 10);
    check_output('1', '1', 2);
    check_output('1', '0', 1);

    -- Set input to a value below threshold but above
    -- hysteresis. Normal out should remain high.
    assign_inp (116, 10);
    check_output('1', '0', 2);

    -- Set input to a value below threshold and hysteresis.
    -- All outputs should remain low.
    assign_inp (32, 10);
    check_output('0', '0', 2);

    -- Set input to a value above threshold but only for one
    -- cycle.both outputs should pulse for one cycle.
    assign_inp (512, 10);
    assign_inp (0, 1);
    check_output('1', '1', 1);
    check_output('0', '0', 1);

    -- Set input to a value above threshold.
    -- out_p should pulse and normal out should stay high.
    assign_inp (512, 10);
    check_output('1', '1', 2);
    check_output('1', '0', 1);

    -- Disable comparator. Both outputs should remain low.
    wait_clock_rising(10);
    tb_enable_i <= '0';
    check_output('0', '0', 2);

    -- Switch polarity and enable comparator again
    wait_clock_rising(10);
    tb_pol_inv_i <= '1';
    wait_clock_rising(10);
    tb_enable_i  <= '1';
    check_output('0', '0', 0);

    -- Set input to a value above threshold.
    -- out_p should pulse and normal out should stay high.
    assign_inp (0, 10);
    check_output('1', '1', 2);
    check_output('1', '0', 1);

    -- Set input to a value below threshold but above
    -- hysteresis. Normal out should remain high.
    assign_inp (132, 10);
    check_output('1', '0', 2);

    -- Set input to a value below threshold and hysteresis.
    -- All outputs should remain low.
    assign_inp (256, 10);
    check_output('0', '0', 2);

    -- Set input to a value above threshold but only for one
    -- cycle.both outputs should pulse for one cycle.
    assign_inp (0, 10);
    assign_inp (512, 1);
    check_output('1', '1', 1);
    check_output('0', '0', 1);

    report "PASS" severity NOTE;

    wait_clock_rising(10);

    tb_end_sim <= '1';

    wait;

  end process;


end tb;
