------------------------------------------------------------------------------
-- Title      : Atmel EBI asynchronous bus <-> Wishbone bridge
-- Project    : White Rabbit Switch
------------------------------------------------------------------------------
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-05-18
-- Last update: 2011-03-16
-- Platform   : FPGA-generic
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: An interface between AT91SAM9x-series ARM CPU External Bus Interface
-- and FPGA-internal Wishbone bus:
-- - does clock domain synchronisation
-- - provides configurable number of independent WB master ports at fixed base addresses
-- TODO:
-- - implement write queueing and read prefetching (for speed improvement)
-------------------------------------------------------------------------------
-- Copyright (c) 2010 Tomasz Wlostowski
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2010-05-18  1.0      twlostow        Created
-------------------------------------------------------------------------------


library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.log2;
use ieee.math_real.ceil;


use work.gencores_pkg.all;
use work.wishbone_pkg.all;

entity wb_cpu_bridge is
  generic (
    g_simulation           : integer := 0;
    g_wishbone_num_masters : integer);

  port(
    sys_rst_n_i : in std_logic;         -- global reset

-------------------------------------------------------------------------------
-- Atmel EBI bus
-------------------------------------------------------------------------------

    cpu_clk_i  : in std_logic;          -- clock (not used now)
-- async chip select, active LOW
    cpu_cs_n_i : in std_logic;
-- async write, active LOW
    cpu_wr_n_i : in std_logic;
-- async read, active LOW
    cpu_rd_n_i : in std_logic;
-- byte select, active  LOW (not used due to weird CPU pin layout - NBS2 line is
-- shared with 100 Mbps Ethernet PHY)
    cpu_bs_n_i : in std_logic_vector(3 downto 0);

-- address input
    cpu_addr_i : in std_logic_vector(c_cpu_addr_width-1 downto 0);

-- data bus (bidirectional)
    cpu_data_b : inout std_logic_vector(31 downto 0);

-- async wait, active LOW
    cpu_nwait_o : out std_logic;

-------------------------------------------------------------------------------
-- Wishbone master I/F 
-------------------------------------------------------------------------------

-- wishbone clock input (refclk/2)
    wb_clk_i  : in  std_logic;
-- wishbone master address output (m->s, common for all slaves)
    wb_addr_o : out std_logic_vector(c_wishbone_addr_width - 1 downto 0);
-- wishbone master data output (m->s, common for all slaves)
    wb_data_o : out std_logic_vector(31 downto 0);
-- wishbone cycle strobe (m->s, common for all slaves)
    wb_stb_o  : out std_logic;
-- wishbone write enable (m->s, common for all slaves)
    wb_we_o   : out std_logic;
-- wishbone byte select output (m->s, common for all slaves)
    wb_sel_o  : out std_logic_vector(3 downto 0);


-- wishbone cycle select (m->s, individual)
    wb_cyc_o  : out std_logic_vector (g_wishbone_num_masters - 1 downto 0);
-- wishbone master data input (s->m, individual)
    wb_data_i : in  std_logic_vector (32 * g_wishbone_num_masters-1 downto 0);
-- wishbone ACK input (s->m, individual)
    wb_ack_i  : in  std_logic_vector(g_wishbone_num_masters-1 downto 0)

    );

end wb_cpu_bridge;

architecture behavioral of wb_cpu_bridge is

  constant c_periph_addr_bits : integer := c_cpu_addr_width - c_wishbone_addr_width;

  signal periph_addr     : std_logic_vector(c_periph_addr_bits - 1 downto 0);
  signal periph_addr_reg : std_logic_vector(c_periph_addr_bits - 1 downto 0);

  signal periph_sel     : std_logic_vector(g_wishbone_num_masters - 1 downto 0);
  signal periph_sel_reg : std_logic_vector(g_wishbone_num_masters - 1 downto 0);


  signal rw_sel, cycle_in_progress, cs_synced, rd_pulse, wr_pulse : std_logic;
  signal cpu_data_reg                                             : std_logic_vector(31 downto 0);
  signal ack_muxed                                                : std_logic;
  signal data_in_muxed                                            : std_logic_vector(31 downto 0);
  signal long_cycle                                               : std_logic;
  signal wb_cyc_int                                               : std_logic;
  
begin

  gen_sync_chains_nosim : if(g_simulation = 0) generate

    sync_ffs_cs : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map
      (rst_n_i  => sys_rst_n_i,
       clk_i    => wb_clk_i,
       data_i   => cpu_cs_n_i,
       synced_o => cs_synced,
       npulse_o => open
       );

    sync_ffs_wr : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        rst_n_i  => sys_rst_n_i,
        clk_i    => wb_clk_i,
        data_i   => cpu_wr_n_i,
        synced_o => open,
        npulse_o => wr_pulse
        );

    sync_ffs_rd : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        rst_n_i  => sys_rst_n_i,
        clk_i    => wb_clk_i,
        data_i   => cpu_rd_n_i,
        synced_o => open,
        npulse_o => rd_pulse
        );

  end generate gen_sync_chains_nosim;

  gen_sim : if(g_simulation = 1) generate
    wr_pulse  <= not cpu_wr_n_i;
    rd_pulse  <= not cpu_rd_n_i;
    cs_synced <= cpu_cs_n_i;
  end generate gen_sim;



  periph_addr <= cpu_addr_i (c_cpu_addr_width - 1 downto c_wishbone_addr_width);

  onehot_decode : process (periph_addr)  -- periph_sel <= onehot_decode(periph_addr)
    variable temp1 : std_logic_vector (periph_sel'high downto 0);
    variable temp2 : integer range 0 to periph_sel'high;
  begin
    temp1 := (others => '0');
    temp2 := 0;
    for i in periph_addr'range loop
      if (periph_addr(i) = '1') then
        temp2 := 2*temp2+1;
      else
        temp2 := 2*temp2;
      end if;
    end loop;
    temp1(temp2) := '1';
    periph_sel   <= temp1;
  end process;


  ACK_MUX : process (periph_addr_reg, wb_ack_i)
  begin
    if(to_integer(unsigned(periph_addr_reg)) < g_wishbone_num_masters) then
      ack_muxed <= wb_ack_i(to_integer(unsigned(periph_addr_reg)));
    else
      ack_muxed <= '0';
    end if;
  end process;


  DIN_MUX : process (periph_addr_reg, wb_data_i)
  begin
    if(to_integer(unsigned(periph_addr_reg)) < g_wishbone_num_masters) then
      data_in_muxed <= wb_data_i(32*to_integer(unsigned(periph_addr_reg)) + 31 downto 32 * to_integer(unsigned(periph_addr_reg)));
    else
      data_in_muxed <= (others => 'X');
    end if;
  end process;

  process(wb_clk_i)
  begin
    if(rising_edge(wb_clk_i)) then
      if(sys_rst_n_i = '0') then
        cpu_data_reg      <= (others => '0');
        cycle_in_progress <= '0';
        rw_sel            <= '0';
        cpu_nwait_o       <= '1';
        long_cycle        <= '0';

        wb_addr_o  <= (others => '0');
        wb_data_o  <= (others => '0');
        wb_sel_o   <= (others => '1');
        wb_stb_o   <= '0';
        wb_we_o    <= '0';
        wb_cyc_int <= '0';

        periph_sel_reg  <= (others => '0');
        periph_addr_reg <= (others => '0');
      else
        

        if(cs_synced = '0') then

          wb_addr_o <= cpu_addr_i(c_wishbone_addr_width-1 downto 0);

          if(cycle_in_progress = '1') then
            if(ack_muxed = '1') then

              if(rw_sel = '0') then
                cpu_data_reg <= data_in_muxed;
              end if;

              cycle_in_progress <= '0';
              wb_cyc_int        <= '0';
              wb_sel_o          <= (others => '1');
              wb_stb_o          <= '0';
              wb_we_o           <= '0';
              cpu_nwait_o       <= '1';
              long_cycle        <= '0';
              
            else
              cpu_nwait_o <= not long_cycle;
              long_cycle  <= '1';
            end if;
            
          elsif(rd_pulse = '1' or wr_pulse = '1') then
            wb_we_o <= wr_pulse;
            rw_sel  <= wr_pulse;

            wb_cyc_int <= '1';
            wb_stb_o   <= '1';
            wb_addr_o  <= cpu_addr_i(c_wishbone_addr_width-1 downto 0);
            long_cycle <= '0';

            periph_addr_reg <= cpu_addr_i (c_cpu_addr_width-1 downto c_wishbone_addr_width);
            periph_sel_reg  <= periph_sel;

            if(wr_pulse = '1') then
              wb_data_o <= cpu_data_b;
            end if;

            cycle_in_progress <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  process(cpu_cs_n_i, cpu_rd_n_i, cpu_data_reg)
  begin
    if(cpu_cs_n_i = '0' and cpu_rd_n_i = '0') then
      cpu_data_b <= cpu_data_reg;
    else
      cpu_data_b <= (others => 'Z');
    end if;
  end process;

  gen_cyc_outputs : for i in 0 to g_wishbone_num_masters-1 generate
    wb_cyc_o(i) <= wb_cyc_int and periph_sel_reg(i);
  end generate gen_cyc_outputs;
  
  

end behavioral;
