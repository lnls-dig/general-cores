-------------------------------------------------------------------------------
-- Title      : Wishbone interconnect matrix for WR Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_conmax_pri_dec.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-02-12
-- Last update: 2010-02-12
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- Simple Master's priority encoder
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
-- (eg. <if..generate> instead of pri_out_d0 and pri_out_d1)
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity wb_conmax_pri_dec is
  generic(
    -- :=1 means 2 priority levels, :=2 means 4 priority levels
    g_pri_sel : integer := 0
  );
  port(
    valid_i : in std_logic;
    pri_i   : in std_logic_vector(1 downto 0);
    pri_o   : out std_logic_vector(3 downto 0)
  );
end wb_conmax_pri_dec;

architecture behaviour of wb_conmax_pri_dec is

  signal pri_out_d0 : std_logic_vector(3 downto 0);
  signal pri_out_d1 : std_logic_vector(3 downto 0);

begin

  --4 priority levels
  process(valid_i,pri_i)
  begin
    if( valid_i='0' ) then
      pri_out_d1 <= "0001";
    elsif( pri_i="00" ) then
      pri_out_d1 <= "0001";
    elsif( pri_i="01" ) then
      pri_out_d1 <= "0010";
    elsif( pri_i="10" ) then
      pri_out_d1 <= "0100";
    else
      pri_out_d1 <= "1000";
    end if;
  end process;

  --2 priority levels
  process(valid_i, pri_i)
  begin
    if( valid_i='0' ) then
      pri_out_d0 <= "0001";
    elsif( pri_i="00" ) then
      pri_out_d0 <= "0001";
    else
      pri_out_d0 <= "0010";
    end if;
  end process;

  --select how many pririty levels
  G1: if(g_pri_sel=0) generate
    pri_o <= "0000";
  end generate;
  G2: if(g_pri_sel=1) generate
    pri_o <= pri_out_d0;
  end generate;
  G3: if(g_pri_sel/=0 and g_pri_sel/=1) generate
    pri_o <= pri_out_d1;
  end generate;

end behaviour;
