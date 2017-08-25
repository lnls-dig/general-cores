-------------------------------------------------------------------------------
-- Title      : An Wishbone delay buffer
-- Project    : General Cores Library (gencores)
-------------------------------------------------------------------------------
-- File       : xwb_crossbar.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-12-16
-- Last update: 2016-04-12
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
  port(
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
  signal r_dat           : t_wishbone_data;

begin
  
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
    adr_i        => slave_i.adr,
    dat_i        => slave_i.dat,
    sel_i        => slave_i.sel,
    we_i         => slave_i.we,
    adr_o        => master_o.adr,
    dat_o        => master_o.dat,
    sel_o        => master_o.sel,
    we_o         => master_o.we
  );


  slave_o.ack   <= r_ack;	
  slave_o.err   <= r_err;
  slave_o.dat   <= r_dat; 

  s_pop         <= not master_i.stall;
  s_push        <= slave_i.cyc and slave_i.stb and not s_full;
  slave_o.stall <= s_full;
  master_o.stb  <= not s_empty; 
  master_o.cyc  <= slave_i.cyc;

  main : process(clk_sys_i, rst_n_i) is
  begin
    if rst_n_i = '0' then
      r_ack  <= '0';
      r_err  <= '0';
      r_dat  <= (others => '0');  
    elsif rising_edge(clk_sys_i) then
      -- no flow control on ack/err
      r_ack <= master_i.ack;
      r_err <= master_i.err;
      r_dat <= master_i.dat;
    end if;
  end process;

end rtl;
