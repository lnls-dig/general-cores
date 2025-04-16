--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://gitlab.com/ohwr/project/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   xwb_metadata
--
-- description: Provide metadata for the 'convention'.  This is just a little
-- ROM.
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

library work;
use work.wishbone_pkg.all;

entity xwb_metadata is
  generic (
    --  The vendor ID.  Official PCI VID are valid.
    --  The default is the CERN PCI VID.
    g_VENDOR_ID  : std_logic_vector(31 downto 0) := x"000010dc";
    --  Device ID, defined by the vendor.
    g_DEVICE_ID  : std_logic_vector(31 downto 0);
    --  Version (semantic version).
    g_VERSION    : std_logic_vector(31 downto 0);
    --  Capabilities.  Specific to the device.
    g_CAPABILITIES : std_logic_vector(31 downto 0);
    --  Git commit ID.
    g_COMMIT_ID    : std_logic_vector(127 downto 0)
    );
  port (
    clk_i   : in  std_logic;
    rst_n_i : in std_logic;
    wb_i    : in  t_wishbone_slave_in;
    wb_o    : out t_wishbone_slave_out
    );
end xwb_metadata;

architecture rtl of xwb_metadata is
  signal busy : std_logic;
begin
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        busy <= '0';
        wb_o <= (stall | ack | rty | err => '0', dat => (others => 'X'));
      else
        busy <= '0';
        wb_o <= (stall | ack | rty | err => '0', dat => (others => 'X'));
        if busy = '0' and wb_i.cyc = '1' and wb_i.stb = '1' then
          wb_o.ack <= '1';
          --  Be compatible with both classic and pipelined WB, and be registered.
          --  So, reply immediately but be sure the ack will be negated for at least one
          --  cycle (classic).  Because of that, stall for one cycle (pipelined).
          wb_o.stall <= '1';
          busy <= '1';

          case wb_i.adr(5 downto 2) is
          when x"0" =>
            --  Vendor ID
            wb_o.dat <= g_VENDOR_ID;
          when x"1" =>
            --  Device ID
            wb_o.dat <= g_DEVICE_ID;
          when x"2" =>
            -- Version
            wb_o.dat <= g_VERSION;
          when x"3" =>
            -- BOM
            wb_o.dat <= x"fffe0000";
          when x"4" =>
            -- source id
            wb_o.dat <= g_COMMIT_ID(127 downto 96);
          when x"5" =>
            wb_o.dat <= g_COMMIT_ID(95 downto 64);
          when x"6" =>
            wb_o.dat <= g_COMMIT_ID(63 downto 32);
          when x"7" =>
            wb_o.dat <= g_COMMIT_ID(31 downto 0);
          when x"8" =>
            -- capability mask
            wb_o.dat <= g_CAPABILITIES;
          when others =>
            wb_o.dat <= x"00000000";
          end case;
        end if;
      end if;
    end if;
  end process;
end rtl;
