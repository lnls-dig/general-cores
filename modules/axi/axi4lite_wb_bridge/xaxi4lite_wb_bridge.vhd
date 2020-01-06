-------------------------------------------------------------------------------
-- Title      : WB-to-AXI4Lite bridge
-- Project    : General Cores
-------------------------------------------------------------------------------
-- File       : xaxi4lite_wb_bridge.vhd
-- Author     : Grzegorz Daniluk
-- Company    : CERN
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description:
--
-- This module is a WB Slave Classic to AXI4-Lite Master bridge.
-------------------------------------------------------------------------------
-- Copyright (c) 2019 CERN
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

use work.axi4_pkg.all;
use work.wishbone_pkg.all;

entity xaxi4lite_wb_bridge is
  port (
    clk_i         : in std_logic;
    rst_n_i       : in std_logic;

    wb_slave_i    : in  t_wishbone_slave_in;
    wb_slave_o    : out t_wishbone_slave_out;

    axi4_master_o : out t_axi4_lite_master_out_32;
    axi4_master_i : in  t_axi4_lite_master_in_32);
end xaxi4lite_wb_bridge;

architecture behav of xaxi4lite_wb_bridge is

  type t_state is (IDLE, READ, WRITE, WB_END);
  signal state : t_state;

begin

  wb_slave_o.stall <= '0';

  process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        wb_slave_o.ack <= '0';
        wb_slave_o.err <= '0';
        axi4_master_o  <= c_axi4_lite_default_master_out_32;

        state <= IDLE;
      else
        case state is

          -------------------------------------------
          when IDLE =>
            wb_slave_o.ack   <= '0';
            wb_slave_o.err <= '0';

            axi4_master_o.ARVALID <= '0';
            axi4_master_o.ARADDR  <= (others=>'X');
            axi4_master_o.RREADY  <= '0';

            axi4_master_o.AWVALID <= '0';
            axi4_master_o.AWADDR  <= (others=>'X');
            axi4_master_o.WVALID  <= '0';
            axi4_master_o.WDATA   <= (others=>'X');
            axi4_master_o.WSTRB   <= "0000";
            axi4_master_o.BREADY  <= '0';

            if wb_slave_i.stb = '1' and wb_slave_i.we = '0' then
              -- AXI: set address for read cycle
              axi4_master_o.ARVALID <= '1';
              axi4_master_o.ARADDR  <= wb_slave_i.adr;
              -- AXI: ready to accept data from slave
              axi4_master_o.RREADY  <= '1';
              state <= READ;
            elsif (wb_slave_i.stb = '1' and wb_slave_i.we = '1') then
              -- AXI: set address for write cycle
              axi4_master_o.AWVALID <= '1';
              axi4_master_o.AWADDR  <= wb_slave_i.adr;
              -- AXI: set data for write cycle
              axi4_master_o.WVALID  <= '1';
              axi4_master_o.WDATA   <= wb_slave_i.dat;
              axi4_master_o.WSTRB   <= wb_slave_i.sel;
              state <= WRITE;
            end if;

          -------------------------------------------
          --            READ CYCLE                 --
          -------------------------------------------
          when READ =>
            wb_slave_o.ack   <= '0';
            wb_slave_o.err <= '0';

            axi4_master_o.RREADY  <= '1';

            if (axi4_master_i.ARREADY = '1') then
              -- AXI: address received by slave
              axi4_master_o.ARVALID <= '0';
            end if;
            if (axi4_master_i.RVALID = '1' and axi4_master_i.RRESP = c_AXI4_RESP_OKAY) then
              -- received valid data, pass it to wishbone
              wb_slave_o.dat <= axi4_master_i.RDATA;
              wb_slave_o.ack <= '1';
              wb_slave_o.err <= '0';
            elsif (axi4_master_i.RVALID = '1') then
              wb_slave_o.ack <= '0';
              wb_slave_o.err <= '1';
            else
              wb_slave_o.ack <= '0';
              wb_slave_o.err <= '0';
            end if;

            if (axi4_master_i.RVALID = '1') then
              axi4_master_o.RREADY <= '0';
              state <= WB_END;
            end if;

          -------------------------------------------
          --            WRITE CYCLE                --
          -------------------------------------------
          when WRITE =>
            wb_slave_o.ack <= '0';
            wb_slave_o.err <= '0';
            axi4_master_o.BREADY <= '1';

            if (axi4_master_i.AWREADY = '1') then
              axi4_master_o.AWVALID <= '0';
            end if;
            if (axi4_master_i.WREADY = '1') then
              axi4_master_o.WVALID <= '0';
            end if;

            if (axi4_master_i.BVALID = '1' and axi4_master_i.BRESP = c_AXI4_RESP_OKAY) then
              wb_slave_o.ack <= '1';
              wb_slave_o.err <= '0';
            elsif (axi4_master_i.BVALID = '1') then
              wb_slave_o.ack <= '0';
              wb_slave_o.err <= '1';
            else
              wb_slave_o.ack <= '0';
              wb_slave_o.err <= '0';
            end if;

            if (axi4_master_i.BVALID = '1') then
              axi4_master_o.BREADY <= '0';
              state <= WB_END;
            end if;

          -------------------------------------------
          when WB_END =>
            wb_slave_o.ack <= '0';
            wb_slave_o.err <= '0';

            -- WB: wait for the cycle to end
            if (wb_slave_i.stb = '0') then
              state <= IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

end behav;
