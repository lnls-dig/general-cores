--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://gitlab.com/ohwr/project/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   wb_vic
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
use work.genram_pkg.all;

entity wb_vic is
  
  generic (
    g_INTERFACE_MODE      : t_wishbone_interface_mode      := CLASSIC;
    g_ADDRESS_GRANULARITY : t_wishbone_address_granularity := WORD;

    -- number of IRQ inputs.
    g_NUM_INTERRUPTS : natural range 2 to 32 := 32;
    -- initial values for the vector addresses. 
    g_INIT_VECTORS   : t_wishbone_address_array := cc_dummy_address_array;

    -- If True, the polarity is fixed and set by g_POLARITY
    g_FIXED_POLARITY : boolean := False;
    g_POLARITY       : std_logic := '1';

    g_RETRY_TIMEOUT : natural := 0
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

  signal irqs_i_reg : std_logic_vector(g_NUM_INTERRUPTS - 1 downto 0);

  signal vic_ctl_pol      : std_logic;
  signal vic_ctl_pol_in    : std_logic;
  signal vic_ctl_wr        : std_logic;

  signal vic_ctl_enable    : std_logic;
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
  signal vic_ivt_ram_data_towb   : std_logic_vector(31 downto 0);
  signal vic_ivt_ram_data_fromwb : std_logic_vector(31 downto 0);
  signal vic_ivt_ram_data_int    : std_logic_vector(31 downto 0);
  signal vic_ivt_ram_wr          : std_logic;

  signal vic_swir    : std_logic_vector(31 downto 0);
  signal vic_swir_wr : std_logic;

  signal swi_mask : std_logic_vector(31 downto 0);

  signal current_irq    : natural range 0 to 31;
  signal state          : t_state;

  signal wb_in  : t_wishbone_slave_in;
  signal wb_out : t_wishbone_slave_out;

  signal timeout_count : unsigned(15 downto 0);

  signal vector_table : t_wishbone_address_array(0 to 31) := f_resize_addr_array(g_init_vectors, 32);
  
  constant c_valid_irq_mask : std_logic_vector(31 downto 0) :=
    (31 downto g_NUM_INTERRUPTS => '0') & (g_NUM_INTERRUPTS - 1 downto 0 => '1');
begin  -- syn

  --  Read and write vector table (from the bus)
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

  --  Read the vector for the current interrupt.
  p_vector_table_int : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      vic_ivt_ram_data_int <= vector_table(current_irq);
    end if;
  end process;

  p_register_irq_lines : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        irqs_i_reg <= (others => '0');
      else
        irqs_i_reg <= (irqs_i or swi_mask(g_NUM_INTERRUPTS-1 downto 0)) and vic_imr(g_NUM_INTERRUPTS-1 downto 0);
      end if;
    end if;
  end process;

  vic_risr <= (31 downto g_NUM_INTERRUPTS => '0') & (irqs_i or swi_mask(g_NUM_INTERRUPTS-1 downto 0));

  U_Slave_adapter : entity work.wb_slave_adapter
    generic map (
      g_master_use_struct  => true,
      g_master_mode        => PIPELINED,
      g_master_granularity => WORD,
      g_slave_use_struct   => false,
      g_slave_mode         => g_INTERFACE_MODE,
      g_slave_granularity  => g_ADDRESS_GRANULARITY)
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


  U_wb_controller : entity work.wb_vic_regs
    port map (
      rst_n_i    => rst_n_i,
      clk_i      => clk_sys_i,
      wb_adr_i   => wb_in.adr(5 downto 0),
      wb_dat_i   => wb_in.dat,
      wb_dat_o   => wb_out.dat,
      wb_cyc_i   => wb_in.cyc,
      wb_sel_i   => wb_in.sel,
      wb_stb_i   => wb_in.stb,
      wb_we_i    => wb_in.we,
      wb_ack_o   => wb_out.ack,
      wb_stall_o => wb_out.stall,

      ctl_enable_o   => vic_ctl_enable,
      ctl_pol_o      => vic_ctl_pol_in,
      ctl_pol_i      => vic_ctl_pol,
      ctl_emu_edge_o => vic_ctl_emu_edge,
      ctl_emu_len_o  => vic_ctl_emu_len,
      ctl_wr_o       => vic_ctl_wr,
      risr_i         => vic_risr,
      ier_o          => vic_ier,
      ier_wr_o       => vic_ier_wr,
      idr_o          => vic_idr,
      idr_wr_o       => vic_idr_wr,
      imr_i          => vic_imr,
      var_i          => vic_var,
      eoir_o         => vic_eoir,
      eoir_wr_o      => vic_eoir_wr,
      swir_o         => vic_swir,
      swir_wr_o      => vic_swir_wr,
      ivt_ram_addr_o => vic_ivt_ram_addr_wb,
      ivt_ram_data_i => vic_ivt_ram_data_towb,
      ivt_ram_data_o => vic_ivt_ram_data_fromwb,
      ivt_ram_wr_o   => vic_ivt_ram_wr);

  gen_pol: if not g_FIXED_POLARITY generate
    --  The polarity register
    process (clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          vic_ctl_pol <= '0';
        else
          if vic_ctl_wr = '1' then
            vic_ctl_pol <= vic_ctl_pol_in;
          end if;
        end if;
      end if;
    end process;
  end generate;
  
  gen_fixed_pol: if g_FIXED_POLARITY generate
    vic_ctl_pol <= g_POLARITY;
  end generate;
    
  p_vic_imr: process (clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        vic_imr <= (others => '0');
      else
        if vic_ier_wr = '1' then
          vic_imr <= vic_imr or (vic_ier and c_valid_irq_mask);
        end if;

        if vic_idr_wr = '1' then
          vic_imr <= vic_imr and not vic_idr;
        end if;
      end if;
    end if;
  end process;

  vic_fsm : process (clk_sys_i, rst_n_i)
  begin  -- process vic_fsm
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        state        <= WAIT_IRQ;
        current_irq  <= 0;
        irq_master_o <= '0';
        vic_var      <= x"12345678";
        swi_mask     <= (others => '0');
        
      else
        if(vic_ctl_enable = '0') then
          irq_master_o <= not vic_ctl_pol;
          current_irq  <= 0;
          state        <= WAIT_IRQ;
          vic_var      <= x"12345678";
          swi_mask     <= (others => '0');
        else

          if(vic_swir_wr = '1') then    -- handle the software IRQs
            swi_mask <= vic_swir;
          end if;

          case state is
            when WAIT_IRQ =>
              if irqs_i_reg /= (irqs_i_reg'range => '0') then
                current_irq <= 0;
                for i in 0 to g_NUM_INTERRUPTS - 1 loop
                  if irqs_i_reg (i) = '1' then
                    current_irq <= i;
                    exit;
                  end if;
                end loop;
                state  <= WAIT_MEM;
              else
                -- no interrupts? de-assert the IRQ line 
                irq_master_o <= not vic_ctl_pol;
                vic_var      <= (others => '0');
              end if;

            when WAIT_MEM =>
              state <= PROCESS_IRQ;
              
            when PROCESS_IRQ =>
              -- fetch the vector address from vector table and
              -- load it into VIC_VAR register
              vic_var       <= vic_ivt_ram_data_int;
              irq_master_o  <= vic_ctl_pol;
              timeout_count <= (others => '0');
              state         <= WAIT_ACK;

            when WAIT_ACK =>
              -- got write operation to VIC_EOIR register? if yes,
              -- advance to next interrupt.
              if vic_eoir_wr = '1' then
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
