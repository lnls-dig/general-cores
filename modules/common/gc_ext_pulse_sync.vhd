-- This module was copied as is (apart from this comment header and some minor
-- changes, see below) from the project FMC ADC 100M 14B 4CHA from ohwr repository,
-- available at http://www.ohwr.org/projects/fmc-adc-100m14b4cha/repository
--
-- Changes from the original module:
--
-- name change: ext_pulse_sync -> gc_ext_pulse_sync
-- use local log2_ceil function based on the one at wishbone_pkg: the function
--		log2_ceil is replaced by the a modified f_ceil_log2 function in order
-- 		to	obtain identical outputs for the set of input values
--		(log(x) = 1, x <= 2 for log2_ceil in utils_pkg, but
--		(log(x) = 0, x <= 1; log(x) = 1, x = 2, for f_ceil_log2 in wishbone_pkg)
--		(log(x) = 1, x <= 2, for f_ceil_log2 in local body)
-- use lowercase for generics

--=============================================================================
-- @file ext_pulse_sync_rtl.vhd
--=============================================================================
--! Standard library
library IEEE;
--! Standard packages
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library work;
--use work.utils_pkg.all;
--! Specific packages
-------------------------------------------------------------------------------
-- --
-- CERN, BE-CO-HT, Synchronize an asnychronous external pulse to a clock
-- --
-------------------------------------------------------------------------------
--
-- Unit name: External pulse synchronizer (ext_pulse_sync_rtl)
--
--! @brief Synchronize an asnychronous external pulse to a clock
--!
--
--! @author Matthieu Cattin (matthieu dot cattin at cern dot ch)
--
--! @date 22\10\2009
--
--! @version v1.0
--
--! @details Latency = 5 clk_i ticks
--!
--! <b>Dependencies:</b>\n
--! utils_pkg.vhd
--!
--! <b>References:</b>\n
--!
--!
--! <b>Modified by:</b>\n
--! Author:
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 22.10.2009    mcattin     Creation from pulse_sync_rtl.vhd
--! 27.10.2009    mcattin     Possibility for output monostable to be
--!                           retriggerable
--! 03.03.2011    mcattin     Input polarity from port instead of generic
-------------------------------------------------------------------------------
--! @todo
--
-------------------------------------------------------------------------------


--=============================================================================
--! Entity declaration for External pulse synchronizer
--=============================================================================
entity gc_ext_pulse_sync is
  generic(
    g_min_pulse_width : natural   := 2;      --! Minimum input pulse width
                                             --! (in ns), must be >1 clk_i tick
    g_clk_frequency   : natural   := 40;     --! clk_i frequency (in MHz)
    g_output_polarity : std_logic := '1';    --! pulse_o polarity
                                             --! (1=negative, 0=positive)
    g_output_retrig   : boolean   := false;  --! Retriggerable output monostable
    g_output_length   : natural   := 1       --! pulse_o lenght (in clk_i ticks)
    );
  port (
    rst_n_i          : in  std_logic;        --! Reset (active low)
    clk_i            : in  std_logic;        --! Clock to synchronize pulse
    input_polarity_i : in  std_logic;        --! Input pulse polarity (1=negative, 0=positive)
    pulse_i          : in  std_logic;        --! Asynchronous input pulse
    pulse_o          : out std_logic         --! Synchronized output pulse
    );
end entity gc_ext_pulse_sync;


--=============================================================================
--! Architecture declaration External pulse synchronizer
--=============================================================================
architecture rtl of gc_ext_pulse_sync is

  function f_ceil_log2(x : natural) return natural is
  begin
    --if x <= 1
    if x <= 2
    --then return 0;
    then return 1;
    else return f_ceil_log2((x+1)/2) +1;
    end if;
  end f_ceil_log2;

  --! g_MIN_PULSE_WIDTH converted into clk_i ticks
  constant c_nb_ticks : natural := 1 + to_integer(to_unsigned(g_min_pulse_width, f_ceil_log2(g_min_pulse_width))*
                                                  to_unsigned(g_clk_frequency, f_ceil_log2(g_clk_frequency))/
                                                  to_unsigned(1000, f_ceil_log2(1000)));
  --! FFs to synchronize input pulse
  signal s_pulse_sync_reg   : std_logic_vector(1 downto 0)                  := (others => '0');
  --! Pulse length counter
  signal s_pulse_length_cnt : unsigned(f_ceil_log2(c_nb_ticks) downto 0)      := (others => '0');
  --! Output pulse monostable counter
  signal s_monostable_cnt   : unsigned(f_ceil_log2(g_output_length) downto 0) := (others => '0');
  --! Pulse to start output monostable
  signal s_sync_pulse       : std_logic_vector(1 downto 0)                  := (others => '0');
  --! Output pulse for readback
  signal s_output_pulse     : std_logic                                     := '0';


--=============================================================================
--! Architecture begin
--=============================================================================
begin


--*****************************************************************************
-- Begin of p_pulse_sync
--! Process: Synchronise input pulse to clk_i clock
--*****************************************************************************
  p_pulse_sync : process(clk_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      s_pulse_sync_reg <= (others => '0');
    elsif rising_edge(clk_i) then
      s_pulse_sync_reg <= s_pulse_sync_reg(0) & pulse_i;
    end if;
  end process p_pulse_sync;


--*****************************************************************************
-- Begin of p_pulse_length_cnt
--! Process: Counts input pulse length
--*****************************************************************************
  p_pulse_length_cnt : process(clk_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      s_pulse_length_cnt <= (others => '0');
      s_sync_pulse(0)    <= '0';
    elsif rising_edge(clk_i) then
      if s_pulse_sync_reg(1) = input_polarity_i then
        s_pulse_length_cnt <= (others => '0');
        s_sync_pulse(0)    <= '0';
      elsif s_pulse_length_cnt = to_unsigned(c_nb_ticks, s_pulse_length_cnt'length) then
        s_sync_pulse(0) <= '1';
      elsif s_pulse_sync_reg(1) = not(input_polarity_i) then
        s_pulse_length_cnt <= s_pulse_length_cnt + 1;
        s_sync_pulse(0)    <= '0';
      end if;
    end if;
  end process p_pulse_length_cnt;


--*****************************************************************************
-- Begin of p_start_pulse
--! Process: FF to generate monostable start pulse
--*****************************************************************************
  p_start_pulse : process (clk_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      s_sync_pulse(1) <= '0';
    elsif rising_edge(clk_i) then
      s_sync_pulse(1) <= s_sync_pulse(0);
    end if;
  end process p_start_pulse;


--*****************************************************************************
-- Begin of p_monostable
--! Process: Monostable to generate output pulse
--*****************************************************************************
  p_monostable : process (clk_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      s_monostable_cnt <= (others => '0');
      s_output_pulse   <= g_output_polarity;
    elsif rising_edge(clk_i) then
      if ((not(g_output_retrig) and ((s_sync_pulse(0) and not(s_sync_pulse(1))) = '1')
           and (s_output_pulse = g_output_polarity))              -- non-retriggerable
          or (g_output_retrig and (s_sync_pulse(0) = '1'))) then  -- retriggerable
        s_monostable_cnt <= to_unsigned(g_output_length, s_monostable_cnt'length) - 1;
        s_output_pulse   <= not(g_output_polarity);
      elsif s_monostable_cnt = to_unsigned(0, s_monostable_cnt'length) then
        s_output_pulse <= g_output_polarity;
      else
        s_monostable_cnt <= s_monostable_cnt - 1;
      end if;
    end if;
  end process p_monostable;

  pulse_o <= s_output_pulse;

end architecture rtl;
--=============================================================================
--! Architecture end
--=============================================================================
