-------------------------------------------------------------------------------
-- Title      : Dual channel PI controller for use in WR PLLs
-- Project    : White Rabbit 
-------------------------------------------------------------------------------
-- File       : gc_dual_pi_controller.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-06-14
-- Last update: 2011-04-29
-- Platform   : FPGA-generic
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Dual, programmable PI controller:
-- - first channel processes the frequency error (gain defined by P_KP/P_KI)
-- - second channel processes the phase error (gain defined by F_KP/F_KI)
-- Mode is selected by the mode_sel_i port and FORCE_F field in PCR register.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2009 - 2010 CERN
--
-- This source file is free software; you can redistribute it   
-- and/or modify it under the terms of the GNU Lesser General   
-- Public License as published by the Free Software Foundation; 
-- either version 2.1 of the License, or (at your option) any   
-- later version.                                               
--
-- This source is distributed in the hope that it will be       
-- useful, but WITHOUT ANY WARRANTY; without even the implied   
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      
-- PURPOSE.  See the GNU Lesser General Public License for more 
-- details.                                                     
--
-- You should have received a copy of the GNU Lesser General    
-- Public License along with this source; if not, download it   
-- from http://www.gnu.org/licenses/lgpl-2.1.html
--
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2010-06-14  1.0      twlostow        Created
-- 2010-07-16  1.1      twlostow        added anti-windup
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;

entity gc_dual_pi_controller is
  generic(
    g_error_bits          : integer := 12;
    g_dacval_bits         : integer := 16;
    g_output_bias         : integer := 32767;
    g_integrator_fracbits : integer := 16;
    g_integrator_overbits : integer := 6;
    g_coef_bits           : integer := 16

    );
  port (
    clk_sys_i      : in std_logic;
    rst_n_sysclk_i : in std_logic;

-------------------------------------------------------------------------------
-- Phase & frequency error inputs
-------------------------------------------------------------------------------

    phase_err_i       : in std_logic_vector(g_error_bits-1 downto 0);
    phase_err_stb_p_i : in std_logic;

    freq_err_i       : in std_logic_vector(g_error_bits-1 downto 0);
    freq_err_stb_p_i : in std_logic;

-- mode select input: 1 = frequency mode, 0 = phase mode
    mode_sel_i : in std_logic;

-------------------------------------------------------------------------------
-- DAC Output
-------------------------------------------------------------------------------

    dac_val_o       : out std_logic_vector(g_dacval_bits-1 downto 0);
    dac_val_stb_p_o : out std_logic;



-------------------------------------------------------------------------------
-- Wishbone regs
-------------------------------------------------------------------------------    

-- PLL enable
    pll_pcr_enable_i : in std_logic;

-- PI force freq mode. '1' causes the PI to stay in frequency lock mode all the
-- time.
    pll_pcr_force_f_i : in std_logic;

-- Frequency Kp/Ki
    pll_fbgr_f_kp_i : in std_logic_vector(g_coef_bits-1 downto 0);
    pll_fbgr_f_ki_i : in std_logic_vector(g_coef_bits-1 downto 0);

-- Phase Kp/Ki
    pll_pbgr_p_kp_i : in std_logic_vector(g_coef_bits-1 downto 0);
    pll_pbgr_p_ki_i : in std_logic_vector(g_coef_bits-1 downto 0)


    );

end gc_dual_pi_controller;

architecture behavioral of gc_dual_pi_controller is

  type t_dmpll_state is (PI_CHECK_MODE, PI_WAIT_SAMPLE, PI_MUL_KI, PI_INTEGRATE, PI_MUL_KP, PI_CALC_SUM, PI_SATURATE, PI_ROUND_SUM, PI_DISABLED);

  -- integrator size: 12 error bits + 16 coefficient bits + 6 overflow bits
  constant c_INTEGRATOR_BITS : integer := g_error_bits + g_integrator_overbits + g_coef_bits;

  constant c_ZEROS : unsigned (63 downto 0) := (others => '0');
  constant c_ONES  : unsigned (63 downto 0) := (others => '1');

  -- DAC DC bias (extended by c_INTEGRATOR_FRACBITS). By default it's half of the
  -- output voltage scale.
  constant c_OUTPUT_BIAS : signed(g_dacval_bits + g_integrator_fracbits-1 downto 0) := to_signed(g_output_bias, g_dacval_bits) & to_signed(0, g_integrator_fracbits);

  -- Multiplier size. A = error value, B = coefficient value
  constant c_MUL_A_BITS : integer := g_error_bits;
  constant c_MUL_B_BITS : integer := g_coef_bits;

  -- the integrator
  signal i_reg : signed(c_INTEGRATOR_BITS-1 downto 0);

  -- multiplier IO
  signal mul_A   : signed(c_MUL_A_BITS - 1 downto 0);
  signal mul_B   : signed(c_MUL_B_BITS - 1 downto 0);
  signal mul_OUT : signed(c_MUL_A_BITS + c_MUL_B_BITS - 1 downto 0);

  signal mul_out_reg : signed(c_MUL_A_BITS + c_MUL_B_BITS - 1 downto 0);

  signal pi_state : t_dmpll_state;

  -- 1: we are in the frequency mode, 0: we are in phase mode.
  signal freq_mode    : std_logic;
  signal freq_mode_ld : std_logic;

  signal output_val           : unsigned(c_INTEGRATOR_BITS-1 downto 0);
  signal output_val_unrounded : unsigned(g_dacval_bits-1 downto 0);
  signal output_val_round_up  : std_logic;

  signal dac_val_int       : std_logic_vector(g_dacval_bits-1 downto 0);
  signal output_val_sign   : std_logic;
  signal output_val_sat_hi : std_logic;
  signal output_val_sat_lo : std_logic;

  signal s_zero : unsigned(63 downto 0) := (others => '0');

  signal anti_windup_hi, anti_windup_lo : std_logic;
  
begin  -- behavioral

-- shared multiplier
  multiplier : process (mul_A, mul_B)
  begin  -- process
    mul_OUT <= mul_A * mul_B;
  end process;

  output_val_unrounded <= output_val(g_integrator_fracbits + g_dacval_bits - 1 downto g_integrator_fracbits);
  output_val_round_up  <= std_logic(output_val(g_integrator_fracbits - 1));

-- saturation detect logic

  output_val_sign <= output_val(output_val'high);

  output_val_sat_hi <= '1' when output_val_sign = '0' and (output_val(output_val'high-1 downto g_integrator_fracbits+g_dacval_bits) /= s_zero(output_val'high-1 downto g_integrator_fracbits+g_dacval_bits)) else '0';

  output_val_sat_lo <= '1' when output_val_sign = '1' else '0';


  main_fsm : process (clk_sys_i, rst_n_sysclk_i)
  begin  -- process
    if rising_edge(clk_sys_i) then
      if rst_n_sysclk_i = '0' then
        i_reg           <= (others => '0');
        freq_mode       <= '1';         -- start in frequency lock mode
        pi_state        <= PI_CHECK_MODE;
        dac_val_stb_p_o <= '0';
        dac_val_int <= std_logic_vector(to_unsigned(g_output_bias, dac_val_int'length));
        freq_mode       <= '1';

      else
          case pi_state is
            when PI_DISABLED =>
              dac_val_stb_p_o <= '0';

              if(pll_pcr_enable_i = '1') then
                pi_state <= PI_CHECK_MODE;
              end if;

            when PI_CHECK_MODE =>
              
              if(pll_pcr_force_f_i = '0') then
                freq_mode <= mode_sel_i;
              else
                freq_mode <= '1';
              end if;
              if(pll_pcr_enable_i = '1') then
                dac_val_stb_p_o <= '0';                 
                pi_state <= PI_WAIT_SAMPLE;
              else
          dac_val_stb_p_o <= '1';
          dac_val_int <= std_logic_vector(to_unsigned(g_output_bias, dac_val_int'length));
                pi_state <= PI_DISABLED;
          freq_mode <= '1';
              end if;

-------------------------------------------------------------------------------
-- State: DMPLL wait for input sample. When a frequency error (or phase error)
-- sample arrives from the detector, start the PI update.
-------------------------------------------------------------------------------
              
            when PI_WAIT_SAMPLE =>


-- frequency lock mode, got a frequency sample
              if(freq_mode = '1' and freq_err_stb_p_i = '1') then
                pi_state <= PI_MUL_KI;
                mul_A    <= signed(freq_err_i);
                mul_B    <= signed(pll_fbgr_f_ki_i);
-- phase lock mode, got a phase sample
              elsif (freq_mode = '0' and phase_err_stb_p_i = '1') then
                pi_state <= PI_MUL_KI;
                mul_A    <= signed(phase_err_i);
                mul_B    <= signed(pll_pbgr_p_ki_i);
              end if;

-------------------------------------------------------------------------------
-- State: DMPLL multiply by Ki: multiples the phase/freq error by an appropriate
-- Kp/Ki coefficient, set up the multipler for (error * Kp) operation.
-------------------------------------------------------------------------------              
            when PI_MUL_KI =>


              if(freq_mode = '1') then
                mul_B <= signed(pll_fbgr_f_kp_i);
              else
                mul_B <= signed(pll_pbgr_p_kp_i);
              end if;

              mul_out_reg <= mul_OUT;   -- just keep the result
              pi_state    <= PI_INTEGRATE;

-------------------------------------------------------------------------------
-- State: HPLL integrate: add the (Error * Ki) to the integrator register
-------------------------------------------------------------------------------              
            when PI_INTEGRATE =>

              
              if(anti_windup_lo = '0' and anti_windup_hi = '0') then
                i_reg <= i_reg + mul_out_reg;
              end if;

              -- the output is saturated to MAX value, but the (Ki*error)
              -- is negative, or the output is saturated to MIN value
              -- and the (Ki*error) is positive
              if (anti_windup_hi = '1' and mul_out_reg(mul_out_reg'high) = '1') or (anti_windup_lo = '1' and mul_out_reg(mul_out_reg'high) = '0') then  --
                i_reg <= i_reg + mul_out_reg;
              end if;


              pi_state <= PI_MUL_KP;

-------------------------------------------------------------------------------
-- State: HPLL multiply by Kp: does the same as PI_MUL_KI but for the proportional
-- branch. 
-------------------------------------------------------------------------------              
            when PI_MUL_KP =>


              mul_out_reg <= mul_OUT;
              pi_state    <= PI_CALC_SUM;

              
            when PI_CALC_SUM =>

              output_val <= unsigned(c_OUTPUT_BIAS + resize(mul_out_reg, output_val'length) + resize(i_reg, output_val'length));
              pi_state   <= PI_SATURATE;


            when PI_SATURATE =>
              if(output_val_sat_hi = '1') then
                dac_val_int     <= (others => '1');
                dac_val_stb_p_o <= '1';
                pi_state        <= PI_CHECK_MODE;
                anti_windup_hi  <= '1';
                anti_windup_lo  <= '0';
              elsif (output_val_sat_lo = '1') then
                dac_val_int     <= (others => '0');
                dac_val_stb_p_o <= '1';
                pi_state        <= PI_CHECK_MODE;
                anti_windup_hi  <= '0';
                anti_windup_lo  <= '1';
              else
                anti_windup_lo <= '0';
                anti_windup_hi <= '0';
                pi_state       <= PI_ROUND_SUM;
              end if;


-------------------------------------------------------------------------------
-- State: HPLL round sum: calculates the final DAC value, with 0.5LSB rounding.
-- Also checks for the frequency lock.
-------------------------------------------------------------------------------              

            when PI_ROUND_SUM =>
              dac_val_stb_p_o <= '1';


-- +-0.5 rounding of the output value
              if(output_val_round_up = '1') then
                dac_val_int <= std_logic_vector(output_val_unrounded + 1);
              else
                dac_val_int <= std_logic_vector(output_val_unrounded);
              end if;

              pi_state <= PI_CHECK_MODE;

            when others => null;
          end case;
        end if;
     end if;
  end process;

  dac_val_o <= dac_val_int;
  
  
end behavioral;
