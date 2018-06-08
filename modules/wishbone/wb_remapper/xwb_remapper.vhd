--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_remapper
--
-- description: Simple Wishbone bus address remapper. Remaps a certain range
-- of addresses defined by base address and mask to another base address.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2014-2018
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

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
