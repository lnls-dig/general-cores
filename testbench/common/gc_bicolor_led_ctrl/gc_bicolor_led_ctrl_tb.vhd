--------------------------------------------------------------------------------
-- CERN (BE-CO-HT)
-- Bi-color LED controller testbench
-- http://www.ohwr.org/projects/svec
--------------------------------------------------------------------------------
--
-- unit name: gc_bicolor_led_ctrl_tb
--
-- author: Matthieu Cattin (matthieu.cattin@cern.ch)
--
-- date: 12-07-2012
--
-- version: 1.0
--
-- description: Bi-color LED controller testbench.
--
-- dependencies:
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
-- last changes: see log.
--------------------------------------------------------------------------------
-- TODO: - 
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library work;
use work.gencores_pkg.all;


entity gc_bicolor_led_ctrl_tb is
end gc_bicolor_led_ctrl_tb;


architecture tb of gc_bicolor_led_ctrl_tb is

  ------------------------------------------------------------------------------
  -- Types declaration
  ------------------------------------------------------------------------------
  type t_led_color is (OFF, RED, GREEN, UNDEF);
  type t_led_color_array is array (0 to 7) of t_led_color;

  ------------------------------------------------------------------------------
  -- Constants declaration
  ------------------------------------------------------------------------------
  constant c_NB_LINE      : natural := 3;
  constant c_NB_COLUMN    : natural := 4;
  constant c_CLK_FREQ     : natural := 125000000;  -- in Hz
  constant c_REFRESH_RATE : natural := 250;        -- in Hz

  ------------------------------------------------------------------------------
  -- Signals declaration
  ------------------------------------------------------------------------------
  signal rst_n_i         : std_logic                                                    := '1';
  signal clk_i           : std_logic                                                    := '0';
  signal led_intensity_i : std_logic_vector(6 downto 0)                                 := (others => '0');
  signal led_state_i     : std_logic_vector((c_NB_LINE * c_NB_COLUMN * 2) - 1 downto 0) := (others => '0');
  signal column_o        : std_logic_vector(c_NB_COLUMN - 1 downto 0);
  signal line_o          : std_logic_vector(c_NB_LINE - 1 downto 0);
  signal line_oen_o      : std_logic_vector(c_NB_LINE - 1 downto 0);
  signal led_color       : t_led_color_array;


begin

  -- Instantiate the Unit Under Test (UUT)
  uut : gc_bicolor_led_ctrl
    generic map (
      g_NB_COLUMN    => c_NB_COLUMN,
      g_NB_LINE      => c_NB_LINE,
      g_CLK_FREQ     => c_CLK_FREQ,
      g_REFRESH_RATE => c_REFRESH_RATE
      )
    port map(
      rst_n_i         => rst_n_i,
      clk_i           => clk_i,
      led_intensity_i => led_intensity_i,
      led_state_i     => led_state_i,
      column_o        => column_o,
      line_o          => line_o,
      line_oen_o      => line_oen_o
      );

  -- Clock process definitions
  clk_i_process : process
  begin
    clk_i <= '0';
    wait for 4 ns;
    clk_i <= '1';
    wait for 4 ns;
  end process;

  -- check color
  p_led_color_check: process
  begin
    wait until (line_oen_o'event or line_o'event or column_o'event);
    if (line_oen_o(0) = '0' or (line_oen_o(0) = '1' and line_o(0) = column_o(0))) then
      led_color(0) <= OFF;
    elsif (line_oen_o(0) = '1' and line_o(0) = '1' and column_o(0) = '0') then
      led_color(0) <= RED;
    elsif (line_oen_o(0) = '1' and line_o(0) = '0' and column_o(0) = '1') then
      led_color(0) <= GREEN;
    else
      led_color(0) <= UNDEF;
    end if;

    if (line_oen_o(0) = '0' or (line_oen_o(0) = '1' and line_o(0) = column_o(1))) then
      led_color(1) <= OFF;
    elsif (line_oen_o(0) = '1' and line_o(0) = '1' and column_o(1) = '0') then
      led_color(1) <= RED;
    elsif (line_oen_o(0) = '1' and line_o(0) = '0' and column_o(1) = '1') then
      led_color(1) <= GREEN;
    else
      led_color(1) <= UNDEF;
    end if;

    if (line_oen_o(0) = '0' or (line_oen_o(0) = '1' and line_o(0) = column_o(2))) then
      led_color(2) <= OFF;
    elsif (line_oen_o(0) = '1' and line_o(0) = '1' and column_o(2) = '0') then
      led_color(2) <= RED;
    elsif (line_oen_o(0) = '1' and line_o(0) = '0' and column_o(2) = '1') then
      led_color(2) <= GREEN;
    else
      led_color(2) <= UNDEF;
    end if;

    if (line_oen_o(0) = '0' or (line_oen_o(0) = '1' and line_o(0) = column_o(3))) then
      led_color(3) <= OFF;
    elsif (line_oen_o(0) = '1' and line_o(0) = '1' and column_o(3) = '0') then
      led_color(3) <= RED;
    elsif (line_oen_o(0) = '1' and line_o(0) = '0' and column_o(3) = '1') then
      led_color(3) <= GREEN;
    else
      led_color(3) <= UNDEF;
    end if;

    if (line_oen_o(1) = '0' or (line_oen_o(1) = '1' and line_o(1) = column_o(0))) then
      led_color(4) <= OFF;
    elsif (line_oen_o(1) = '1' and line_o(1) = '1' and column_o(0) = '0') then
      led_color(4) <= RED;
    elsif (line_oen_o(1) = '1' and line_o(1) = '0' and column_o(0) = '1') then
      led_color(4) <= GREEN;
    else
      led_color(4) <= UNDEF;
    end if;

    if (line_oen_o(1) = '0' or (line_oen_o(1) = '1' and line_o(1) = column_o(1))) then
      led_color(5) <= OFF;
    elsif (line_oen_o(1) = '1' and line_o(1) = '1' and column_o(1) = '0') then
      led_color(5) <= RED;
    elsif (line_oen_o(1) = '1' and line_o(1) = '0' and column_o(1) = '1') then
      led_color(5) <= GREEN;
    else
      led_color(5) <= UNDEF;
    end if;

    if (line_oen_o(1) = '0' or (line_oen_o(1) = '1' and line_o(1) = column_o(2))) then
      led_color(6) <= OFF;
    elsif (line_oen_o(1) = '1' and line_o(1) = '1' and column_o(2) = '0') then
      led_color(6) <= RED;
    elsif (line_oen_o(1) = '1' and line_o(1) = '0' and column_o(2) = '1') then
      led_color(6) <= GREEN;
    else
      led_color(6) <= UNDEF;
    end if;

    if (line_oen_o(1) = '0' or (line_oen_o(1) = '1' and line_o(1) = column_o(3))) then
      led_color(7) <= OFF;
    elsif (line_oen_o(1) = '1' and line_o(1) = '1' and column_o(3) = '0') then
      led_color(7) <= RED;
    elsif (line_oen_o(1) = '1' and line_o(1) = '0' and column_o(3) = '1') then
      led_color(7) <= GREEN;
    else
      led_color(7) <= UNDEF;
    end if;
  end process p_led_color_check;


  -- Stimulus process
  stim_proc : process
  begin
    -- hold reset state for 1 us.
    rst_n_i <= '0';
    wait for 1 us;
    rst_n_i <= '1';
    wait for 100 ns;
    wait until rising_edge(clk_i);

    led_intensity_i         <= std_logic_vector(to_unsigned(100, led_intensity_i'length));
    led_state_i(1 downto 0) <= c_LED_RED;
    led_state_i(3 downto 2) <= c_LED_OFF;
    led_state_i(5 downto 4) <= c_LED_RED_GREEN;
    led_state_i(7 downto 6) <= c_LED_OFF;
    led_state_i(9 downto 8) <= c_LED_GREEN;
    led_state_i(11 downto 10) <= c_LED_OFF;
    led_state_i(13 downto 12) <= c_LED_OFF;
    led_state_i(15 downto 14) <= c_LED_RED_GREEN;

    wait for 20 ms;
    wait until rising_edge(clk_i);

    led_intensity_i <= std_logic_vector(to_unsigned(50, led_intensity_i'length));

    wait for 20 ms;
    wait until rising_edge(clk_i);

    led_intensity_i <= std_logic_vector(to_unsigned(10, led_intensity_i'length));

    wait for 20 ms;
    wait until rising_edge(clk_i);

    led_intensity_i <= std_logic_vector(to_unsigned(0, led_intensity_i'length));

    wait for 20 ms;
    wait until rising_edge(clk_i);

    led_intensity_i <= std_logic_vector(to_unsigned(120, led_intensity_i'length));

    wait;
  end process;


end tb;
