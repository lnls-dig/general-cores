-------------------------------------------------------------------------------
-- Title        : Xilinx FPGA Loader
-- Project      : General Cores Library
-------------------------------------------------------------------------------
-- File         : wb_xilinx_fpga_loader.vhd
-- Author       : Tomasz Włostowski
-- Company      : CERN BE-CO-HT
-- Created      : 2012-01-30
-- Last update  : 2012-01-30
-- Platform     : FPGA-generic
-- Standard     : VHDL '93
-- Dependencies : xldr_wbgen2_pkg, gencores_pkg, wbgen2_pkg, gc_sync_ffs
--                xloader_wb, wb_slave_adapter, wishbone_pkg
-------------------------------------------------------------------------------
-- Description: Wishbone compatible Xilinx serial port bitstream loader.
-- Host initiates boot sequence by writing 1 to CSR.START register. Afterwards,
-- it copies the bitstream to FIFO register. End of configuration is indicated
-- by CSR.DONE bit (CSR.ERROR = FPGA DONE signal timeout). The actual startup
-- of the FPGA is triggered by writing 1 to CSR.EXIT bit after loading the
-- bitstream.
-- The core also provides a boot sequence detector useful for bootloader
-- applications which passively monitor the host bus until a certain "magic"
-- sequence is found, which activates the bootloader mode.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2012 CERN
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
-- 2012-01-30  1.0      twlostow        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.STD_LOGIC_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;
use work.wishbone_pkg.all;
use work.xldr_wbgen2_pkg.all;

entity wb_xilinx_fpga_loader is
  generic(
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD;
    g_idr_value           : std_logic_vector(31 downto 0)  := x"626f6f74"
    );
  port (
-- system clock
    clk_sys_i : in std_logic;
-- synchronous reset, active LOW
    rst_n_i   : in std_logic;

-- Wishbone bus
    wb_cyc_i   : in  std_logic;
    wb_stb_i   : in  std_logic;
    wb_we_i    : in  std_logic;
    wb_adr_i   : in  std_logic_vector(c_wishbone_address_width - 1 downto 0);
    wb_sel_i   : in  std_logic_vector((c_wishbone_data_width + 7) / 8 - 1 downto 0);
    wb_dat_i   : in  std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_dat_o   : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_ack_o   : out std_logic;
    wb_stall_o : out std_logic;

-- Configuration clock (to pin CCLK)
    xlx_cclk_o      : out std_logic := '0';
-- Data output (to pin D0/DIN)
    xlx_din_o       : out std_logic;
-- Program enable pin (active low, to pin PROG_B)
    xlx_program_b_o : out std_logic := '1';
-- Init ready pin (active low, to pin INIT_B)
    xlx_init_b_i    : in  std_logic;
-- Configuration done pin (to pin DONE)
    xlx_done_i      : in  std_logic;
-- FPGA suspend pin
    xlx_suspend_o   : out std_logic;

-- FPGA mode select pin. Connect to M1..M0 pins of the FPGA or leave open if
-- the pins are hardwired on the PCB
    xlx_m_o : out std_logic_vector(1 downto 0);

-- Trigger sequence detector output:
-- 1-pulse: boot trigger sequence detected
    boot_trig_p1_o : out std_logic := '0';

-- Exit bootloader mode, 1-pulse on write 1 to CSR.EXIT
    boot_exit_p1_o : out std_logic := '0';

-- Bootloader enable. When disabled, all WB writes except for the trigger register are
-- ignored.
    boot_en_i : in std_logic;

-- User-available IO (GPIOR register contents)
    gpio_o : out std_logic_vector(7 downto 0)
    );

end wb_xilinx_fpga_loader;

architecture behavioral of wb_xilinx_fpga_loader is

  component xloader_wb
    port (
      rst_n_i    : in  std_logic;
      clk_sys_i  : in  std_logic;
      wb_adr_i   : in  std_logic_vector(2 downto 0);
      wb_dat_i   : in  std_logic_vector(31 downto 0);
      wb_dat_o   : out std_logic_vector(31 downto 0);
      wb_cyc_i   : in  std_logic;
      wb_sel_i   : in  std_logic_vector(3 downto 0);
      wb_stb_i   : in  std_logic;
      wb_we_i    : in  std_logic;
      wb_ack_o   : out std_logic;
      wb_stall_o : out std_logic;
      regs_i     : in  t_xldr_in_registers;
      regs_o     : out t_xldr_out_registers);
  end component;

  type t_bootseq_state is (TWORD0, TWORD1, TWORD2, TWORD3, TWORD4, TWORD5, TWORD6, TWORD7, BOOT_READY);

  type t_xloader_state is (IDLE, WAIT_INIT, WAIT_INIT2, READ_FIFO, READ_FIFO2, OUTPUT_BIT, CLOCK_EDGE, WAIT_DONE, EXTEND_PROG, STARTUP_CCLK0, STARTUP_CCLK1, GOT_DONE);

  signal state           : t_xloader_state;
  signal clk_div         : unsigned(6 downto 0);
  signal tick            : std_logic;
  signal init_b_synced   : std_logic;
  signal done_synced     : std_logic;
  signal timeout_counter : unsigned(20 downto 0);
  signal wb_in           : t_wishbone_master_out;
  signal wb_out          : t_wishbone_master_in;
  signal regs_in         : t_xldr_out_registers;
  signal regs_out        : t_xldr_in_registers;

  -- PROG_B assertion duration
  constant c_MIN_PROG_DELAY : unsigned(timeout_counter'left downto 0) := to_unsigned(1000, timeout_counter'length);


  -- PROG_B active to INIT_B active timeout
  constant c_INIT_TIMEOUT : unsigned(timeout_counter'left downto 0) := to_unsigned(200000, timeout_counter'length);

  -- Last word written to DONE active timeout
  constant c_DONE_TIMEOUT : unsigned(timeout_counter'left downto 0) := to_unsigned(200000, timeout_counter'length);

  -- Number of CCLK cycles after assertion of DONE required to start up the FPGA.
  constant c_STARTUP_CYCLES : integer := 1024;

  signal d_data : std_logic_vector(31 downto 0);
  signal d_size : std_logic_vector(1 downto 0);
  signal d_last : std_logic;

  signal bit_counter : unsigned(4 downto 0);
  signal boot_state  : t_bootseq_state;

  procedure f_bootseq_step(signal st : out t_bootseq_state; nstate : t_bootseq_state; match_val : std_logic_vector; regs : t_xldr_out_registers) is
  begin
    if(regs.btrigr_wr_o = '1') then
      if(regs.btrigr_o = match_val) then
        st <= nstate;
      else
        st <= TWORD0;
      end if;
    end if;
  end f_bootseq_step;

  signal startup_count : unsigned(20 downto 0);

  
  
begin  -- behavioral


-- Pipelined-classic adapter/converter
  U_Adapter : wb_slave_adapter
    generic map (
      g_master_use_struct  => true,
      g_master_mode        => CLASSIC,
      g_master_granularity => WORD,
      g_slave_use_struct   => false,
      g_slave_mode         => g_interface_mode,
      g_slave_granularity  => g_address_granularity)
    port map (
      clk_sys_i => clk_sys_i,
      rst_n_i   => rst_n_i,

      sl_cyc_i   => wb_cyc_i,
      sl_stb_i   => wb_stb_i,
      sl_we_i    => wb_we_i,
      sl_adr_i   => wb_adr_i,
      sl_sel_i   => wb_sel_i,
      sl_dat_i   => wb_dat_i,
      sl_dat_o   => wb_dat_o,
      sl_ack_o   => wb_ack_o,
      sl_stall_o => wb_stall_o,

      master_i => wb_out,
      master_o => wb_in);

  wb_out.err   <= '0';
  wb_out.rty   <= '0';
  wb_out.stall <= '0';
  wb_out.int   <= '0';

  xlx_m_o <= "11";                      -- permamently select Passive serial
                                        -- boot mode

  xlx_suspend_o <= '0';                 -- suspend feature is not used

-- Synchronization chains for async INIT_B and DONE inputs
  U_Sync_INIT : gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_n_i,
      data_i   => xlx_init_b_i,
      synced_o => init_b_synced);

  U_Sync_DONE : gc_sync_ffs
    generic map (
      g_sync_edge => "positive")
    port map (
      clk_i    => clk_sys_i,
      rst_n_i  => rst_n_i,
      data_i   => xlx_done_i,
      synced_o => done_synced);

  -- Clock divider. Genrates a single-cycle pulse on "tick" signal every
  -- CSR.CLKDIV system clock cycles.
  p_divide_clock : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        clk_div <= (others => '0');
        tick    <= '0';
      else
        if(clk_div = unsigned(regs_in.csr_clkdiv_o)) then
          tick    <= '1';
          clk_div <= (others => '0');
        else
          tick    <= '0';
          clk_div <= clk_div + 1;
        end if;
      end if;
    end if;
  end process;


  p_main_fsm : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' or regs_in.csr_swrst_o = '1' then
        state           <= IDLE;
        xlx_program_b_o <= '1';
        xlx_cclk_o      <= '0';
        xlx_din_o       <= '0';
        timeout_counter <= (others => '0');

        regs_out.csr_done_i  <= '0';
        regs_out.csr_error_i <= '0';
      else
        case state is
          when IDLE =>
            
            timeout_counter <= c_INIT_TIMEOUT;
            if(regs_in.csr_start_o = '1' and boot_en_i = '1') then
              xlx_program_b_o      <= '0';
              regs_out.csr_done_i  <= '0';
              regs_out.csr_error_i <= '0';
              state                <= EXTEND_PROG;
              timeout_counter      <= c_MIN_PROG_DELAY;
            end if;

          when EXTEND_PROG =>
            timeout_counter <= timeout_counter-1;

            if(timeout_counter = 0) then
              timeout_counter <= c_INIT_TIMEOUT;
              state           <= WAIT_INIT;
            end if;
            
          when WAIT_INIT =>
            timeout_counter <= timeout_counter - 1;

            if(timeout_counter = 0) then
              regs_out.csr_error_i <= '1';
              regs_out.csr_done_i  <= '1';
              state                <= IDLE;
            end if;

            if (init_b_synced = '0') then
              state           <= WAIT_INIT2;
              xlx_program_b_o <= '1';
            end if;

          when WAIT_INIT2 =>
            if (init_b_synced /= '0') then
              state <= READ_FIFO;
            end if;

          when READ_FIFO =>
            xlx_cclk_o <= '0';

            if(regs_in.fifo_rd_empty_o = '0') then
              state <= READ_FIFO2;
            end if;

          when READ_FIFO2 =>


            -- handle byte swapping
            if(regs_in.csr_msbf_o = '0') then
              d_data(31 downto 24) <= regs_in.fifo_xdata_o(7 downto 0);
              d_data(23 downto 16) <= regs_in.fifo_xdata_o(15 downto 8);
              d_data(15 downto 8)  <= regs_in.fifo_xdata_o(23 downto 16);
              d_data(7 downto 0)   <= regs_in.fifo_xdata_o(31 downto 24);  -- little-endian
            else
              d_data <= regs_in.fifo_xdata_o;  -- big-endian
            end if;

            d_size <= regs_in.fifo_xsize_o;
            d_last <= regs_in.fifo_xlast_o;

            if(tick = '1') then
              state       <= OUTPUT_BIT;
              bit_counter <= unsigned(regs_in.fifo_xsize_o) & "111";
            end if;

          when OUTPUT_BIT =>
            if(tick = '1') then
              xlx_din_o                    <= d_data(31);
              xlx_cclk_o                   <= '0';
              d_data(d_data'left downto 1) <= d_data(d_data'left-1 downto 0);
              if(xlx_done_i = '1') then
                state <= GOT_DONE;
              else
                state <= CLOCK_EDGE;
              end if;
              
            end if;
            
          when CLOCK_EDGE =>
            if(tick = '1') then
              xlx_cclk_o <= '1';

              bit_counter <= bit_counter - 1;

              if(bit_counter = 0) then
                if(d_last = '1') then
                  state           <= WAIT_DONE;
                  timeout_counter <= c_DONE_TIMEOUT;
                else
                  state <= READ_FIFO;
                end if;
              else
                state <= OUTPUT_BIT;
              end if;
            end if;

          when WAIT_DONE =>
            if(done_synced = '1') then
              state                <= IDLE;
              regs_out.csr_done_i  <= '1';
              regs_out.csr_error_i <= '0';
            end if;

            timeout_counter <= timeout_counter - 1;
            if(timeout_counter = 0) then
              state                <= IDLE;
              regs_out.csr_error_i <= '1';
              regs_out.csr_done_i  <= '1';
            end if;

-- DONE pin has just been asserted high. Stop loading the bitstream and wait
-- for EXIT command.
            
          when GOT_DONE =>
            regs_out.csr_done_i  <= '1';
            regs_out.csr_error_i <= '0';
            if(regs_in.csr_exit_o = '1') then
              state         <= STARTUP_CCLK0;
              startup_count <= (others => '0');
            end if;

-- After receiving EXIT command, pulse CCLK for several cycles to initiate the
-- FPGA startup. This is to ensure the freshly configured FPGA keeps all its
-- pins in hi-z mode until the host bootloader is done (for example in VME
-- carriers, where a small FPGA, implementing the bootloader shares the VME bus
-- with the main FPGA.
          when STARTUP_CCLK0 =>
            xlx_din_o <= '0';
            if(tick = '1') then
              xlx_cclk_o <= '0';
              state      <= STARTUP_CCLK1;
            end if;

          when STARTUP_CCLK1 =>

            if(tick = '1') then
              xlx_cclk_o <= '1';
              if(startup_count = c_STARTUP_CYCLES) then
                state <= IDLE;
              else
                state <= STARTUP_CCLK0;
              end if;

              startup_count <= startup_count + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

  -- Bootloader trigger sequence detection.
  -- Write of 0xde, 0xad, 0xbe, 0xef, 0xca, 0xfe, 0xba, 0xbe to BTRIGR
  -- produces a pulse on boot_trig_p1_o.
  p_detect_boot_trigger : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        boot_trig_p1_o <= '0';
        boot_state     <= TWORD0;
      else
        case boot_state is
          when TWORD0 =>
            boot_trig_p1_o <= '0';
            f_bootseq_step(boot_state, TWORD1, x"de", regs_in);
          when TWORD1     => f_bootseq_step(boot_state, TWORD2, x"ad", regs_in);
          when TWORD2     => f_bootseq_step(boot_state, TWORD3, x"be", regs_in);
          when TWORD3     => f_bootseq_step(boot_state, TWORD4, x"ef", regs_in);
          when TWORD4     => f_bootseq_step(boot_state, TWORD5, x"ca", regs_in);
          when TWORD5     => f_bootseq_step(boot_state, TWORD6, x"fe", regs_in);
          when TWORD6     => f_bootseq_step(boot_state, TWORD7, x"ba", regs_in);
          when TWORD7     => f_bootseq_step(boot_state, BOOT_READY, x"be", regs_in);
          when BOOT_READY =>
            boot_trig_p1_o <= '1';
            boot_state     <= TWORD0;
        end case;
      end if;
    end if;
  end process;

  gpio_o         <= regs_in.gpior_o;
  boot_exit_p1_o <= regs_in.csr_exit_o;

  regs_out.csr_busy_i    <= '0' when (state = IDLE)                                                            else '1';
  regs_out.fifo_rd_req_i <= '1' when ((regs_in.fifo_rd_empty_o = '0') and (state = IDLE or state = READ_FIFO)) else '0';

  regs_out.idr_i <= g_idr_value;

  U_WB_SLAVE : xloader_wb
    port map (
      rst_n_i   => rst_n_i,
      clk_sys_i => clk_sys_i,
      wb_adr_i  => wb_in.adr(2 downto 0),
      wb_dat_i  => wb_in.dat(31 downto 0),
      wb_dat_o  => wb_out.dat(31 downto 0),
      wb_cyc_i  => wb_in.cyc,
      wb_sel_i  => wb_in.sel(3 downto 0),
      wb_stb_i  => wb_in.stb,
      wb_we_i   => wb_in.we,
      wb_ack_o  => wb_out.ack,
      regs_o    => regs_in,
      regs_i    => regs_out);

end behavioral;
