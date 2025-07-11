-------------------------------------------------------------------------------
-- Title      : gc_iq_modulator.vhd testbench
-- Project    :
-------------------------------------------------------------------------------
-- File       : gc_iq_modulator_tb.vhd
-- Author     : David Daminelli <david.daminelli@lnls.br>
-- Company    : Brazilian Synchrotron Light Laboratory, LNLS/CNPEM
-- Created    : 2025-06-18
-- Last update: 2025-06-18
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: A testbench for the gc_iq_modulator.vhd core.
-- This testbench loops through a set of I and Q values, computes the expected
-- generates the corresponding sines, and compares it to the module's output.
-- The gc_iq_modulator.vhd core has two outputs that are 90° out of phase, and
-- both are asserted.
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

entity gc_iq_modulator_tb is
end entity gc_iq_modulator_tb;

architecture tb of gc_iq_modulator_tb is

  -------- Procedure Declaration --------
  -- Clock Generation
  procedure f_gen_clk(constant freq : in    natural;
                      signal   clk  : inout std_logic) is
    begin
      loop
        wait for (0.5 / real(freq)) * 1 sec;
        clk <= not clk;
      end loop;
    end procedure f_gen_clk;

  -- Wait procedure
  procedure f_wait_cycles(signal   clk    : in std_logic;
                          constant cycles : natural) is
    begin
      for i in 1 to cycles loop
        wait until rising_edge(clk);
      end loop;
    end procedure f_wait_cycles;

  -------- Constants Declaration --------
  constant c_clk_freq : natural   := 100e3;
  constant c_in_freq  : real      := real(c_clk_freq)/4.0;
  constant c_N        : positive  := 16; -- Data size

  -------- Type Declaration --------
  type t_IQ_STATE is (S_0, S_PI2, S_PI, S_3PI2);

  -------- Signal Declaration --------
  signal clk                  : std_logic := '0';
  signal rst                  : std_logic := '1';
  signal s_i_mod, s_i_mod_d0  : std_logic_vector(c_N-1 downto 0) := (others => '0');
  signal s_q_mod, s_q_mod_d0  : std_logic_vector(c_N-1 downto 0) := (others => '0');
  signal s_i_out, s_q_out     : std_logic_vector(c_N-1 downto 0) := (others => '0');
  signal s_i_in, s_q_in       : integer   := 0;
  signal s_sync               : std_logic := '0';
  signal s_en                 : std_logic := '1';
  signal s_state              : t_IQ_STATE := S_0;

begin
  -------- Clock generation --------
  f_gen_clk(c_clk_freq, clk);

  -------- Test Processes --------
  p_gen_stimulus: process
  begin
    s_sync <= '1';
    rst <= '1';
    f_wait_cycles(clk, 1);
    rst <= '0';
    f_wait_cycles(clk, 1);
    for i in 0 to c_N-2 loop -- Loop through I values
      s_i_in <= 2**i;
      for j in 0 to c_N-2 loop -- Loop through Q values
        s_q_in <= 2**j;
        s_sync <= '0';
        f_wait_cycles(clk, 1);
        f_wait_cycles(clk, 50); -- Wait 50 cycles in each value
      end loop;
    end loop;
    report "Finished!";
    std.env.finish;
  end process;

  p_modulator : process(clk) -- Generate the expected outputs
  begin
    if rising_edge(clk) then
      if rst = '1' then
        s_state <= S_0;
        s_i_mod <= (others => '0');
        s_q_mod <= (others => '0');
      elsif s_en = '0' then
        s_state <= S_0;
        s_i_mod <= std_logic_vector(to_signed(s_i_in, c_N));
        s_q_mod <= std_logic_vector(to_signed(s_q_in, c_N));
      elsif s_sync = '1' or s_state = S_3PI2 then
        s_state <= S_0;
        s_i_mod <= std_logic_vector(to_signed(s_i_in, c_N));
        s_q_mod <= std_logic_vector(to_signed(s_q_in, c_N));
      elsif s_state = S_0 then
        s_state <= S_PI2;
        s_i_mod <= std_logic_vector(to_signed(-s_q_in, c_N));
        s_q_mod <= std_logic_vector(to_signed(s_i_in, c_N));
      elsif s_state = S_PI2 then
        s_state <= S_PI;
        s_i_mod <= std_logic_vector(to_signed(-s_i_in, c_N));
        s_q_mod <= std_logic_vector(to_signed(-s_q_in, c_N));
      elsif s_state = S_PI then
        s_state <= S_3PI2;
        s_i_mod <= std_logic_vector(to_signed(s_q_in, c_N));
        s_q_mod <= std_logic_vector(to_signed(-s_i_in, c_N));
      end if;
    end if;
  end process;

  p_assert: process(clk)
  begin
    if rising_edge(clk) then
      -- Delay the outputs to match core delay
      s_i_mod_d0 <= s_i_mod;
      s_q_mod_d0 <= s_q_mod;
      if s_sync = '0' then -- Skip first clocks where output is undefined
        assert signed(s_i_mod_d0) = signed(s_i_out)
          report "Error in I output value " &
                  to_string(s_i_mod_d0) & " | " &
                  to_string(s_i_out)
        severity failure;
        assert signed(s_q_mod_d0) = signed(s_q_out)
          report "Error in Q output value "  &
                  to_string(s_q_mod_d0) & " | " &
                  to_string(s_q_out)
        severity failure;
      end if;
    end if;
  end process;

  -------- Entity instantiation --------
  UUT: entity work.gc_iq_modulator
  generic map (
    g_N => c_N
  )
  port map (
    clk_i     => clk,
    en_i      => s_en,
    rst_i     => rst,
    sync_p1_i => s_sync,
    i_i       => std_logic_vector(to_signed(s_i_in, c_N)),
    q_i       => std_logic_vector(to_signed(s_q_in, c_N)),
    i_o       => s_i_out,
    q_o       => s_q_out
  );

end architecture tb;