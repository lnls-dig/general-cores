-------------------------------------------------------------------------------
-- Title      : Wishbone interconnect matrix for WR Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_conmax_pri_enc.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-02-12
-- Last update: 2010-02-12
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- The set of priority encoders for all Master interfaces.
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

entity wb_conmax_pri_enc is
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
end wb_conmax_pri_enc;

architecture behaviour of wb_conmax_pri_enc is

  component wb_conmax_pri_dec is
    generic(
      -- :=1 means 2 priority levels, :=2 means 4 priority levels
      g_pri_sel : integer := 0
    );
    port(
      valid_i : in std_logic;
      pri_i   : in std_logic_vector(1 downto 0);
      pri_o   : out std_logic_vector(3 downto 0)
    );
  end component;

  signal s_pri0_o : std_logic_vector(3 downto 0);
  signal s_pri1_o : std_logic_vector(3 downto 0);
  signal s_pri2_o : std_logic_vector(3 downto 0);
  signal s_pri3_o : std_logic_vector(3 downto 0);
  signal s_pri4_o : std_logic_vector(3 downto 0);
  signal s_pri5_o : std_logic_vector(3 downto 0);
  signal s_pri6_o : std_logic_vector(3 downto 0);
  signal s_pri7_o : std_logic_vector(3 downto 0);

  signal s_pritmp_o : std_logic_vector(3 downto 0);

  signal s_pri_out0 : std_logic_vector(1 downto 0);
  signal s_pri_out1 : std_logic_vector(1 downto 0);


begin

  PD0: wb_conmax_pri_dec
    generic map( 
      g_pri_sel => g_pri_sel
    )
    port map(
      valid_i => valid_i(0),
      pri_i   => pri0_i,
      pri_o   => s_pri0_o
    );
 
  PD1: wb_conmax_pri_dec
    generic map( 
      g_pri_sel => g_pri_sel
    )
    port map(
      valid_i => valid_i(1),
      pri_i   => pri1_i,
      pri_o   => s_pri1_o
    );

  PD2: wb_conmax_pri_dec
    generic map( 
      g_pri_sel => g_pri_sel
    )
    port map(
      valid_i => valid_i(2),
      pri_i   => pri2_i,
      pri_o   => s_pri2_o
    );

  PD3: wb_conmax_pri_dec
    generic map( 
      g_pri_sel => g_pri_sel
    )
    port map(
      valid_i => valid_i(3),
      pri_i   => pri3_i,
      pri_o   => s_pri3_o
    );

  PD4: wb_conmax_pri_dec
    generic map( 
      g_pri_sel => g_pri_sel
    )
    port map(
      valid_i => valid_i(4),
      pri_i   => pri4_i,
      pri_o   => s_pri4_o
    );
 
  PD5: wb_conmax_pri_dec
    generic map( 
      g_pri_sel => g_pri_sel
    )
    port map(
      valid_i => valid_i(5),
      pri_i   => pri5_i,
      pri_o   => s_pri5_o
    );

  PD6: wb_conmax_pri_dec
    generic map( 
      g_pri_sel => g_pri_sel
    )
    port map(
      valid_i => valid_i(6),
      pri_i   => pri6_i,
      pri_o   => s_pri6_o
    );

  PD7: wb_conmax_pri_dec
    generic map( 
      g_pri_sel => g_pri_sel
    )
    port map(
      valid_i => valid_i(7),
      pri_i   => pri7_i,
      pri_o   => s_pri7_o
    );


  s_pritmp_o <= s_pri0_o or s_pri1_o or s_pri2_o or s_pri3_o or s_pri4_o or
                s_pri5_o or s_pri6_o or s_pri7_o;

  --4 priority levels
  s_pri_out1 <= "11" when ( s_pritmp_o(3)='1' ) else
                "10" when ( s_pritmp_o(2)='1' ) else
                "01" when ( s_pritmp_o(1)='1' ) else
                "00";

  --2 priority levels
  s_pri_out0 <= "01" when ( s_pritmp_o(1)='1' ) else
                "00";



  G1: if (g_pri_sel=0) generate
    pri_o <= "00";
  end generate;
  G2: if (g_pri_sel=1) generate
    pri_o <= s_pri_out0;
  end generate;
  G3: if (g_pri_sel/=0 and g_pri_sel/=1) generate 
    pri_o <= s_pri_out1;
  end generate;


end behaviour;


