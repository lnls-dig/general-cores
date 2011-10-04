-------------------------------------------------------------------------------
-- Title      : Wishbone interconnect matrix for WR Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_conmax_slave_if.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-02-12
-- Last update: 2011-09-12
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- Full interface for a single Wishbone Slave. Consists of WB Master interface,
-- Prioritizing Arbiter and multiplexer for selecting appropriate Master.
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

entity wb_conmax_slave_if is
  generic(
    g_pri_sel : integer := 2
    );
  port(
    clk_i  : in std_logic;
    rst_i  : in std_logic;
    conf_i : in std_logic_vector(15 downto 0);

    --Slave interface
    wb_slave_i : in  t_wishbone_master_in;
    wb_slave_o : out t_wishbone_master_out;

    --Master (0 to 7) interfaces
    wb_masters_i : in  t_wishbone_slave_in_array(0 to 7);
    wb_masters_o : out t_wishbone_slave_out_array(0 to 7)
    );
end wb_conmax_slave_if;

architecture bahaviour of wb_conmax_slave_if is

  component wb_conmax_arb is
    port(
      clk_i : in std_logic;
      rst_i : in std_logic;

      req_i : in  std_logic_vector(7 downto 0);
      gnt_o : out std_logic_vector(2 downto 0);

      next_i : in std_logic
      );
  end component;

  component wb_conmax_msel is
    generic(
      g_pri_sel : integer := 0
      );
    port(
      clk_i : in std_logic;
      rst_i : in std_logic;

      conf_i : in std_logic_vector(15 downto 0);
      req_i  : in std_logic_vector(7 downto 0);
      next_i : in std_logic;

      sel : out std_logic_vector(2 downto 0)
      );
  end component;



  signal s_wb_cyc_o                       : std_logic;
  signal s_msel_simple, s_msel_pe, s_msel : std_logic_vector(2 downto 0);
  signal s_next                           : std_logic;
  signal s_mcyc                           : std_logic_vector(7 downto 0);
  signal s_arb_req_i                      : std_logic_vector(7 downto 0);

begin

  wb_slave_o.cyc <= s_wb_cyc_o;

  process(clk_i)
  begin
    if(clk_i'event and clk_i = '1') then
      s_next <= not(s_wb_cyc_o);
    end if;
  end process;

  s_arb_req_i <= wb_masters_i(7).cyc & wb_masters_i(6).cyc & wb_masters_i(5).cyc &
                 wb_masters_i(4).cyc & wb_masters_i(3).cyc & wb_masters_i(2).cyc &
                 wb_masters_i(1).cyc & wb_masters_i(0).cyc;
  --Prioritizing Arbiter
  ARB : wb_conmax_arb
    port map(
      clk_i => clk_i,
      rst_i => rst_i,

      req_i  => s_arb_req_i,
      gnt_o  => s_msel_simple,
      next_i => '0'                     --no round robin
      );

  MSEL : wb_conmax_msel
    generic map(
      g_pri_sel => g_pri_sel
      )
    port map(
      clk_i => clk_i,
      rst_i => rst_i,

      conf_i => conf_i,
      req_i  => s_arb_req_i,
      next_i => s_next,
      sel    => s_msel_pe
      );

  G1 : if(g_pri_sel = 0) generate
    s_msel <= s_msel_simple;
  end generate;
  G2 : if(g_pri_sel /= 0) generate
    s_msel <= s_msel_pe;
  end generate;


  -------------------------------------
  --Address & Data Pass
  wb_slave_o.adr <= wb_masters_i(0).adr when(s_msel = "000") else
                    wb_masters_i(1).adr when(s_msel = "001") else
                    wb_masters_i(2).adr when(s_msel = "010") else
                    wb_masters_i(3).adr when(s_msel = "011") else
                    wb_masters_i(4).adr when(s_msel = "100") else
                    wb_masters_i(5).adr when(s_msel = "101") else
                    wb_masters_i(6).adr when(s_msel = "110") else
                    wb_masters_i(7).adr when(s_msel = "111") else
                    (others => '0');

  wb_slave_o.sel <= wb_masters_i(0).sel when(s_msel = "000") else
                     wb_masters_i(1).sel when(s_msel = "001") else
                     wb_masters_i(2).sel when(s_msel = "010") else
                     wb_masters_i(3).sel when(s_msel = "011") else
                     wb_masters_i(4).sel when(s_msel = "100") else
                     wb_masters_i(5).sel when(s_msel = "101") else
                     wb_masters_i(6).sel when(s_msel = "110") else
                     wb_masters_i(7).sel when(s_msel = "111") else
                     (others => '0');

  wb_slave_o.dat <= wb_masters_i(0).dat when(s_msel = "000") else
                     wb_masters_i(1).dat when(s_msel = "001") else
                     wb_masters_i(2).dat when(s_msel = "010") else
                     wb_masters_i(3).dat when(s_msel = "011") else
                     wb_masters_i(4).dat when(s_msel = "100") else
                     wb_masters_i(5).dat when(s_msel = "101") else
                     wb_masters_i(6).dat when(s_msel = "110") else
                     wb_masters_i(7).dat when(s_msel = "111") else
                     (others => '0');
  
  G_OUT : for I in 0 to 7 generate
    wb_masters_o(I).dat <= wb_slave_i.dat;
    wb_masters_o(I).ack <= wb_slave_i.ack when(s_msel = std_logic_vector(
      to_unsigned(I, 3)) ) else '0';
    wb_masters_o(I).err <= wb_slave_i.err when(s_msel = std_logic_vector(
      to_unsigned(I, 3)) ) else '0';
    wb_masters_o(I).rty <= wb_slave_i.rty when(s_msel = std_logic_vector(
      to_unsigned(I, 3)) ) else '0';
  end generate;

  ------------------------------------
  --Control Signal Pass
  wb_slave_o.we <= wb_masters_i(0).we when(s_msel = "000") else
                   wb_masters_i(1).we when(s_msel = "001") else
                   wb_masters_i(2).we when(s_msel = "010") else
                   wb_masters_i(3).we when(s_msel = "011") else
                   wb_masters_i(4).we when(s_msel = "100") else
                   wb_masters_i(5).we when(s_msel = "101") else
                   wb_masters_i(6).we when(s_msel = "110") else
                   wb_masters_i(7).we when(s_msel = "111") else
                   '0';

  process(clk_i)
  begin
    if(clk_i'event and clk_i = '1') then
      s_mcyc(7 downto 0) <= wb_masters_i(7).cyc & wb_masters_i(6).cyc &
                                 wb_masters_i(5).cyc & wb_masters_i(4).cyc & wb_masters_i(3).cyc &
                                 wb_masters_i(2).cyc & wb_masters_i(1).cyc & wb_masters_i(0).cyc;
      
    end if;
  end process;

  s_wb_cyc_o <= wb_masters_i(0).cyc and s_mcyc(0) when(s_msel = "000") else
                wb_masters_i(1).cyc and s_mcyc(1) when(s_msel = "001") else
                wb_masters_i(2).cyc and s_mcyc(2) when(s_msel = "010") else
                wb_masters_i(3).cyc and s_mcyc(3) when(s_msel = "011") else
                wb_masters_i(4).cyc and s_mcyc(4) when(s_msel = "100") else
                wb_masters_i(5).cyc and s_mcyc(5) when(s_msel = "101") else
                wb_masters_i(6).cyc and s_mcyc(6) when(s_msel = "110") else
                wb_masters_i(7).cyc and s_mcyc(7) when(s_msel = "111") else
                '0';

  wb_slave_o.stb <= wb_masters_i(0).stb when(s_msel = "000") else
                    wb_masters_i(1).stb when(s_msel = "001") else
                    wb_masters_i(2).stb when(s_msel = "010") else
                    wb_masters_i(3).stb when(s_msel = "011") else
                    wb_masters_i(4).stb when(s_msel = "100") else
                    wb_masters_i(5).stb when(s_msel = "101") else
                    wb_masters_i(6).stb when(s_msel = "110") else
                    wb_masters_i(7).stb when(s_msel = "111") else
                    '0';

end bahaviour;
