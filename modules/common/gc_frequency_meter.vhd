library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.gencores_pkg.all;

entity gc_frequency_meter is
  generic(
    g_with_internal_timebase : boolean := true;
    g_clk_sys_freq           : integer;
    g_counter_bits           : integer := 32);

  port(
    clk_sys_i    : in  std_logic;
    clk_in_i     : in  std_logic;
    rst_n_i      : in  std_logic;
    pps_p1_i     : in  std_logic;
    freq_o       : out std_logic_vector(g_counter_bits-1 downto 0);
    freq_valid_o : out std_logic
    );

end gc_frequency_meter;


architecture behavioral of gc_frequency_meter is

  signal gate_pulse, gate_pulse_synced : std_logic;

  signal cntr_gate : unsigned(g_counter_bits-1 downto 0);
  signal cntr_meas : unsigned(g_counter_bits-1 downto 0);
  signal freq_reg  : std_logic_vector(g_counter_bits-1 downto 0);

begin

  gen_internal_timebase : if(g_with_internal_timebase = true) generate

    p_gate_counter : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          cntr_gate  <= (others => '0');
          gate_pulse <= '0';
        else
          if(cntr_gate = g_clk_sys_freq-1) then
            cntr_gate  <= (others => '0');
            gate_pulse <= '1';
          else
            cntr_gate  <= cntr_gate + 1;
            gate_pulse <= '0';
          end if;
        end if;
      end if;
    end process;

  end generate gen_internal_timebase;

  gen_external_timebase : if(g_with_internal_timebase = false) generate
    gate_pulse <= pps_p1_i;
  end generate gen_external_timebase;

  U_Sync_Gate : gc_pulse_synchronizer
    port map (
      clk_in_i  => clk_sys_i,
      clk_out_i => clk_in_i,
      rst_n_i   => rst_n_i,
      d_ready_o => freq_valid_o,
      d_p_i     => gate_pulse,
      q_p_o     => gate_pulse_synced);

  p_freq_counter : process (clk_in_i, rst_n_i)
  begin
    if rst_n_i = '0' then               -- asynchronous reset (active low)
      cntr_meas <= (others => '0');
      freq_reg  <= (others => '0');
    elsif rising_edge(clk_in_i) then
      
      if(gate_pulse_synced = '1') then
        freq_reg  <= std_logic_vector(cntr_meas);
        cntr_meas <= (others => '0');
      else
        cntr_meas <= cntr_meas + 1;
      end if;
    end if;
  end process p_freq_counter;

  freq_o <= freq_reg;
end behavioral;


