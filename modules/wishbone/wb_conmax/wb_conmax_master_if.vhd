-------------------------------------------------------------------------------
-- Title      : Wishbone interconnect matrix for WR Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_conmax_master_if.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-02-12
-- Last update: 2011-09-12
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- Wishbone interface to connect WB master from outside. Decodes 4 most 
-- significant bits of Address bus. Using the selection it multiplexes the 
-- Master's WB interface to appropriate Slave interface.
--
-------------------------------------------------------------------------------
-- Copyright (C) 2000-2002 Rudolf Usselmann
-- Copyright (c) 2011 Grzegorz Daniluk (VHDL port)
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-02-12  1.0      greg.d          Created
-- 2011-02-16  1.1      greg.d          Using generates and types
-------------------------------------------------------------------------------
-- TODO:
-- Code optimization. (now it is more like dummy translation from Verilog)
--
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wbconmax_pkg.all;
use work.wishbone_pkg.all;

entity wb_conmax_master_if is
  generic(
    g_adr_width : integer;
    g_sel_width : integer;
    g_dat_width : integer);
  port(
    clk_i : in std_logic;
    rst_i : in std_logic;

    --Master interface
    wb_master_i : in  t_wishbone_slave_in;
    wb_master_o : out t_wishbone_slave_out;

    --Slaves(0 to 15) interface
    wb_slaves_i : in  t_wishbone_master_in_array(0 to 15);
    wb_slaves_o : out t_wishbone_master_out_array(0 to 15)
    ); 
end wb_conmax_master_if;

architecture behaviour of wb_conmax_master_if is


  signal s_slv_sel    : std_logic_vector(3 downto 0);
  signal s_cyc_o_next : std_logic_vector(15 downto 0);
  signal s_cyc_o      : std_logic_vector(15 downto 0);

begin

  --Select logic
  s_slv_sel <= wb_master_i.adr(g_adr_width-1 downto g_adr_width-4);

  --Address & Data Pass
  GEN_OUTS :
  for I in 0 to 15 generate
    wb_slaves_o(I).adr <= wb_master_i.adr;
    wb_slaves_o(I).sel <= wb_master_i.sel;
    wb_slaves_o(I).dat <= wb_master_i.dat;
    wb_slaves_o(I).we  <= wb_master_i.we;
    wb_slaves_o(I).cyc <= s_cyc_o(I);
    wb_slaves_o(I).stb <= wb_master_i.stb when(s_slv_sel = std_logic_vector(
      to_unsigned(I, 4)) ) else '0';
  end generate;

  wb_master_o.dat <= wb_slaves_i(0).dat when(s_slv_sel = "0000") else
                     wb_slaves_i(1).dat  when(s_slv_sel = "0001") else
                     wb_slaves_i(2).dat  when(s_slv_sel = "0010") else
                     wb_slaves_i(3).dat  when(s_slv_sel = "0011") else
                     wb_slaves_i(4).dat  when(s_slv_sel = "0100") else
                     wb_slaves_i(5).dat  when(s_slv_sel = "0101") else
                     wb_slaves_i(6).dat  when(s_slv_sel = "0110") else
                     wb_slaves_i(7).dat  when(s_slv_sel = "0111") else
                     wb_slaves_i(8).dat  when(s_slv_sel = "1000") else
                     wb_slaves_i(9).dat  when(s_slv_sel = "1001") else
                     wb_slaves_i(10).dat when(s_slv_sel = "1010") else
                     wb_slaves_i(11).dat when(s_slv_sel = "1011") else
                     wb_slaves_i(12).dat when(s_slv_sel = "1100") else
                     wb_slaves_i(13).dat when(s_slv_sel = "1101") else
                     wb_slaves_i(14).dat when(s_slv_sel = "1110") else
                     wb_slaves_i(15).dat when(s_slv_sel = "1111") else
                     (others => '0');

  --Control Signal Pass
  G1 : for I in 0 to 15 generate
    s_cyc_o_next(I) <= s_cyc_o(I) when (wb_master_i.cyc = '1' and wb_master_i.stb = '0') else
                       wb_master_i.cyc when (s_slv_sel = std_logic_vector(to_unsigned(I, 4))) else
                       '0';
  end generate;

  process(clk_i)
  begin
    if(clk_i'event and clk_i = '1') then
      if(rst_i = '1') then
        s_cyc_o(15 downto 0) <= (others => '0');
      else
        s_cyc_o(15 downto 0) <= s_cyc_o_next(15 downto 0);
      end if;
    end if;
  end process;

  wb_master_o.ack <= wb_slaves_i(0).ack when(s_slv_sel = "0000") else
                     wb_slaves_i(1).ack  when(s_slv_sel = "0001") else
                     wb_slaves_i(2).ack  when(s_slv_sel = "0010") else
                     wb_slaves_i(3).ack  when(s_slv_sel = "0011") else
                     wb_slaves_i(4).ack  when(s_slv_sel = "0100") else
                     wb_slaves_i(5).ack  when(s_slv_sel = "0101") else
                     wb_slaves_i(6).ack  when(s_slv_sel = "0110") else
                     wb_slaves_i(7).ack  when(s_slv_sel = "0111") else
                     wb_slaves_i(8).ack  when(s_slv_sel = "1000") else
                     wb_slaves_i(9).ack  when(s_slv_sel = "1001") else
                     wb_slaves_i(10).ack when(s_slv_sel = "1010") else
                     wb_slaves_i(11).ack when(s_slv_sel = "1011") else
                     wb_slaves_i(12).ack when(s_slv_sel = "1100") else
                     wb_slaves_i(13).ack when(s_slv_sel = "1101") else
                     wb_slaves_i(14).ack when(s_slv_sel = "1110") else
                     wb_slaves_i(15).ack when(s_slv_sel = "1111") else
                     '0';

  wb_master_o.err <= wb_slaves_i(0).err when(s_slv_sel = "0000") else
                     wb_slaves_i(1).err  when(s_slv_sel = "0001") else
                     wb_slaves_i(2).err  when(s_slv_sel = "0010") else
                     wb_slaves_i(3).err  when(s_slv_sel = "0011") else
                     wb_slaves_i(4).err  when(s_slv_sel = "0100") else
                     wb_slaves_i(5).err  when(s_slv_sel = "0101") else
                     wb_slaves_i(6).err  when(s_slv_sel = "0110") else
                     wb_slaves_i(7).err  when(s_slv_sel = "0111") else
                     wb_slaves_i(8).err  when(s_slv_sel = "1000") else
                     wb_slaves_i(9).err  when(s_slv_sel = "1001") else
                     wb_slaves_i(10).err when(s_slv_sel = "1010") else
                     wb_slaves_i(11).err when(s_slv_sel = "1011") else
                     wb_slaves_i(12).err when(s_slv_sel = "1100") else
                     wb_slaves_i(13).err when(s_slv_sel = "1101") else
                     wb_slaves_i(14).err when(s_slv_sel = "1110") else
                     wb_slaves_i(15).err when(s_slv_sel = "1111") else
                     '0';

  wb_master_o.rty <= wb_slaves_i(0).rty when(s_slv_sel = "0000") else
                     wb_slaves_i(1).rty  when(s_slv_sel = "0001") else
                     wb_slaves_i(2).rty  when(s_slv_sel = "0010") else
                     wb_slaves_i(3).rty  when(s_slv_sel = "0011") else
                     wb_slaves_i(4).rty  when(s_slv_sel = "0100") else
                     wb_slaves_i(5).rty  when(s_slv_sel = "0101") else
                     wb_slaves_i(6).rty  when(s_slv_sel = "0110") else
                     wb_slaves_i(7).rty  when(s_slv_sel = "0111") else
                     wb_slaves_i(8).rty  when(s_slv_sel = "1000") else
                     wb_slaves_i(9).rty  when(s_slv_sel = "1001") else
                     wb_slaves_i(10).rty when(s_slv_sel = "1010") else
                     wb_slaves_i(11).rty when(s_slv_sel = "1011") else
                     wb_slaves_i(12).rty when(s_slv_sel = "1100") else
                     wb_slaves_i(13).rty when(s_slv_sel = "1101") else
                     wb_slaves_i(14).rty when(s_slv_sel = "1110") else
                     wb_slaves_i(15).rty when(s_slv_sel = "1111") else
                     '0';

end behaviour;
