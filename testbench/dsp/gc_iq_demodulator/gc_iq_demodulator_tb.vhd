-------------------------------------------------------------------------------
-- Title      : gc_iq_demodulator testbench
-- Project    :
-------------------------------------------------------------------------------
-- File       : gc_iq_demodulator_tb.vhd
-- Author     : David Daminelli <david.daminelli@lnls.br>
-- Company    : Brazilian Synchrotron Light Laboratory, LNLS/CNPEM
-- Created    : 2025-06-18
-- Last update: 2025-06-18
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Testbench for the gc_iq_demodulator core.
--              A cosine signal is input to the core, with amplitude varying
--              from 0 to 2**(c_N-1) - 1 and phase sweeping from 0 to 2π.
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Brazilian Synchrotron Light Laboratory, LNLS/CNPEM
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author            Description
-- 2025-06-18  1.0      david.daminelli   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;

library work;

entity gc_iq_demodulator_tb is
end entity gc_iq_demodulator_tb;

architecture tb of gc_iq_demodulator_tb is

  -------- Procedure declarations --------
  -- Clock generation
  procedure f_gen_clk(constant freq : in    natural;
                      signal   clk  : inout std_logic) is
    begin
      loop
        wait for (0.5 / real(freq)) * 1 sec;
        clk <= not clk;
      end loop;
    end procedure f_gen_clk;

  -- Wait cycles
  procedure f_wait_cycles(signal   clk    : in std_logic;
                          constant cycles : natural) is
    begin
      for i in 1 to cycles loop
        wait until rising_edge(clk);
      end loop;
    end procedure f_wait_cycles;

  -------- Constants declarations --------
  constant c_clk_freq : natural   := 100e3;
  constant c_in_freq  : real      := real(c_clk_freq)/4.0;
  constant c_N        : positive  := 16;

  -------- Type declaration --------
  type t_IQ_STATE is (INPH, MINUS_QUAD, MINUS_INPH, QUAD);

  -------- Signal declarations --------
  signal clk          : std_logic := '0';
  signal rst          : std_logic := '0';
  signal s_data_in    : std_logic_vector(c_N-1 downto 0);
  signal s_data_in_d0 : std_logic_vector(c_N-1 downto 0);
  signal s_i, s_q     : std_logic_vector(c_N downto 0);
  signal s_sync       : std_logic := '0';
  signal s_sine       : real      := 0.0;
  signal s_state      : t_IQ_STATE := INPH;

begin
  f_gen_clk(c_clk_freq, clk);

  -------- Test processes --------
  s_data_in <= std_logic_vector(to_signed(integer(s_sine), s_data_in'length));

  -- Loop through amplitutes and phases
  p_gen_stimulus: process
    variable v_amp, v_phs : real := 0.0;
  begin
    rst <= '1';
    f_wait_cycles(clk, 5);
    rst <= '0';
    f_wait_cycles(clk, 1);

    -- Loop through c_N amplitudes
    for i in 0 to c_N-1 loop
      s_sync <= '1';
      f_wait_cycles(clk, 1);
      s_sync <= '0';
      f_wait_cycles(clk, 1);
      v_amp := 2.0**real(i) - 1.0;
      -- Loop through 20 phases
      for j in 0 to 19 loop
        v_phs := real(j) * 2.0*math_pi/20.0;
        -- Compute 50 sine samples for each {amplitude,phase} pair
        for k in 0 to 49 loop
          s_sine <= v_amp *
                  cos(2.0 * math_pi * c_in_freq *
                  real(k)/real(c_clk_freq)
                  + v_phs);
          f_wait_cycles(clk, 1);
        end loop;
      end loop;
    end loop;
    report "Finished!";
    std.env.finish;
  end process;

  -- Asserting the output is the expected
  p_assert: process(clk)
    variable v_is_valid_output_correct, v_is_null_output_correct : boolean;
  begin
    if rising_edge(clk) then
      -- Delay the input signal by 1 cycle to match core delay
      s_data_in_d0 <= s_data_in;

      if rst = '1' then
        s_state <= INPH;
        s_data_in_d0 <= (others => '0');
      elsif s_sync = '1' then
        s_state <= MINUS_QUAD;
      else
        -- All this comparisons are delayed by 1 clock cycle.
        -- Each clock cycle has a valid output while the other is zero.
        -- s_{i,q} is one bit longer than s_data_in_d0.
        case s_state is
          when INPH =>
            s_state <= MINUS_QUAD;
            v_is_valid_output_correct :=
                      resize(signed(s_data_in_d0), s_q'length) = (signed(s_q));
            v_is_null_output_correct  :=
                      s_i = std_logic_vector(to_signed(0, c_N+1));
          when MINUS_QUAD =>
            s_state <= MINUS_INPH;
            v_is_valid_output_correct :=
                      resize(signed(s_data_in_d0), s_i'length) = (signed(s_i));
            v_is_null_output_correct  :=
                      s_q = std_logic_vector(to_signed(0, c_N+1));
          when MINUS_INPH =>
            s_state <= QUAD;
            v_is_valid_output_correct :=
                      resize(signed(s_data_in_d0), s_q'length) = (-signed(s_q));
            v_is_null_output_correct  :=
                      s_i = std_logic_vector(to_signed(0, c_N+1));
          when QUAD =>
            s_state <= INPH;
            v_is_valid_output_correct :=
                      resize(signed(s_data_in_d0), s_i'length) = (-signed(s_i));
            v_is_null_output_correct  :=
                      s_q = std_logic_vector(to_signed(0, c_N+1));
        end case;
        -- Assert the valid output
        assert v_is_valid_output_correct
          report "Error in valid output"
        severity failure;
        -- Assert the zero output
        assert v_is_null_output_correct
          report "Error in zero output"
        severity failure;
      end if;
    end if;
  end process;

  -------- Entity instantiation --------
  UUT: entity work.gc_iq_demodulator
  generic map (
    g_N => c_N
  )
  port map (
    clk_i       => clk,
    rst_i       => rst,
    sync_p1_i   => s_sync,
    adc_data_i  => s_data_in,
    i_o         => s_i,
    q_o         => s_q
  );

end architecture tb;
