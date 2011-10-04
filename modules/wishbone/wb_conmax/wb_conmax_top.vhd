-------------------------------------------------------------------------------
-- Title      : Wishbone interconnect matrix for WR Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_conmax_top.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-02-12
-- Last update: 2011-09-14
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- Wishbone Interconnect Matrix, up to 8 Masters and 16 Slaves. Features 
-- prioritized arbiter inside each Slave Interface (1, 2 of 4 priority levels).
-- Allows the parallel communication between masters and slaves on 
-- different interfaces.
-- It is the WISHBONE Conmax IP Core from opencores.org rewritten in VHDL (from
-- Verilog) with some code optimalization.
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

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.wbconmax_pkg.all;

entity wb_conmax_top is
  generic(
    g_rf_addr     : integer range 0 to 15 := 15   --0xf
  );
  port(
    clk_i : std_logic;
    rst_i : std_logic;

    wb_masters_i : in  t_conmax_masters_i;
    wb_masters_o : out t_conmax_masters_o;
    wb_slaves_i  : in  t_conmax_slaves_i;
    wb_slaves_o  : out t_conmax_slaves_o
  );
end wb_conmax_top;

architecture struct of wb_conmax_top is
  
  component wb_conmax_master_if is
    port(
      clk_i : in std_logic;
      rst_i : in std_logic;

      --Master interface
      wb_master_i : in  t_wb_i;
      wb_master_o : out t_wb_o;

      --Slaves(0 to 15) interface
      wb_slaves_i : in  t_conmax_slaves_i;
      wb_slaves_o : out t_conmax_slaves_o
    ); 
  end component;

  component wb_conmax_slave_if is
    generic(
      g_pri_sel : integer := 2
    );
    port(
      clk_i        : in std_logic;
      rst_i        : in std_logic;
      conf_i       : in std_logic_vector(15 downto 0);
  
      --Slave interface
      wb_slave_i   : in  t_wb_o;
      wb_slave_o   : out t_wb_i;

      --Master (0 to 7) interfaces
      wb_masters_i : in  t_conmax_masters_i;
      wb_masters_o : out t_conmax_masters_o
    );
  end component;

  component wb_conmax_rf is
    generic(
      g_rf_addr : integer range 0 to 15 := 15  --0xF
    );
    port(
      clk_i : in std_logic;
      rst_i : in std_logic;
      
      --Internal WB interface
      int_wb_i  : in  t_wb_i;
      int_wb_o  : out t_wb_o;
      --External WB interface
      ext_wb_i  : in  t_wb_o;
      ext_wb_o  : out t_wb_i;

      --Configuration regs
      conf_o    : out t_rf_conf
    );
  end component;


  signal intwb_s15_i  : t_wishbone_master_in;
  signal intwb_s15_o  : t_wishbone_master_out;
  

  --M0Sx
  signal m0_slaves_i : t_conmax_slaves_i;
  signal m0_slaves_o : t_conmax_slaves_o;
  signal m1_slaves_i : t_conmax_slaves_i;
  signal m1_slaves_o : t_conmax_slaves_o;
  signal m2_slaves_i : t_conmax_slaves_i;
  signal m2_slaves_o : t_conmax_slaves_o;
  signal m3_slaves_i : t_conmax_slaves_i;
  signal m3_slaves_o : t_conmax_slaves_o;
  signal m4_slaves_i : t_conmax_slaves_i;
  signal m4_slaves_o : t_conmax_slaves_o;
  signal m5_slaves_i : t_conmax_slaves_i;
  signal m5_slaves_o : t_conmax_slaves_o;
  signal m6_slaves_i : t_conmax_slaves_i;
  signal m6_slaves_o : t_conmax_slaves_o;
  signal m7_slaves_i : t_conmax_slaves_i;
  signal m7_slaves_o : t_conmax_slaves_o;


  signal s_conf   : t_rf_conf;
  
  signal s15_wb_masters_i : t_conmax_masters_i;
  signal s15_wb_masters_o : t_conmax_masters_o;

begin

  --Master interfaces
  M0: wb_conmax_master_if
    port map(
      clk_i => clk_i,
      rst_i => rst_i,
  
      --Master interface
      wb_master_i => wb_masters_i(0),
      wb_master_o => wb_masters_o(0),
      --Slaves(0 to 15) interface
      wb_slaves_i => m0_slaves_i,
      wb_slaves_o => m0_slaves_o
    );

  M1: wb_conmax_master_if
    port map(
      clk_i => clk_i,
      rst_i => rst_i,

      wb_master_i => wb_masters_i(1),
      wb_master_o => wb_masters_o(1),
      wb_slaves_i => m1_slaves_i,
      wb_slaves_o => m1_slaves_o
    );

  M2: wb_conmax_master_if
    port map(
      clk_i => clk_i,
      rst_i => rst_i,
  
      wb_master_i => wb_masters_i(2),
      wb_master_o => wb_masters_o(2),
      wb_slaves_i => m2_slaves_i,
      wb_slaves_o => m2_slaves_o
    );
     
  M3: wb_conmax_master_if
    port map(
      clk_i => clk_i,
      rst_i => rst_i,
  
      wb_master_i => wb_masters_i(3),
      wb_master_o => wb_masters_o(3),
      wb_slaves_i => m3_slaves_i,
      wb_slaves_o => m3_slaves_o
    );

  M4: wb_conmax_master_if
    port map(
      clk_i => clk_i,
      rst_i => rst_i,
  
      wb_master_i => wb_masters_i(4),
      wb_master_o => wb_masters_o(4),
      wb_slaves_i => m4_slaves_i,
      wb_slaves_o => m4_slaves_o
    );

  M5: wb_conmax_master_if
    port map(
      clk_i => clk_i,
      rst_i => rst_i,
  
      wb_master_i => wb_masters_i(5),
      wb_master_o => wb_masters_o(5),
      wb_slaves_i => m5_slaves_i,
      wb_slaves_o => m5_slaves_o
    );

  M6: wb_conmax_master_if
    port map(
      clk_i => clk_i,
      rst_i => rst_i,
  
      wb_master_i => wb_masters_i(6),
      wb_master_o => wb_masters_o(6),
      wb_slaves_i => m6_slaves_i,
      wb_slaves_o => m6_slaves_o
    );

  M7: wb_conmax_master_if
    port map(
      clk_i => clk_i,
      rst_i => rst_i,
  
      wb_master_i => wb_masters_i(7),
      wb_master_o => wb_masters_o(7),
      wb_slaves_i => m7_slaves_i,
      wb_slaves_o => m7_slaves_o
    );

  --------------------------------------------------
  --Slave interfaces
  S_GEN: for I in 0 to 14 generate
    SLV: wb_conmax_slave_if
      generic map(
        g_pri_sel => g_pri_sel(I)
      )
      port map(
        clk_i  => clk_i, 
        rst_i  => rst_i,
        conf_i => s_conf(I),
    
        --Slave interface
        wb_slave_i => wb_slaves_i(I),
        wb_slave_o => wb_slaves_o(I),

        --Interfaces to masters
        wb_masters_i(0) => m0_slaves_o(I),
        wb_masters_i(1) => m1_slaves_o(I),
        wb_masters_i(2) => m2_slaves_o(I),
        wb_masters_i(3) => m3_slaves_o(I),
        wb_masters_i(4) => m4_slaves_o(I),
        wb_masters_i(5) => m5_slaves_o(I),
        wb_masters_i(6) => m6_slaves_o(I),
        wb_masters_i(7) => m7_slaves_o(I),
        
        wb_masters_o(0) => m0_slaves_i(I),
        wb_masters_o(1) => m1_slaves_i(I),
        wb_masters_o(2) => m2_slaves_i(I),
        wb_masters_o(3) => m3_slaves_i(I),
        wb_masters_o(4) => m4_slaves_i(I),
        wb_masters_o(5) => m5_slaves_i(I),
        wb_masters_o(6) => m6_slaves_i(I),
        wb_masters_o(7) => m7_slaves_i(I)
      );
  end generate;


  s15_wb_masters_i(0) <= m0_slaves_o(15);
  s15_wb_masters_i(1) <= m1_slaves_o(15);
  s15_wb_masters_i(2) <= m2_slaves_o(15);
  s15_wb_masters_i(3) <= m3_slaves_o(15);
  s15_wb_masters_i(4) <= m4_slaves_o(15);
  s15_wb_masters_i(5) <= m5_slaves_o(15);
  s15_wb_masters_i(6) <= m6_slaves_o(15);
  s15_wb_masters_i(7) <= m7_slaves_o(15);
  
  m0_slaves_i(15) <= s15_wb_masters_o(0);
  m1_slaves_i(15) <= s15_wb_masters_o(1);
  m2_slaves_i(15) <= s15_wb_masters_o(2);
  m3_slaves_i(15) <= s15_wb_masters_o(3);
  m4_slaves_i(15) <= s15_wb_masters_o(4);
  m5_slaves_i(15) <= s15_wb_masters_o(5);
  m6_slaves_i(15) <= s15_wb_masters_o(6);
  m7_slaves_i(15) <= s15_wb_masters_o(7);


  SLV15: wb_conmax_slave_if
    generic map(
      g_pri_sel => g_pri_sel(15)
    )
    port map(
      clk_i  => clk_i, 
      rst_i  => rst_i,
      conf_i => s_conf(15),

      --Slave interface
      wb_slave_i => intwb_s15_i,
      wb_slave_o => intwb_s15_o,

      --Interfaces to masters
      wb_masters_i => s15_wb_masters_i,
      wb_masters_o => s15_wb_masters_o
    );
   
  ---------------------------------------
  --Register File

  RF: wb_conmax_rf
    generic map(
      g_rf_addr => g_rf_addr
    )
    port map(
      clk_i   => clk_i,
      rst_i   => rst_i,
      
      int_wb_i  => intwb_s15_o,
      int_wb_o  => intwb_s15_i,
      ext_wb_i  => wb_slaves_i(15),
      ext_wb_o  => wb_slaves_o(15),
      
      conf_o    => s_conf
    );

end struct;
