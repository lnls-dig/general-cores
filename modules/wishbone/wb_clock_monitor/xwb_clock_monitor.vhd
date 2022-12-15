--------------------------------------------------------------------------------
-- CERN BE-CEM-EDL
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_clock_monitor
--
-- description: Multichannel clock frequency monitor with Wishbone interface.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2020-2021
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;
use work.wishbone_pkg.all;
use work.cm_wbgen2_pkg.all;

entity xwb_clock_monitor is

  generic (
    g_NUM_CLOCKS : integer := 1;
    g_CLK_SYS_FREQ : integer := 62500000;
    g_WITH_INTERNAL_TIMEBASE : boolean := TRUE
    );
  port (
    rst_n_i   : in std_logic;
    clk_sys_i : in std_logic;

    clk_in_i : in std_logic_vector(g_num_clocks-1 downto 0);
    pps_p1_i : in std_logic := '0';

    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out
    );

end xwb_clock_monitor;

architecture rtl of xwb_clock_monitor is

  signal regs_in  : t_cm_in_registers;
  signal regs_out : t_cm_out_registers;

  type t_clock_state is record
    presc_cnt  : unsigned(4 downto 0);
    clk_in     : std_logic;
    clk_presc  : std_logic;
    pulse      : std_logic;
    counter    : unsigned(30 downto 0);
    valid_sreg : std_logic_vector(1 downto 0);
    freq       : unsigned(30 downto 0);
    ack        : std_logic;
  end record;

  type t_clock_state_array is array (integer range <>) of t_clock_state;

  signal clks    : t_clock_state_array(0 to g_num_clocks);
  signal rst_n_a : std_logic;

  signal ref_pulse_p : std_logic;
  signal gate_p      : std_logic;

  signal gate_cnt     : unsigned(31 downto 0);
  signal pps_p_sysclk : std_logic;

  signal cntr_gate : unsigned(30 downto 0) := (others => '0');
  signal gate_pulse, gate_pulse_synced : std_logic := '0';

begin

  gen_ext_pps : if g_WITH_INTERNAL_TIMEBASE = false generate
    
    U_PPS_Pulse_Detect : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => clk_sys_i,
        rst_n_i  => rst_n_i,
        data_i   => pps_p1_i,
        ppulse_o => pps_p_sysclk);

  end generate gen_ext_pps;

  gen_int_pps : if g_WITH_INTERNAL_TIMEBASE = true generate

    p_gate_counter : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          cntr_gate <= (others => '0');
          pps_p_sysclk <= '0';
        else
          if cntr_gate = g_CLK_SYS_FREQ-1 then
            cntr_gate  <= (others => '0');
            pps_p_sysclk <= '1';
          else
            cntr_gate  <= cntr_gate + 1;
            pps_p_sysclk <= '0';
          end if;
        end if;
      end if;
    end process;

  end generate gen_int_pps;
  

  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' or regs_out.cr_cnt_rst_o = '1' then
        gate_cnt <= (others => '0');
        gate_p   <= '0';
      else

        ref_pulse_p <= clks(to_integer(unsigned(regs_out.cr_refsel_o))).pulse;

        if unsigned(regs_out.cr_refsel_o) /= 15 then
          if ref_pulse_p = '1' then
            if gate_cnt = unsigned(regs_out.refdr_refdr_o) then
              gate_cnt <= (others => '0');
              gate_p   <= '1';
            else
              gate_cnt <= gate_cnt + 1;
              gate_p   <= '0';
            end if;
          else
            gate_p <= '0';
          end if;
        else
          gate_p <= pps_p_sysclk;
        end if;
      end if;
    end if;
  end process;



  rst_n_a <= rst_n_i;

  U_WB_Slave : entity work.clock_monitor_wb
    port map (
      rst_n_i   => rst_n_i,
      clk_sys_i => clk_sys_i,
      slave_i   => slave_i,
      slave_o   => slave_o,
      regs_i    => regs_in,
      regs_o    => regs_out);

  clks(g_num_clocks).clk_in <= clk_sys_i;

  gen1 : for i in 0 to g_num_clocks-1 generate
    clks(i).clk_in <= clk_in_i(i);
  end generate gen1;

  gen2 : for i in 0 to g_num_clocks generate

    p_clk_prescaler : process(clks(i).clk_in, rst_n_a)
    begin
      if rst_n_a = '0' then
        clks(i).presc_cnt <= (others => '0');
        clks(i).clk_presc <= '0';
      elsif rising_edge(clks(i).clk_in) then
        if(clks(i).presc_cnt = unsigned(regs_out.cr_presc_o)) then
          clks(i).presc_cnt <= (others => '0');
          clks(i).clk_presc <= not clks(i).clk_presc;
        else
          clks(i).presc_cnt <= clks(i).presc_cnt + 1;
        end if;
      end if;
    end process;

    U_Edge_Detect : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        clk_i    => clk_sys_i,
        rst_n_i  => rst_n_i,
        data_i   => clks(i).clk_presc,
        ppulse_o => clks(i).pulse);

  end generate gen2;


  gen3 : for i in 0 to g_num_clocks generate
    p_counter : process(clk_sys_i)
      variable cnt_idx : integer range 0 to g_num_clocks;
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' or regs_out.cr_cnt_rst_o = '1' then
          clks(i).counter    <= (others => '0');
          clks(i).valid_sreg <= (others => '0');
        else

          if(gate_p = '1') then
            clks(i).valid_sreg <= clks(i).valid_sreg(0) & '1';
            clks(i).freq       <= clks(i).counter;
            clks(i).counter    <= (others => '0');
          elsif clks(i).pulse = '1' then
            clks(i).counter <= clks(i).counter + 1;
          end if;

          if clks(i).ack = '1' then
            clks(i).valid_sreg(1) <= '0';
          end if;

          cnt_idx := to_integer(unsigned(regs_out.cnt_sel_sel_o));

          if (i = cnt_idx) then
            clks(i).ack <= regs_out.cnt_val_valid_o and regs_out.cnt_val_valid_load_o;
          else
            clks(i).ack <= '0';
          end if;


        end if;
      end if;
    end process;

  end generate gen3;

  p_regs : process(clk_sys_i)
    variable cnt_idx : integer range 0 to g_num_clocks;
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        regs_in.cnt_val_valid_i <= '0';

      else
        cnt_idx                 := to_integer(unsigned(regs_out.cnt_sel_sel_o));
        regs_in.cnt_val_value_i <= std_logic_vector(clks(cnt_idx).freq);
        regs_in.cnt_val_valid_i <= clks(cnt_idx).valid_sreg(1);
      end if;
    end if;
  end process;




end rtl;
