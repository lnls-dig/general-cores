--------------------------------------------------------------------------------
-- CERN (BE-CO-HT)
-- General-Purpose Comparator
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:     gc_comparator
--
-- description:
--
--   This unit implements a general-purpose comparator with optional hysteresis.
--   The unit offers two outputs, one is the "traditional" comparator output
--   (output is high as long as positive input is greater than negative input),
--   while the other one is a monostable (one clock tick long) output.
--
--   Inputs have configurable width and they will be treated as signed vectors
--   internally. The Hysteresis input, if used, will be treated as an unsigned
--   vector.
--
--   A "polarity inversion" input bit is also available to make the comparator
--   output active when the positive input is below the negative input. If not
--   used, this input defaults to "non-inverted".
--
--   A "comparator enable" bit is also available to disable the outputs of the
--   comparator. This is useful when changing settings (threshold, polarity) to
--   avoid glitches on the outputs.
--
--   Pleas note that after reset (or after re-enabling the input), the unit will
--   wait for the positive input to drop below (above if inverted) the negative
--   input before performing any comparisons. This is done to avoid output
--   glitches when switching on and/or when changing settings.
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

entity gc_comparator is

  generic (
    -- Width of input vectors (in bits).
    g_IN_WIDTH : natural := 32);
  port (
    clk_i     : in  std_logic;
    rst_n_i   : in  std_logic                               := '1';
    -- Polarity inversion
    pol_inv_i : in  std_logic                               := '0';
    -- Comparator enable
    enable_i  : in  std_logic                               := '1';
    -- Positive input (treated as signed)
    inp_i     : in  std_logic_vector(g_IN_WIDTH-1 downto 0);
    -- Negative input (treated as signed)
    inn_i     : in  std_logic_vector(g_IN_WIDTH-1 downto 0);
    -- Hysteresis (treated as unsigned)
    hys_i     : in  std_logic_vector(g_IN_WIDTH-1 downto 0) := (others => '0');
    -- Comparator output
    out_o     : out std_logic;
    out_p_o   : out std_logic);

end entity gc_comparator;

architecture arch of gc_comparator is

  type t_FSM_STATE is (S_IDLE, S_BELOW_THRES, S_ABOVE_THRES1, S_ABOVE_THRES2);

  signal fsm_regin, fsm_regout : t_FSM_STATE := S_IDLE;

  signal inp_signx : signed(g_IN_WIDTH downto 0) := (others => '0');
  signal inn_signx : signed(g_IN_WIDTH downto 0) := (others => '0');
  signal hys_signx : signed(g_IN_WIDTH downto 0) := (others => '0');
  signal u_thres   : signed(g_IN_WIDTH downto 0) := (others => '0');
  signal l_thres   : signed(g_IN_WIDTH downto 0) := (others => '0');

  signal l_below : std_logic := '0';
  signal u_above : std_logic := '0';

  signal thr_cross : std_logic := '0';
  signal hys_cross : std_logic := '0';

  signal comp_out   : std_logic := '0';
  signal comp_out_p : std_logic := '0';

begin  -- architecture arch

  -- Convert inputs to signed and perform comparisons, taking into account
  -- optional hysteresis and polarity inversion. See also:
  -- https://en.wikipedia.org/wiki/Comparator#Hysteresis
  inp_signx <= resize(signed(inp_i), g_IN_WIDTH+1);
  inn_signx <= resize(signed(inn_i), g_IN_WIDTH+1);
  hys_signx <= signed('0' & hys_i);
  u_thres   <= inn_signx when pol_inv_i = '0'     else inn_signx + hys_signx;
  l_thres   <= inn_signx when pol_inv_i = '1'     else inn_signx - hys_signx;
  u_above   <= '1'       when inp_signx > u_thres else '0';
  l_below   <= '1'       when inp_signx < l_thres else '0';
  thr_cross <= u_above   when pol_inv_i = '0'     else l_below;
  hys_cross <= l_below   when pol_inv_i = '0'     else u_above;

  p_fsm_seq : process (clk_i) is
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' or enable_i = '0' then
        fsm_regout <= S_IDLE;
      else
        fsm_regout <= fsm_regin;
      end if;
    end if;
  end process p_fsm_seq;

  p_fsm_comb : process (fsm_regout, hys_cross, thr_cross) is
    -- Variable to hold changes to our FSM register
    -- within the current clock cycle.
    variable v_fsm_reg : t_FSM_STATE := S_IDLE;
  begin

    -- Default values for FSM combinatorial outputs. Overriden
    -- when necessary by each state.
    comp_out   <= '0';
    comp_out_p <= '0';

    -- First load register values from previous cycle.
    v_fsm_reg := fsm_regout;

    case v_fsm_reg is

      -- We can only end here after a reset or enable_i = '0'.
      -- Wait for input to drop below lower threshold
      -- before we start tracking it.
      when S_IDLE =>
        if hys_cross = '1' then
          v_fsm_reg := S_BELOW_THRES;
        end if;

      -- Signal is below lower threshold.
      when S_BELOW_THRES =>
        if thr_cross = '1' then
          v_fsm_reg := S_ABOVE_THRES1;
        end if;

      -- Signal is above upper threshold, pulse the
      -- monostable output and change state.
      when S_ABOVE_THRES1 =>
        comp_out   <= '1';
        comp_out_p <= '1';
        if hys_cross = '1' then
          v_fsm_reg := S_BELOW_THRES;
        else
          v_fsm_reg := S_ABOVE_THRES2;
        end if;

      -- Signal is still below threshold, wait for it.
      when S_ABOVE_THRES2 =>
        comp_out <= '1';
        if hys_cross = '1' then
          v_fsm_reg := S_BELOW_THRES;
        end if;

      -- Re-init the FSM if something unexpected happens.
      when others =>
        v_fsm_reg := S_IDLE;

    end case;

    -- Last step, update register values for next cycle
    fsm_regin <= v_fsm_reg;

  end process p_fsm_comb;

  -- Assign comparator outputs
  out_o   <= comp_out;
  out_p_o <= comp_out_p;

end architecture arch;
