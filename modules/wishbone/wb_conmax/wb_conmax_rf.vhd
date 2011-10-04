-------------------------------------------------------------------------------
-- Title      : Wishbone interconnect matrix for WR Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_conmax_rf.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-02-12
-- Last update: 2011-09-12
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- Register File - consists of 16 registers. Each stores configuration for 
-- different Slave. 
-- Each of those 16 registers is the Slave's personal priority register, 
-- where the priorities for each Master are stored. The Register File is 
-- accessible from Master through Slave 15th interface.
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


entity wb_conmax_rf is
  generic(
    g_rf_addr : integer range 0 to 15 := 15;  --0xF
    g_adr_width : integer;
    g_sel_width : integer;
    g_dat_width : integer);
  
  port(
    clk_i : in std_logic;
    rst_i : in std_logic;
    
    --Internal WB interface
    int_wb_i  : in  t_wishbone_slave_in;
    int_wb_o  : out t_wishbone_slave_out;
    --External WB interface
    ext_wb_i  : in  t_wishbone_master_in;
    ext_wb_o  : out t_wishbone_master_out;

    --Configuration regs
    conf_o    : out t_conmax_rf_conf
  );
end wb_conmax_rf;

architecture behaviour of wb_conmax_rf is

  signal s_rf_sel  : std_logic;
  signal s_rf_dout : std_logic_vector(15 downto 0);
  signal s_rf_ack  : std_logic;
  signal s_rf_we   : std_logic;

  signal s_conf    : t_conmax_rf_conf;

  signal s_rf_addr  : std_logic_vector(3 downto 0);
begin

  --Register File select logic
  s_rf_addr <= std_logic_vector(to_unsigned(g_rf_addr, 4));
  s_rf_sel <= int_wb_i.cyc and int_wb_i.stb when(int_wb_i.adr(g_adr_width-5 downto g_adr_width-8) = s_rf_addr )
              else '0';


  --Register File logic
  process(clk_i)
  begin
    if(clk_i'event and clk_i='1') then
      s_rf_we <= s_rf_sel and int_wb_i.we and not(s_rf_we);
      s_rf_ack <= s_rf_sel and not(s_rf_ack);
    end if;
  end process;


  --Write logic
  process(clk_i)
  begin
    if(clk_i'event and clk_i='1') then
      if(rst_i = '1') then
        s_conf <= (others=> (others=>'0'));
      elsif(s_rf_we='1') then

        if   (int_wb_i.adr(5 downto 2)=x"0") then s_conf(0)  <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"1") then s_conf(1)  <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"2") then s_conf(2)  <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"3") then s_conf(3)  <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"4") then s_conf(4)  <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"5") then s_conf(5)  <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"6") then s_conf(6)  <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"7") then s_conf(7)  <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"8") then s_conf(8)  <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"9") then s_conf(9)  <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"a") then s_conf(10) <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"b") then s_conf(11) <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"c") then s_conf(12) <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"d") then s_conf(13) <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"e") then s_conf(14) <= int_wb_i.dat(15 downto 0);
        elsif(int_wb_i.adr(5 downto 2)=x"f") then s_conf(15) <= int_wb_i.dat(15 downto 0);
        end if;

      end if;
    end if;
  end process;


  --Read logic
  process(clk_i)
  begin
    if(clk_i'event and clk_i='1') then
      if(s_rf_sel='0') then
        s_rf_dout <= x"0000";
      else
      
        if   ( int_wb_i.adr(5 downto 2)=x"0" ) then s_rf_dout <= s_conf(0);
        elsif( int_wb_i.adr(5 downto 2)=x"1" ) then s_rf_dout <= s_conf(1);
        elsif( int_wb_i.adr(5 downto 2)=x"2" ) then s_rf_dout <= s_conf(2);
        elsif( int_wb_i.adr(5 downto 2)=x"3" ) then s_rf_dout <= s_conf(3);
        elsif( int_wb_i.adr(5 downto 2)=x"4" ) then s_rf_dout <= s_conf(4);
        elsif( int_wb_i.adr(5 downto 2)=x"5" ) then s_rf_dout <= s_conf(5);
        elsif( int_wb_i.adr(5 downto 2)=x"6" ) then s_rf_dout <= s_conf(6);
        elsif( int_wb_i.adr(5 downto 2)=x"7" ) then s_rf_dout <= s_conf(7);
        elsif( int_wb_i.adr(5 downto 2)=x"8" ) then s_rf_dout <= s_conf(8);
        elsif( int_wb_i.adr(5 downto 2)=x"9" ) then s_rf_dout <= s_conf(9);
        elsif( int_wb_i.adr(5 downto 2)=x"A" ) then s_rf_dout <= s_conf(10);
        elsif( int_wb_i.adr(5 downto 2)=x"B" ) then s_rf_dout <= s_conf(11);
        elsif( int_wb_i.adr(5 downto 2)=x"C" ) then s_rf_dout <= s_conf(12);
        elsif( int_wb_i.adr(5 downto 2)=x"D" ) then s_rf_dout <= s_conf(13);
        elsif( int_wb_i.adr(5 downto 2)=x"E" ) then s_rf_dout <= s_conf(14);
        elsif( int_wb_i.adr(5 downto 2)=x"F" ) then s_rf_dout <= s_conf(15);
        end if;
      
      end if;
    end if;
  end process;


  --Register File bypass logic
  ext_wb_o.adr <= int_wb_i.adr;
  ext_wb_o.sel  <= int_wb_i.sel;
  ext_wb_o.dat <= int_wb_i.dat;
  ext_wb_o.cyc  <= int_wb_i.cyc when(s_rf_sel='0') else '0';
  ext_wb_o.stb  <= int_wb_i.stb;
  ext_wb_o.we   <= int_wb_i.we;

  int_wb_o.dat <= ( (g_dat_width-1 downto 16 => '0') & s_rf_dout ) when(s_rf_sel='1')
                   else ext_wb_i.dat;
  int_wb_o.ack  <= s_rf_ack when(s_rf_sel='1') else ext_wb_i.ack;
  int_wb_o.err  <= '0'      when(s_rf_sel='1') else ext_wb_i.err;
  int_wb_o.rty  <= '0'      when(s_rf_sel='1') else ext_wb_i.rty;

  conf_o  <= s_conf;

end behaviour;
