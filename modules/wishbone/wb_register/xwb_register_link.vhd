-------------------------------------------------------------------------------
-- Title      : An Wishbone delay buffer
-- Project    : General Cores Library (gencores)
-------------------------------------------------------------------------------
-- File       : xwb_crossbar.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-12-16
-- Last update: 2018-11-19
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description:
--
-- Adds registers between two wishbone interfaces.
-- Useful to improve timing closure when placed between crossbars.
--
-------------------------------------------------------------------------------
-- Copyright (c) 2011 GSI / Wesley W. Terpstra
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-12-16  1.0      wterpstra       V1, half bandwidth
-- 2016-04-12  2.0      mkreider        reworked, now with full throughput

-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.wishbone_pkg.all;

entity xwb_register_link is
  generic (
    g_WB_IN_MODE         : t_wishbone_interface_mode      := PIPELINED;
    g_WB_IN_GRANULARITY  : t_wishbone_address_granularity := BYTE;
    g_WB_OUT_MODE        : t_wishbone_interface_mode      := PIPELINED;
    g_WB_OUT_GRANULARITY : t_wishbone_address_granularity := BYTE);
  port (
    clk_sys_i : in  std_logic;
    rst_n_i   : in  std_logic;
    slave_i   : in  t_wishbone_slave_in;
    slave_o   : out t_wishbone_slave_out;
    master_i  : in  t_wishbone_master_in;
    master_o  : out t_wishbone_master_out);
end xwb_register_link;

architecture rtl of xwb_register_link is

  signal s_push, s_pop   : std_logic;
  signal s_full, s_empty : std_logic;
  signal r_ack,  r_err   : std_logic;
  signal r_cyc           : std_logic;
  signal r_dat           : t_wishbone_data;

  signal slave_in   : t_wishbone_slave_in;
  signal slave_out  : t_wishbone_slave_out;
  signal master_in  : t_wishbone_master_in;
  signal master_out : t_wishbone_master_out;

begin

  -- xwb_register_link only works with PIPELINED interfaces.
  -- We convert from/to PIPELINED to enforce this.
  wb_slave_adapter_in: wb_slave_adapter
    generic map (
      g_master_use_struct  => TRUE,
      g_slave_use_struct   => TRUE,
      g_slave_mode         => g_WB_IN_MODE,
      g_slave_granularity  => g_WB_IN_GRANULARITY,
      g_master_mode        => CLASSIC,
      g_master_granularity => BYTE)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      slave_i    => slave_i,
      slave_o    => slave_o,
      master_i   => slave_out,
      master_o   => slave_in);

  wb_slave_adapter_out: wb_slave_adapter
    generic map (
      g_master_use_struct  => TRUE,
      g_slave_use_struct   => TRUE,
      g_slave_mode         => CLASSIC,
      g_slave_granularity  => BYTE,
      g_master_mode        => g_WB_OUT_MODE,
      g_master_granularity => g_WB_OUT_GRANULARITY)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      slave_i    => master_out,
      slave_o    => master_in,
      master_i   => master_i,
      master_o   => master_o);

  sp : wb_skidpad
  generic map(
    g_adrbits   => c_wishbone_address_width
  )
  Port map(
    clk_i        => clk_sys_i,
    rst_n_i      => rst_n_i,
    push_i       => s_push,
    pop_i        => s_pop,
    full_o       => s_full,
    empty_o      => s_empty,
    adr_i        => slave_in.adr,
    dat_i        => slave_in.dat,
    sel_i        => slave_in.sel,
    we_i         => slave_in.we,
    adr_o        => master_out.adr,
    dat_o        => master_out.dat,
    sel_o        => master_out.sel,
    we_o         => master_out.we
  );


  slave_out.ack   <= r_ack;
  slave_out.err   <= r_err;
  slave_out.dat   <= r_dat;
  slave_out.rty   <= '0';

  s_pop           <= not master_in.stall;
  s_push          <= slave_in.cyc and slave_in.stb and not s_full;
  slave_out.stall <= s_full;
  master_out.stb  <= not s_empty;
  master_out.cyc  <= r_cyc;

  main : process(clk_sys_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_cyc  <= '0';
      r_ack  <= '0';
      r_err  <= '0';
      r_dat  <= (others => '0');
    elsif rising_edge(clk_sys_i) then
      r_cyc <= slave_in.cyc;
      -- no flow control on ack/err
      r_ack <= master_in.ack;
      r_err <= master_in.err;
      r_dat <= master_in.dat;
    end if;
  end process;

end rtl;
