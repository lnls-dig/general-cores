--------------------------------------------------------------------------------
-- CERN (BE-CO-HT)
-- Bi-color LED controller
-- http://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name: bicolor_led_ctrl
--
-- author: Matthieu Cattin (matthieu.cattin@cern.ch)
--
-- date: 11-07-2012
--
-- version: 1.0
--
-- description: Bi-color LED controller. It controls a matrix of bi-color LED.
--              The FPGA ouputs for the columns (C) are connected to buffers
--              and serial resistances and then to the LEDs. The FPGA outputs
--              for lines (L) are connected to tri-state buffers and the to
--              the LEDs. The FPGA outputs for lines output enable (L_OEN) are
--              connected to the output enable of the tri-state buffers.
--
--   Example with three lines and two columns:
--
--              |<refresh period>|
--
--   L1/L2/L3   __|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__|--|__
--
--   L1_OEN     -----|___________|-----|___________|-----|___________|-----|___________|--
--
--   L2_OEN     _____|-----|___________|-----|___________|-----|___________|-----|________
--
--   L3_OEN     ___________|-----|___________|-----|___________|-----|___________|-----|__
--
--   Cn         __|--|__|--|__|--|_________________|-----------------|--|__|--|__|--|__|--
--
--   LED Ln/Cn         OFF       |     color_1     |     color_2     |   both_colors   |
--
--
--   For an example schematics, see https://edms.cern.ch/file/1249643/1/EDA-02530-V2-0_sch.pdf
--
-- dependencies:
--
--------------------------------------------------------------------------------
--  Modifications:
--      2016-08-24: by Jan Pospisil (j.pospisil@cern.ch)
--          * added default values for determined start-up state
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


entity gc_bicolor_led_ctrl is
  generic(
    g_nb_column    : natural := 4;
    g_nb_line      : natural := 2;
    g_clk_freq     : natural := 125000000;  -- in hz
    g_refresh_rate : natural := 250         -- in Hz
    );
  port
    (
      rst_n_i : in std_logic;
      clk_i   : in std_logic;

      led_intensity_i : in std_logic_vector(6 downto 0);

      led_state_i : in std_logic_vector((g_nb_line * g_nb_column * 2) - 1 downto 0);

      column_o   : out std_logic_vector(g_nb_column - 1 downto 0);
      line_o     : out std_logic_vector(g_nb_line - 1 downto 0);
      line_oen_o : out std_logic_vector(g_nb_line - 1 downto 0)
      );
end gc_bicolor_led_ctrl;



architecture rtl of gc_bicolor_led_ctrl is

  ------------------------------------------------------------------------------
  -- Components declaration
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Constants declaration
  ------------------------------------------------------------------------------
  constant c_refresh_cnt_init     : natural := natural(g_clk_freq/(2 * g_nb_line * g_refresh_rate)) - 1;
  constant c_refresh_cnt_nb_bits  : natural := log2_ceil(c_refresh_cnt_init);
  constant c_line_oen_cnt_nb_bits : natural := log2_ceil(g_nb_line);


  ------------------------------------------------------------------------------
  -- Signals declaration
  ------------------------------------------------------------------------------
  signal refresh_rate_cnt   : unsigned(c_refresh_cnt_nb_bits - 1 downto 0) := (others => '0');
  signal refresh_rate       : std_logic := '0';
  signal line_ctrl          : std_logic := '0';
  signal intensity_ctrl_cnt : unsigned(c_refresh_cnt_nb_bits - 1 downto 0) := (others => '0');
  signal intensity_ctrl     : std_logic := '0';
  signal line_oen_cnt       : unsigned(c_line_oen_cnt_nb_bits - 1 downto 0) := (others => '0');
  signal line_oen           : std_logic_vector(2**c_line_oen_cnt_nb_bits - 1 downto 0);
  signal led_state          : std_logic_vector((g_nb_line * g_nb_column) -1 downto 0);


begin

  ------------------------------------------------------------------------------
  -- Refresh rate counter
  ------------------------------------------------------------------------------
  p_refresh_rate_cnt : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        refresh_rate_cnt <= (others => '0');
        refresh_rate     <= '0';
      elsif refresh_rate_cnt = 0 then
        refresh_rate_cnt <= to_unsigned(c_refresh_cnt_init, c_refresh_cnt_nb_bits);
        refresh_rate     <= '1';
      else
        refresh_rate_cnt <= refresh_rate_cnt - 1;
        refresh_rate     <= '0';
      end if;
    end if;
  end process p_refresh_rate_cnt;


  ------------------------------------------------------------------------------
  -- Intensity control
  ------------------------------------------------------------------------------
  p_intensity_ctrl_cnt : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        intensity_ctrl_cnt <= (others => '0');
      elsif refresh_rate = '1' then
        intensity_ctrl_cnt <= to_unsigned(natural(c_refresh_cnt_init/100) * to_integer(unsigned(led_intensity_i)), c_refresh_cnt_nb_bits);
      else
        intensity_ctrl_cnt <= intensity_ctrl_cnt - 1;
      end if;
    end if;
  end process p_intensity_ctrl_cnt;

  p_intensity_ctrl : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        intensity_ctrl <= '0';
      elsif refresh_rate = '1' then
        intensity_ctrl <= '1';
      elsif intensity_ctrl_cnt = 0 then
        intensity_ctrl <= '0';
      end if;
    end if;
  end process p_intensity_ctrl;


  ------------------------------------------------------------------------------
  -- Lines output
  ------------------------------------------------------------------------------
  p_line_ctrl : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        line_ctrl <= '0';
      elsif refresh_rate = '1' then
        line_ctrl <= not(line_ctrl);
      end if;
    end if;
  end process p_line_ctrl;

  f_line_o : for i in 0 to g_nb_line - 1 generate
    line_o(I) <= line_ctrl and intensity_ctrl;
  end generate f_line_o;

  ------------------------------------------------------------------------------
  -- Lines output enable
  ------------------------------------------------------------------------------
  p_line_oen_cnt : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        line_oen_cnt <= (others => '0');
      elsif line_ctrl = '1' and refresh_rate = '1' then
        if line_oen_cnt = 0 then
          line_oen_cnt <= to_unsigned(g_nb_line - 1, c_line_oen_cnt_nb_bits);
        else
          line_oen_cnt <= line_oen_cnt - 1;
        end if;
      end if;
    end if;
  end process p_line_oen_cnt;

  p_line_oen_decode : process(line_oen_cnt)
    variable v_onehot : std_logic_vector((2**line_oen_cnt'length)-1 downto 0);
    variable v_index  : integer range 0 to (2**line_oen_cnt'length)-1;
  begin
    v_onehot := (others => '0');
    v_index  := 0;
    for i in line_oen_cnt'range loop
      if (line_oen_cnt(i) = '1') then
        v_index := 2*v_index+1;
      else
        v_index := 2*v_index;
      end if;
    end loop;
    v_onehot(v_index) := '1';
    line_oen          <= v_onehot;
  end process p_line_oen_decode;

  line_oen_o <= line_oen(line_oen_o'left downto 0);


  ------------------------------------------------------------------------------
  -- Columns output
  ------------------------------------------------------------------------------
  f_led_state : for i in 0 to (g_nb_column * g_nb_line) - 1 generate
    led_state(i) <= '0' when led_state_i(2 * i + 1 downto 2 * i) = c_led_red else
                    '1'                               when led_state_i(2 * i + 1 downto 2 * i) = c_led_green     else
                    not(line_ctrl and intensity_ctrl) when led_state_i(2 * i + 1 downto 2 * i) = c_led_red_green else
                    (line_ctrl and intensity_ctrl);  -- led off
  end generate f_led_state;

  f_column_o : for c in 0 to g_nb_column - 1 generate
    column_o(c) <= led_state(g_nb_column * to_integer(line_oen_cnt) + c);
  end generate f_column_o;


end rtl;
