------------------------------------------------------------------------------
-- Title      : Wishbone Vectored Interrupt Controller
-- Project    : White Rabbit Switch
------------------------------------------------------------------------------
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-05-18
-- Last update: 2015-11-19
-- Platform   : FPGA-generic
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Simple interrupt controller/multiplexer:
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
-------------------------------------------------------------------------------
-- Copyright (c) 2010 CERN
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
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2010-05-18  1.0      twlostow        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;

entity wb_vic is
  
  generic (
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD;

    -- number of IRQ inputs.
    g_num_interrupts : natural                  := 32;
    -- initial values for the vector addresses. 
    g_init_vectors   : t_wishbone_address_array := cc_dummy_address_array;

    g_retry_timeout : integer := 0
    );

  port (
    clk_sys_i : in std_logic;           -- wishbone clock
    rst_n_i   : in std_logic;           -- reset

    wb_adr_i   : in  std_logic_vector(c_wishbone_address_width-1 downto 0);
    wb_dat_i   : in  std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_dat_o   : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_cyc_i   : in  std_logic;
    wb_sel_i   : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0);
    wb_stb_i   : in  std_logic;
    wb_we_i    : in  std_logic;
    wb_ack_o   : out std_logic;
    wb_stall_o : out std_logic;

    irqs_i       : in  std_logic_vector(g_num_interrupts-1 downto 0);  -- IRQ inputs
    irq_master_o : out std_logic  -- master IRQ output (multiplexed line, to the CPU)

    );

end wb_vic;


architecture syn of wb_vic is

  component vic_prio_enc
    port (
      in_i  : in  std_logic_vector(31 downto 0);
      out_o : out std_logic_vector(4 downto 0));
  end component;

  component wb_slave_vic
    port (
      rst_n_i            : in  std_logic;
      clk_sys_i          : in  std_logic;
      wb_adr_i           : in  std_logic_vector(5 downto 0);
      wb_dat_i           : in  std_logic_vector(31 downto 0);
      wb_dat_o           : out std_logic_vector(31 downto 0);
      wb_cyc_i           : in  std_logic;
      wb_sel_i           : in  std_logic_vector(3 downto 0);
      wb_stb_i           : in  std_logic;
      wb_we_i            : in  std_logic;
      wb_ack_o           : out std_logic;
      wb_stall_o         : out std_logic;
      vic_ctl_enable_o   : out std_logic;
      vic_ctl_pol_o      : out std_logic;
      vic_ctl_emu_edge_o : out std_logic;
      vic_ctl_emu_len_o  : out std_logic_vector(15 downto 0);
      vic_risr_i         : in  std_logic_vector(31 downto 0);
      vic_ier_o          : out std_logic_vector(31 downto 0);
      vic_ier_wr_o       : out std_logic;
      vic_idr_o          : out std_logic_vector(31 downto 0);
      vic_idr_wr_o       : out std_logic;
      vic_imr_i          : in  std_logic_vector(31 downto 0);
      vic_var_i          : in  std_logic_vector(31 downto 0);
      vic_swir_o         : out std_logic_vector(31 downto 0);
      vic_swir_wr_o      : out std_logic;
      vic_eoir_o         : out std_logic_vector(31 downto 0);
      vic_eoir_wr_o      : out std_logic;
      vic_ivt_ram_addr_o : out std_logic_vector(4 downto 0);
      vic_ivt_ram_data_i : in  std_logic_vector(31 downto 0);
      vic_ivt_ram_data_o : out std_logic_vector(31 downto 0);
      vic_ivt_ram_wr_o   : out std_logic
      );

  end component;

  function f_resize_addr_array(a : t_wishbone_address_array; size : integer) return t_wishbone_address_array is
    variable rv : t_wishbone_address_array(0 to size-1);
  begin

    for i in 0 to a'length-1 loop
      rv(i) := a(i);
    end loop;  -- i

    for i in a'length to size-1 loop
      rv(i) := (others => '0');
    end loop;  -- i

    return rv;
  end f_resize_addr_array;



  type t_state is (WAIT_IRQ, PROCESS_IRQ, WAIT_ACK, WAIT_MEM, WAIT_IDLE, RETRY);

  signal irqs_i_reg : std_logic_vector(32 downto 0);

  signal vic_ctl_enable   : std_logic;
  signal vic_ctl_pol      : std_logic;
  signal vic_ctl_emu_edge : std_logic;
  signal vic_ctl_emu_len  : std_logic_vector(15 downto 0);

  signal vic_risr    : std_logic_vector(31 downto 0);
  signal vic_ier     : std_logic_vector(31 downto 0);
  signal vic_ier_wr  : std_logic;
  signal vic_idr     : std_logic_vector(31 downto 0);
  signal vic_idr_wr  : std_logic;
  signal vic_imr     : std_logic_vector(31 downto 0);
  signal vic_var     : std_logic_vector(31 downto 0);
  signal vic_eoir    : std_logic_vector(31 downto 0);
  signal vic_eoir_wr : std_logic;

  signal vic_ivt_ram_addr_wb     : std_logic_vector(4 downto 0);
  signal vic_ivt_ram_addr_int    : std_logic_vector(4 downto 0);
  signal vic_ivt_ram_data_towb   : std_logic_vector(31 downto 0);
  signal vic_ivt_ram_data_fromwb : std_logic_vector(31 downto 0);
  signal vic_ivt_ram_data_int    : std_logic_vector(31 downto 0);
  signal vic_ivt_ram_wr          : std_logic;

  signal vic_swir    : std_logic_vector(31 downto 0);
  signal vic_swir_wr : std_logic;

  signal got_irq  : std_logic;
  signal swi_mask : std_logic_vector(31 downto 0);

  signal current_irq    : std_logic_vector(4 downto 0);
  signal irq_id_encoded : std_logic_vector(4 downto 0);
  signal state          : t_state;

  signal wb_in  : t_wishbone_slave_in;
  signal wb_out : t_wishbone_slave_out;

  signal timeout_count : unsigned(15 downto 0);

  signal vector_table : t_wishbone_address_array(0 to 31) := f_resize_addr_array(g_init_vectors, 32);
  
begin  -- syn

  check1 : if (g_num_interrupts < 2 or g_num_interrupts > 32) generate
    assert true report "invalid number of interrupts" severity failure;
  end generate check1;


  p_vector_table_host : process(clk_sys_i)
    variable sanitized_addr : integer;
  begin
    if rising_edge(clk_sys_i) then

      sanitized_addr := to_integer(unsigned(vic_ivt_ram_addr_wb));

      vic_ivt_ram_data_towb <= vector_table(sanitized_addr);
      if(vic_ivt_ram_wr = '1') then
        vector_table(sanitized_addr) <= vic_ivt_ram_data_fromwb;
      end if;
    end if;
  end process;

  p_vector_table_int : process(clk_sys_i)
    variable sanitized_addr : integer;
  begin
    if rising_edge(clk_sys_i) then
      sanitized_addr   := to_integer(unsigned(vic_ivt_ram_addr_int));
      vic_ivt_ram_data_int <= vector_table(sanitized_addr);
    end if;
  end process;


  p_register_irq_lines : process(clk_sys_i, rst_n_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        irqs_i_reg <= (others => '0');
      else
        
        irqs_i_reg(g_num_interrupts-1 downto 0) <= (irqs_i or swi_mask(g_num_interrupts-1 downto 0)) and vic_imr(g_num_interrupts-1 downto 0);

        irqs_i_reg(32 downto g_num_interrupts) <= (others => '0');
      end if;
    end if;
  end process;


  vic_risr <= irqs_i_reg(31 downto 0);

  priority_encoder : vic_prio_enc
    port map (
      in_i  => irqs_i_reg(31 downto 0),
      out_o => irq_id_encoded);

  vic_ivt_ram_addr_int <= current_irq;

  U_Slave_adapter : wb_slave_adapter
    generic map (
      g_master_use_struct  => true,
      g_master_mode        => PIPELINED,
      g_master_granularity => WORD,
      g_slave_use_struct   => false,
      g_slave_mode         => g_interface_mode,
      g_slave_granularity  => g_address_granularity)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      sl_adr_i   => wb_adr_i,
      sl_dat_i   => wb_dat_i,
      sl_sel_i   => wb_sel_i,
      sl_cyc_i   => wb_cyc_i,
      sl_stb_i   => wb_stb_i,
      sl_we_i    => wb_we_i,
      sl_dat_o   => wb_dat_o,
      sl_ack_o   => wb_ack_o,
      sl_stall_o => wb_stall_o,
      master_i   => wb_out,
      master_o   => wb_in);

  wb_out.rty <= '0';
  wb_out.err <= '0';
  wb_out.int <= '0';


  U_wb_controller : wb_slave_vic
    port map (
      rst_n_i    => rst_n_i,
      clk_sys_i  => clk_sys_i,
      wb_adr_i   => wb_in.adr(5 downto 0),
      wb_dat_i   => wb_in.dat,
      wb_dat_o   => wb_out.dat,
      wb_cyc_i   => wb_in.cyc,
      wb_sel_i   => wb_in.sel,
      wb_stb_i   => wb_in.stb,
      wb_we_i    => wb_in.we,
      wb_ack_o   => wb_out.ack,
      wb_stall_o => wb_out.stall,

      vic_ctl_enable_o   => vic_ctl_enable,
      vic_ctl_pol_o      => vic_ctl_pol,
      vic_ctl_emu_edge_o => vic_ctl_emu_edge,
      vic_ctl_emu_len_o  => vic_ctl_emu_len,
      vic_risr_i         => vic_risr,
      vic_ier_o          => vic_ier,
      vic_ier_wr_o       => vic_ier_wr,
      vic_idr_o          => vic_idr,
      vic_idr_wr_o       => vic_idr_wr,
      vic_imr_i          => vic_imr,
      vic_var_i          => vic_var,
      vic_eoir_o         => vic_eoir,
      vic_eoir_wr_o      => vic_eoir_wr,
      vic_swir_o         => vic_swir,
      vic_swir_wr_o      => vic_swir_wr,
      vic_ivt_ram_addr_o => vic_ivt_ram_addr_wb,
      vic_ivt_ram_data_i => vic_ivt_ram_data_towb,
      vic_ivt_ram_data_o => vic_ivt_ram_data_fromwb,
      vic_ivt_ram_wr_o   => vic_ivt_ram_wr);

  process (clk_sys_i, rst_n_i)
  begin  -- process enable_disable_irqs
    if rising_edge(clk_sys_i) then
      
      if rst_n_i = '0' then             -- asynchronous reset (active low)
        vic_imr <= (others => '0');
      else
        
        if(vic_ier_wr = '1') then
          for i in 0 to g_num_interrupts-1 loop
            if(vic_ier(i) = '1') then
              vic_imr(i) <= '1';
            end if;
          end loop;  -- i
        end if;

        if(vic_idr_wr = '1') then
          for i in 0 to g_num_interrupts-1 loop
            if(vic_idr(i) = '1') then
              vic_imr(i) <= '0';
            end if;
          end loop;  -- i
        end if;
        
      end if;
    end if;
  end process;

  vic_fsm : process (clk_sys_i, rst_n_i)
  begin  -- process vic_fsm
    if rising_edge(clk_sys_i) then
      
      if rst_n_i = '0' then             -- asynchronous reset (active low)
        state        <= WAIT_IRQ;
        current_irq  <= (others => '0');
        irq_master_o <= '0';
        vic_var      <= x"12345678";
        swi_mask     <= (others => '0');
        
      else
        if(vic_ctl_enable = '0') then
          irq_master_o <= not vic_ctl_pol;
          current_irq  <= (others => '0');
          state        <= WAIT_IRQ;
          vic_var      <= x"12345678";
          swi_mask     <= (others => '0');
        else

          if(vic_swir_wr = '1') then    -- handle the software IRQs
            swi_mask <= vic_swir;
          end if;

          case state is
            when WAIT_IRQ =>
              if(irqs_i_reg /= std_logic_vector(to_unsigned(0, irqs_i_reg'length))) then
                current_irq <= irq_id_encoded;
                state       <= WAIT_MEM;

-- assert the master IRQ line
              else
-- no interrupts? de-assert the IRQ line 
                irq_master_o <= not vic_ctl_pol;
                vic_var      <= (others => '0');
              end if;

            when WAIT_MEM =>
              state <= PROCESS_IRQ;
              
            when PROCESS_IRQ =>
-- fetch the vector address from vector table and load it into VIC_VAR register
              vic_var      <= vic_ivt_ram_data_int;
              state        <= WAIT_ACK;
              irq_master_o <= vic_ctl_pol;
              timeout_count <= (others => '0');

            when WAIT_ACK =>
-- got write operation to VIC_EOIR register? if yes, advance to next interrupt.

              if(vic_eoir_wr = '1') then
                state    <= WAIT_IDLE;
                swi_mask <= (others => '0');
                timeout_count <= (others => '0');
              elsif (g_retry_timeout /= 0 and timeout_count = g_retry_timeout) then
                timeout_count <= (others => '0');
                state <= RETRY;
                irq_master_o <= not vic_ctl_pol;
              else
                timeout_count <= timeout_count + 1;
              end if;

            when RETRY =>
                if(timeout_count = 100) then
                  irq_master_o <= vic_ctl_pol;
                  state <= WAIT_ACK;
                  timeout_count <= (others => '0');
                  else
                timeout_count <= timeout_count + 1;
                    
                end if;
                  

            when WAIT_IDLE =>
              if(vic_ctl_emu_edge = '0') then
                state <= WAIT_IRQ;
              else
                irq_master_o  <= not vic_ctl_pol;
                timeout_count <= timeout_count + 1;
                if(timeout_count = unsigned(vic_ctl_emu_len)) then
                  state <= WAIT_IRQ;
                end if;
                
              end if;
          end case;
        end if;
      end if;
    end if;
  end process vic_fsm;


end syn;
