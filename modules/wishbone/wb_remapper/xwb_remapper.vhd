-------------------------------------------------------------------------------
-- Title      : Wishbone remapper
-- Project    : General cores
-------------------------------------------------------------------------------
-- File       : xwb_remapper.vhd
-- Author     : Tomasz Włostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2014-04-01
-- Last update: 2018-03-23
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description:
--
-- Simple Wishbone bus address remapper. Remaps a certain range of addresses,
-- defined by base address and mask to another base address.
-------------------------------------------------------------------------------
--
-- Copyright (c) 2014 CERN
--
-- This source file is free software; you can redistribute it
-- and/or modify it under the terms of the GNU Lesser General
-- Public License as published by the Free Software Foundation;
-- either version 2.1 of the License, or (at your option) any
-- later version.
--
-- This source is distributed in the hope that it will be
-- useful, but WITHOUT ANY WARRANTY; without even the implied
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
-- PURPOSE.  See the GNU Lesser General Public License for more
-- details.
--
-- You should have received a copy of the GNU Lesser General
-- Public License along with this source; if not, download it
-- from http://www.gnu.org/licenses/lgpl-2.1.html
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.wishbone_pkg.all;

entity xwb_remapper is
  generic (
    g_num_ranges : integer := 1;
    g_base_in    : t_wishbone_address_array;
    g_base_out   : t_wishbone_address_array;
    g_mask_in    : t_wishbone_address_array;
    g_mask_out   : t_wishbone_address_array
    );
  port (
    slave_i  : in  t_wishbone_slave_in;
    slave_o  : out t_wishbone_slave_out;
    master_i : in  t_wishbone_master_in;
    master_o : out t_wishbone_master_out
    );
end xwb_remapper;

architecture rtl of xwb_remapper is
begin
  process(slave_i)
  begin

    master_o <= slave_i;

    for i in 0 to g_num_ranges-1 loop
      if ( (g_mask_in(i) and slave_i.adr ) = g_base_in(i)) then
        master_o.adr <= g_base_out(i) or (slave_i.adr and g_mask_out(i));
      end if;
    end loop;

  end process;

  slave_o <= master_i;                  -- just forward...

end rtl;
