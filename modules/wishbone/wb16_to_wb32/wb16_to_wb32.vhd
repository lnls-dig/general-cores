--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- WR2RF_VME core
-- https://ohwr.org/project/vme-rf-wr-bobr
--------------------------------------------------------------------------------
--
-- unit name:   wb16_to_wb32
--
-- description: Bridge wishbone data width by using a register for the upper 16
--     bits.
--     In order to atomically read a 32 bit word at address ADDR:
--     * read the 16 LSB word at address ADDR
--     * read the 16 MSB word at address ADDR+2
--     In order to atomically write a 32 bit word at address ADDR:
--     * write the 16 MSB word at address ADDR+2
--     * write the 16 LSB word at address ADDR
--
--------------------------------------------------------------------------------
-- Copyright (c) 2019 CERN (home.cern)
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

use work.wishbone_pkg.all;

entity wb16_to_wb32 is
  port (
    clk_i   : in  std_logic;
    rst_n_i : in  std_logic;

    wb16_i  : in    t_wishbone_slave_in;
    wb16_o  : out   t_wishbone_slave_out;

    wb32_i  : in    t_wishbone_master_in;
    wb32_o  : out   t_wishbone_master_out
  );
end;

architecture arch of wb16_to_wb32 is
  signal datah : std_logic_vector(15 downto 0);
  signal stall : std_logic;
  signal we : std_logic;
  signal ack : std_logic;
begin
  wb16_o.stall <= stall or ack;
  wb32_o.dat (31 downto 16) <= datah;
  wb16_o.rty <= '0';
  wb16_o.err <= '0';
  wb16_o.ack <= ack;

  process (clk_i) is
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        datah <= (others => '0');
        stall <= '0';
        ack <= '0';
        wb32_o.cyc <= '0';
        wb32_o.stb <= '0';
      else
        if stall = '0' then
          --  Ready.
          ack <= '0';
          if wb16_i.stb = '1' and wb16_i.cyc = '1' and ack = '0' then
            if wb16_i.adr(1) = '1' then
              --  Access to DATAH.
              if wb16_i.we = '1' then
                --  Write.
                if wb16_i.sel(0) = '1' then
                  datah (7 downto 0) <= wb16_i.dat(7 downto 0);
                end if;
                if wb16_i.sel(1) = '1' then
                  datah (15 downto 8) <= wb16_i.dat(15 downto 8);
                end if;
              else
                --  Read
                wb16_o.dat(15 downto 0) <= datah;
              end if;
              ack <= '1';
            else
              --  Access to the device.
              stall <= '1';
              we <= wb16_i.we;
              wb32_o.cyc <= '1';
              wb32_o.stb <= '1';
              wb32_o.adr <= wb16_i.adr(31 downto 2) & "00";
              wb32_o.dat (15 downto 0) <= wb16_i.dat(15 downto 0);
              wb32_o.we <= wb16_i.we;
              wb32_o.sel <= "11" & wb16_i.sel (1 downto 0);  --  Humm...
            end if;
          end if;
        else
          --  Stall = 1, waiting for the answer.
          if wb32_i.ack = '1' then
            wb16_o.dat (15 downto 0) <= wb32_i.dat (15 downto 0);
            if we = '0' then
              datah <= wb32_i.dat (31 downto 16);
            end if;
            wb32_o.cyc <= '0';
            wb32_o.stb <= '0';
            ack <= '1';
            stall <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;
end arch;
