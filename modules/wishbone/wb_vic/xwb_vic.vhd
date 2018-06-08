--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_vic
--
-- description: Simple interrupt controller/multiplexer:
-- - designed to cooperate with wbgen2 peripherals Embedded Interrupt
--   Controllers (EICs)
-- - accepts 2 to 32 inputs (configurable using g_num_interrupts)
-- - inputs are high-level sensitive
-- - inputs have fixed priorities. Input 0 has the highest priority, Input
--   g_num_interrupts-1 has the lowest priority.
-- - output interrupt line (to the CPU) is active low or high depending on
--   a configuration bit.
-- - interrupt is acknowledged by writing to EIC_EOIR register.
-- - register layout: see wb_vic.wb for details.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2010-2018
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

library work;
use work.wishbone_pkg.all;

entity xwb_vic is
  
  generic (
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD;

    g_num_interrupts : natural                  := 32;  -- number of IRQ inputs.
    g_init_vectors   : t_wishbone_address_array := cc_dummy_address_array;

    g_retry_timeout : integer := 0
    );

  port (
    clk_sys_i : in std_logic;           -- wishbone clock
    rst_n_i   : in std_logic;           -- reset

    slave_i : in  t_wishbone_slave_in;
    slave_o : out t_wishbone_slave_out;

    irqs_i       : in  std_logic_vector(g_num_interrupts-1 downto 0);  -- IRQ inputs
    irq_master_o : out std_logic  -- master IRQ output (multiplexed line, to the CPU)

    );

end xwb_vic;

architecture wrapper of xwb_vic is

begin  -- wrapper

  U_Wrapped_VIC : wb_vic
    generic map (
      g_interface_mode      => g_interface_mode,
      g_address_granularity => g_address_granularity,
      g_num_interrupts      => g_num_interrupts,
      g_init_vectors        => g_init_vectors,
      g_retry_timeout => g_retry_timeout)
    port map (
      clk_sys_i    => clk_sys_i,
      rst_n_i      => rst_n_i,
      wb_adr_i     => slave_i.adr,
      wb_dat_i     => slave_i.dat,
      wb_dat_o     => slave_o.dat,
      wb_cyc_i     => slave_i.Cyc,
      wb_sel_i     => slave_i.sel,
      wb_stb_i     => slave_i.stb,
      wb_we_i      => slave_i.we,
      wb_ack_o     => slave_o.ack,
      wb_stall_o   => slave_o.stall,
      irqs_i       => irqs_i,
      irq_master_o => irq_master_o);

  slave_o.err <= '0';
  slave_o.rty <= '0';
  
end wrapper;
