-------------------------------------------------------------------------------
-- Title      : Wishbone interconnect matrix for WR Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wbconmax_pkg.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-02-16
-- Last update: 2011-09-12
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- Package for WB interconnect matrix. Defines basic constants and types used
-- to simplify WB interface connections.
-------------------------------------------------------------------------------
-- Copyright (c) 2011 Grzegorz Daniluk
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-02-16  1.1      greg.d          Using generates and types
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package wbconmax_pkg is

  type t_conmax_rf_conf  is array(0 to 15) of std_logic_vector(15 downto 0);
  type t_conmax_pri_sel is array(0 to 15) of integer range 0 to 3;  

  constant c_conmax_default_pri_sel : t_conmax_pri_sel := (2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2);  

end wbconmax_pkg;
