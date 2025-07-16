-------------------------------------------------------------------------------
-- Title      : gc_pi_regulator testbench
-- Project    :
-------------------------------------------------------------------------------
-- File       : gc_iq_demodulator_tb.vhd
-- Author     : David Daminelli <david.daminelli@lnls.br>
-- Company    : Brazilian Synchrotron Light Laboratory, LNLS/CNPEM
-- Created    : 2025-07-15
-- Last update: 2025-07-15
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Testbench for the gc_pi_regulator core.
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Brazilian Synchrotron Light Laboratory, LNLS/CNPEM
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author            Description
-- 2025-07-15  1.0      david.daminelli   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library std;

library work;

entity gc_pi_regulator_tb is
end entity gc_pi_regulator_tb;

architecture tb of gc_pi_regulator_tb is

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

  -- Wait for clock cycles
  procedure f_wait_cycles(signal   clk    : in std_logic;
                          constant cycles : natural) is
    begin
      for i in 1 to cycles loop
        wait until rising_edge(clk);
      end loop;
    end procedure f_wait_cycles;

  -------- Constants declarations --------
  -- UUT Constants
  constant c_DATA_BITS        : positive := 16;
  constant c_GAIN_BITS        : integer  := 16;
  constant c_GAIN_FRAC_BITS   : integer  := 16;
  constant c_INTEGRATOR_BITS  : integer  := 32;
  constant c_OUTPUT_BITS      : positive := 16;
  --
  constant c_CLK_FREQ         : natural  := 100e3;
  constant c_CLK_PERIOD       : real     := 1.0/real(c_CLK_FREQ);
  constant c_UUT_GAIN         : integer  := 2**c_GAIN_FRAC_BITS;

  -------- Type declarations --------
  type t_dly is array(natural range <>) of integer;

  -------- Signal declarations --------
  -- UUT signals
  signal clk, rst         : std_logic := '0';
  signal x                : std_logic_vector(c_DATA_BITS-1 downto 0) := (others => '0');
  signal y                : std_logic_vector(c_OUTPUT_BITS-1 downto 0) := (others => '0');
  signal y_d_arr          : t_dly(0 to 1) := (others => 0);
  signal setpoint         : integer := 0;
  signal x_valid, y_valid : std_logic := '0';
  signal kp, ki           : integer := 0 ;
  signal en, lim          : std_logic := '1';
  --
  signal perror, acc   : integer := 0;
begin
  f_gen_clk(c_CLK_FREQ, clk);

  p_gen_stimulus: process
  begin
    rst <= '1';
    f_wait_cycles(clk,1);
    rst <= '0';
    f_wait_cycles(clk,1);
    x_valid <= '1';
    for p in 0 to (c_GAIN_BITS-1) loop
      kp <= 2**p-1;
      for i in 0 to (c_GAIN_BITS-1) loop
        ki <= 2**i-1;
        for s in 0 to (c_DATA_BITS-1) loop
          -- Positive Impulse
          setpoint <= 2**s-1;
          f_wait_cycles(clk, 1);
          setpoint <= 0;
          f_wait_cycles(clk, 1);
          f_wait_cycles(clk, 10);
          -- Negative Impulse
          setpoint <= -2**s;
          f_wait_cycles(clk, 1);
          setpoint <= 0;
          f_wait_cycles(clk, 1);
          f_wait_cycles(clk, 10);
          -- Reset for next cycle
          rst <= '1';
          f_wait_cycles(clk,1);
          rst <= '0';
          f_wait_cycles(clk,1);
        end loop;
      end loop;
    end loop;
    std.env.finish;
  end process;

  p_pi: process(clk)
    variable v_ierr : integer := 0;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        perror <= 0;
        acc <= 0;
      else
        perror <= kp*setpoint;
        v_ierr := ki*setpoint;
        acc <= v_ierr + acc;
      end if;
    end if;
  end process;

  p_assert: process(clk)
    variable v_y_int    : integer;
    variable v_abs_err  : real := 0.0;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        y_d_arr(0) <= 0;
        y_d_arr(1) <= 0;
      else
        y_d_arr(0) <= (perror + acc)/c_UUT_GAIN;
        y_d_arr(1) <= y_d_arr(0);
        v_y_int := to_integer(signed(y));
      end if;
      if y_valid = '1' then
        v_abs_err := abs(real(y_d_arr(1)) - real(v_y_int));
        assert  v_abs_err <= 2.0
          report  "Wrong value at ki = " & to_string(ki) &
                  " kp = " & to_string(kp) &
                  " setpoint = " & to_string(setpoint)
        severity failure;
      end if;
    end if;
  end process;

  -------- Entity instantiation --------
  UUT: entity work.gc_pi_regulator
  generic map(
    g_DATA_BITS       => c_DATA_BITS,
    g_GAIN_BITS       => c_GAIN_BITS,
    g_GAIN_FRAC_BITS  => c_GAIN_FRAC_BITS,
    g_INTEGRATOR_BITS => c_INTEGRATOR_BITS,
    g_OUTPUT_BITS     => c_OUTPUT_BITS
  )
  port map(
    clk_i       => clk,
    rst_i       => rst,
    en_i        => en,
    setpoint_i  => std_logic_vector(to_signed(setpoint, c_DATA_BITS)),
    x_valid_i   => x_valid,
    x_i         => x,
    y_valid_o   => y_valid,
    y_o         => y,
    kp_i        => std_logic_vector(to_signed(kp, c_GAIN_BITS)),
    ki_i        => std_logic_vector(to_signed(ki, c_GAIN_BITS)),
    lim_o       => lim
  );

end architecture tb;