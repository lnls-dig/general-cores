-------------------------------------------------------------------------------
-- Title      : Wishbone interconnect matrix for WR Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wbconmax_pkg.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-02-16
-- Last update: 2010-02-16
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

  type t_rf_conf  is array(0 to 15) of std_logic_vector(15 downto 0);

  constant c_dw : integer := 32;  --data width
  constant c_aw : integer := 18;  --address width = max 14b (for dpram) + 4b 
                                  --for wb_intercom (Mst selects Slave)
  constant c_sw : integer := 4;   -- c_dw/8

  --g_pri_selx := 0 (1 priority level), 1 (2 pri levels) or 2 (4 pri levels).
  type t_pri_sels is array(0 to 15) of integer range 0 to 3;  
  constant g_pri_sel : t_pri_sels := (2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2);  

  --as in original WB conmax spec and implementation, those are
  --inputs fed by WB Master from outside 
  type t_wb_i is record
    data  : std_logic_vector(c_dw-1 downto 0);
    addr  : std_logic_vector(c_aw-1 downto 0);
    sel   : std_logic_vector(c_sw-1 downto 0);
    we    : std_logic;
    cyc   : std_logic;
    stb   : std_logic;
  end record;

  type t_wb_o is record
    data  : std_logic_vector(c_dw-1 downto 0);
    ack   : std_logic;
    err   : std_logic;
    rty   : std_logic;
  end record;

  type t_conmax_masters_i is array(0 to 7) of t_wb_i;
  type t_conmax_masters_o is array(0 to 7) of t_wb_o;
  type t_conmax_slaves_i  is array(0 to 15) of t_wb_o;
  type t_conmax_slaves_o  is array(0 to 15) of t_wb_i;

end wbconmax_pkg;
