--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- xwb_split
-- https://gitlab.com/ohwr/project/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_split
--
-- description: A simple wishbone spliter (a crossbar with 1 master and 2 slaves).
-- note: Slaves addresses are not remapped.
--
--------------------------------------------------------------------------------
-- Copyright CERN 2019
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
use ieee.numeric_std.all;

use work.gencores_pkg.all;
use work.wishbone_pkg.all;

entity xwb_split is
  generic (
    --  Bits that must be considered to select the slave.
    --  When the bits in the address corresponding to the 1 in the mask
    --  are 0, slave 0 is selected.
    g_MASK : std_logic_vector(31 downto 0)
  );
  port (
    clk_sys_i : in  std_logic;
    rst_n_i   : in  std_logic;

    --  Registered pipeline wishbone.  If the address and mask is 0, the transaction is
    --  directed to master 0 else to master 1.  The address is not modified.
    slave_i   : in  t_wishbone_slave_in;
    slave_o   : out t_wishbone_slave_out;

    --  Registered pipeline wishbone.
    master_i  : in  t_wishbone_master_in_array(1 downto 0);
    master_o  : out t_wishbone_master_out_array(1 downto 0));
end entity xwb_split;

architecture top of xwb_split is
  type t_ca_state is (S_IDLE, S_CONN);
  signal ca_state : t_ca_state;
  signal slave_num : natural range 0 to 1;
  signal can_stall : std_logic;
begin
  --  Mini-crossbar from gennum to carrier and application bus.
  carrier_app_xb: process (clk_sys_i)
  is
    constant c_IDLE_WB_MASTER_IN : t_wishbone_master_in :=
      (ack => '0', err => '0', rty => '0', stall => '0', dat => c_DUMMY_WB_DATA);
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        ca_state <= S_IDLE;
        slave_o  <= c_IDLE_WB_MASTER_IN;
        master_o <= (0 | 1 => c_DUMMY_WB_MASTER_OUT);
      else
        case ca_state is
          when S_IDLE =>
            -- No transaction when idle.
            slave_o  <= c_IDLE_WB_MASTER_IN;
            master_o <= (0 | 1 => c_DUMMY_WB_MASTER_OUT);
            if slave_i.cyc = '1' and slave_i.stb = '1' then
              -- New transaction.
              -- Stall so that there is no new requests from the master.
              -- We can only accept one transaction at a time, because a new one
              -- can go in the other master which will require re-ordering of the
              -- replies.
              slave_o.stall <= '1';
              can_stall     <= '1';
              ca_state <= S_CONN;
              -- Select master and pass the transaction.
              if (slave_i.adr and g_MASK) = (31 downto 0 => '0') then
                slave_num <= 0;
                master_o(0) <= slave_i;
              else
                slave_num <= 1;
                master_o(1) <= slave_i;
              end if;
            end if;
          when S_CONN =>
            -- Maintain strobe as long as the master doesn't accept it (stalling).
            -- Must not set strobe once the transaction has started.
            master_o (slave_num).stb <= master_i (slave_num).stall and can_stall;
            can_stall <= can_stall and master_i (slave_num).stall;
            -- Pass the result from the master, but maintain stall (as we don't want
            -- to accept new requests).
            slave_o <= master_i (slave_num);
            slave_o.stall <= '1';
            -- Check for end of transaction.
            if master_i (slave_num).ack = '1' or master_i (slave_num).err = '1' then
              ca_state <= S_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process carrier_app_xb;
end architecture top;
