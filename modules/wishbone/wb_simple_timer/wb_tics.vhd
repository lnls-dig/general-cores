-------------------------------------------------------------------------------
-- Title      : WhiteRabbit PTP Core tics
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_tics.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-04-03
-- Last update: 2011-10-04
-- Platform   : FPGA-generics
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description:
-- WB_TICS is a simple counter with wishbone interface. Each step of a counter
-- takes 1 usec. It is used by ptp-noposix as a replace of gettimeofday()
-- function.
-------------------------------------------------------------------------------
-- Copyright (c) 2011 Grzegorz Daniluk
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-04-03  1.0      greg.d          Created
-- 2011-10-04  1.1      twlostow        added wishbone adapter
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;


entity wb_tics is

  generic (
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD;
    g_period : integer);
  port(
    rst_n_i : in std_logic;
    clk_sys_i : in std_logic;

    wb_adr_i : in  std_logic_vector(3 downto 0);
    wb_dat_i : in  std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_dat_o : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_cyc_i  : in  std_logic;
    wb_sel_i  : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0);
    wb_stb_i  : in  std_logic;
    wb_we_i   : in  std_logic;
    wb_ack_o  : out std_logic;
    wb_stall_o: out std_logic
    );
end wb_tics;

architecture behaviour of wb_tics is

  constant c_TICS_REG : std_logic_vector(1 downto 0) := "00";

  signal cntr_div      : unsigned(23 downto 0);
  signal cntr_tics     : unsigned(31 downto 0);
  signal cntr_overflow : std_logic;

  signal wb_in  : t_wishbone_slave_in;
  signal wb_out : t_wishbone_slave_out;

  signal resized_addr : std_logic_vector(c_wishbone_address_width-1 downto 0);
begin

  resized_addr(3 downto 0) <= wb_adr_i;
  resized_addr(c_wishbone_address_width-1 downto 4) <= (others => '0');

  U_Adapter : wb_slave_adapter
    generic map (
      g_master_use_struct  => true,
      g_master_mode        => CLASSIC,
      g_master_granularity => WORD,
      g_slave_use_struct   => false,
      g_slave_mode         => g_interface_mode,
      g_slave_granularity  => g_address_granularity)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      master_i   => wb_out,
      master_o   => wb_in,
      sl_adr_i   => resized_addr,
      sl_dat_i   => wb_dat_i,
      sl_sel_i   => wb_sel_i,
      sl_cyc_i   => wb_cyc_i,
      sl_stb_i   => wb_stb_i,
      sl_we_i    => wb_we_i,
      sl_dat_o   => wb_dat_o,
      sl_ack_o   => wb_ack_o,
      sl_stall_o => wb_stall_o);
  
  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if(rst_n_i = '0') then
        cntr_div      <= (others => '0');
        cntr_overflow <= '0';
      else
        if(cntr_div = g_period-1) then
          cntr_div      <= (others => '0');
          cntr_overflow <= '1';
        else
          cntr_div      <= cntr_div + 1;
          cntr_overflow <= '0';
        end if;
      end if;
    end if;
  end process;

  --usec counter
  process(clk_sys_i)
  begin
    if(rising_edge(clk_sys_i)) then
      if(rst_n_i = '0') then
        cntr_tics <= (others => '0');
      elsif(cntr_overflow = '1') then
        cntr_tics <= cntr_tics + 1;
      end if;
    end if;
  end process;

  --Wishbone interface
  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if(rst_n_i = '0') then
        wb_out.ack  <= '0';
        wb_out.dat <= (others => '0');
      else
        if(wb_in.stb = '1' and wb_in.cyc = '1') then
          if(wb_in.we = '0') then
            case wb_in.adr(1 downto 0) is
              when c_TICS_REG =>
                wb_out.dat <= std_logic_vector(cntr_tics);
              when others =>
                wb_out.dat <= (others => '0');
            end case;
          end if;
          wb_out.ack <= '1';
        else
          wb_out.dat <= (others => '0');
          wb_out.ack  <= '0';
        end if;
      end if;
    end if;
  end process;

end behaviour;
