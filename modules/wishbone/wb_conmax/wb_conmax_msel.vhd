-------------------------------------------------------------------------------
-- Title      : Wishbone interconnect matrix for WR Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_conmax_msel.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-02-12
-- Last update: 2010-02-12
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- Prioritizing arbiter for Slave interface. Uses simple arbitrer 
-- (wb_conmax_arb) and takes Master's priorities into account.
-- 
-------------------------------------------------------------------------------
-- Copyright (C) 2000-2002 Rudolf Usselmann
-- Copyright (c) 2011 Grzegorz Daniluk (VHDL port)
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-02-12  1.0      greg.d          Created
-------------------------------------------------------------------------------
-- TODO:
-- Code optimization. (now it is more like dummy translation from Verilog)
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity wb_conmax_msel is
  generic(
    g_pri_sel : integer := 0
  );
  port(
    clk_i : in std_logic;
    rst_i : in std_logic;
    
    conf_i  : in std_logic_vector(15 downto 0);
    req_i   : in std_logic_vector(7 downto 0);
    next_i  : in std_logic;
    
    sel     : out std_logic_vector(2 downto 0)
  );
end wb_conmax_msel;

architecture behavioral of wb_conmax_msel is

  component wb_conmax_pri_enc is
  generic(
    -- :=1 means 2 priority levels, :=2 means 4 priority levels
    g_pri_sel : integer := 0
  );
  port(
    valid_i : in std_logic_vector(7 downto 0);

    pri0_i  : in std_logic_vector(1 downto 0);
    pri1_i  : in std_logic_vector(1 downto 0);
    pri2_i  : in std_logic_vector(1 downto 0);
    pri3_i  : in std_logic_vector(1 downto 0);
    pri4_i  : in std_logic_vector(1 downto 0);
    pri5_i  : in std_logic_vector(1 downto 0);
    pri6_i  : in std_logic_vector(1 downto 0);
    pri7_i  : in std_logic_vector(1 downto 0);

    pri_o   : out std_logic_vector(1 downto 0)
  );
  end component;

  component wb_conmax_arb is
    port(
      clk_i : in std_logic;
      rst_i : in std_logic;
  
      req_i : in std_logic_vector(7 downto 0);
      gnt_o : out std_logic_vector(2 downto 0);
  
      next_i  : in std_logic
    );
  end component;


  signal s_pri0, s_pri1, s_pri2, s_pri3, s_pri4,
         s_pri5, s_pri6, s_pri7 : std_logic_vector(1 downto 0);
 
  signal s_pri_out_d, s_pri_out : std_logic_vector(1 downto 0);
  signal s_req_p0, s_req_p1, s_req_p2, s_req_p3 : std_logic_vector(7 downto 0);
  signal s_gnt_p0, s_gnt_p1, s_gnt_p2, s_gnt_p3 : std_logic_vector(2 downto 0);
  signal s_sel1, s_sel2 : std_logic_vector(2 downto 0);
  
begin

  --------------------------------------
  --Priority Select logic
  G1: if(g_pri_sel=0) generate
    s_pri0 <= "00";
    s_pri1 <= "00";
    s_pri2 <= "00";
    s_pri3 <= "00";
    s_pri4 <= "00";
    s_pri5 <= "00";
    s_pri6 <= "00";
    s_pri7 <= "00";
  end generate;

  G2: if(g_pri_sel=2) generate
    s_pri0 <= conf_i(1 downto 0);
    s_pri1 <= conf_i(3 downto 2);
    s_pri2 <= conf_i(5 downto 4);
    s_pri3 <= conf_i(7 downto 6);
    s_pri4 <= conf_i(9 downto 8);
    s_pri5 <= conf_i(11 downto 10);
    s_pri6 <= conf_i(13 downto 12);
    s_pri7 <= conf_i(15 downto 14);
  end generate;

  G3: if(g_pri_sel/=0 and g_pri_sel/=2) generate
    s_pri0 <= '0' & conf_i(0);
    s_pri1 <= '0' & conf_i(2); 
    s_pri2 <= '0' & conf_i(4); 
    s_pri3 <= '0' & conf_i(6); 
    s_pri4 <= '0' & conf_i(8); 
    s_pri5 <= '0' & conf_i(10); 
    s_pri6 <= '0' & conf_i(12); 
    s_pri7 <= '0' & conf_i(14); 
  end generate;
  
  PRI_ENC: wb_conmax_pri_enc
    generic map(
      -- :=1 means 2 priority levels, :=2 means 4 priority levels
      g_pri_sel => g_pri_sel
    )
    port map(
      valid_i => req_i,
  
      pri0_i  => s_pri0, 
      pri1_i  => s_pri1, 
      pri2_i  => s_pri2, 
      pri3_i  => s_pri3, 
      pri4_i  => s_pri4, 
      pri5_i  => s_pri5, 
      pri6_i  => s_pri6, 
      pri7_i  => s_pri7, 
  
      pri_o   => s_pri_out_d
    );

  
  process(clk_i)
  begin
    if(clk_i'event and clk_i='1') then
      if(rst_i = '1') then
        s_pri_out <= "00";
      elsif(next_i = '1') then
        s_pri_out <= s_pri_out_d;
      end if;
    end if;
  end process;


  -----------------------------------------------
  --Arbiters
  s_req_p0(0) <= req_i(0) when(s_pri0 = "00") else '0';
  s_req_p0(1) <= req_i(1) when(s_pri1 = "00") else '0';
  s_req_p0(2) <= req_i(2) when(s_pri2 = "00") else '0';
  s_req_p0(3) <= req_i(3) when(s_pri3 = "00") else '0';
  s_req_p0(4) <= req_i(4) when(s_pri4 = "00") else '0';
  s_req_p0(5) <= req_i(5) when(s_pri5 = "00") else '0';
  s_req_p0(6) <= req_i(6) when(s_pri6 = "00") else '0';
  s_req_p0(7) <= req_i(7) when(s_pri7 = "00") else '0';
  
  s_req_p1(0) <= req_i(0) when(s_pri0 = "01") else '0';
  s_req_p1(1) <= req_i(1) when(s_pri1 = "01") else '0';
  s_req_p1(2) <= req_i(2) when(s_pri2 = "01") else '0';
  s_req_p1(3) <= req_i(3) when(s_pri3 = "01") else '0';
  s_req_p1(4) <= req_i(4) when(s_pri4 = "01") else '0';
  s_req_p1(5) <= req_i(5) when(s_pri5 = "01") else '0';
  s_req_p1(6) <= req_i(6) when(s_pri6 = "01") else '0';
  s_req_p1(7) <= req_i(7) when(s_pri7 = "01") else '0';
  
  s_req_p2(0) <= req_i(0) when(s_pri0 = "10") else '0';
  s_req_p2(1) <= req_i(1) when(s_pri1 = "10") else '0';
  s_req_p2(2) <= req_i(2) when(s_pri2 = "10") else '0';
  s_req_p2(3) <= req_i(3) when(s_pri3 = "10") else '0';
  s_req_p2(4) <= req_i(4) when(s_pri4 = "10") else '0';
  s_req_p2(5) <= req_i(5) when(s_pri5 = "10") else '0';
  s_req_p2(6) <= req_i(6) when(s_pri6 = "10") else '0';
  s_req_p2(7) <= req_i(7) when(s_pri7 = "10") else '0';
  
  s_req_p3(0) <= req_i(0) when(s_pri0 = "11") else '0';
  s_req_p3(1) <= req_i(1) when(s_pri1 = "11") else '0';
  s_req_p3(2) <= req_i(2) when(s_pri2 = "11") else '0';
  s_req_p3(3) <= req_i(3) when(s_pri3 = "11") else '0';
  s_req_p3(4) <= req_i(4) when(s_pri4 = "11") else '0';
  s_req_p3(5) <= req_i(5) when(s_pri5 = "11") else '0';
  s_req_p3(6) <= req_i(6) when(s_pri6 = "11") else '0';
  s_req_p3(7) <= req_i(7) when(s_pri7 = "11") else '0';

  ARB0: wb_conmax_arb 
    port map(
      clk_i  => clk_i,
      rst_i  => rst_i,
  
      req_i  => s_req_p0,
      gnt_o  => s_gnt_p0,
  
      next_i => '0'
    );

  ARB1: wb_conmax_arb 
    port map(
      clk_i  => clk_i,
      rst_i  => rst_i,
  
      req_i  => s_req_p1,
      gnt_o  => s_gnt_p1,
  
      next_i => '0'
    );

  ARB2: wb_conmax_arb 
    port map(
      clk_i  => clk_i,
      rst_i  => rst_i,
  
      req_i  => s_req_p2,
      gnt_o  => s_gnt_p2,
  
      next_i => '0'
    );

  ARB3: wb_conmax_arb 
    port map(
      clk_i  => clk_i,
      rst_i  => rst_i,
  
      req_i  => s_req_p3,
      gnt_o  => s_gnt_p3,
  
      next_i => '0'
    );

  -----------------------------------------------
  --Final Master Select
  s_sel1 <= s_gnt_p1 when( s_pri_out(0)='1' ) else
            s_gnt_p0;

  s_sel2 <= s_gnt_p0 when( s_pri_out="00" ) else
            s_gnt_p1 when( s_pri_out="01" ) else
            s_gnt_p2 when( s_pri_out="10" ) else
            s_gnt_p3;

  G4: if(g_pri_sel=0) generate
    sel <= s_gnt_p0;
  end generate;
  
  G5: if(g_pri_sel=1) generate
    sel <= s_sel1;
  end generate;

  G6: if(g_pri_sel/=0 and g_pri_sel/=1) generate
    sel <= s_sel2;
  end generate;

end behavioral;
