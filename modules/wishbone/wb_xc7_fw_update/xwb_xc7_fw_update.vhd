-------------------------------------------------------------------------------
-- Title      : XC7 firmware update
-- Project    : General Cores
-------------------------------------------------------------------------------
-- Note: The spi clock is directly connected to the STARTUPE2 module, so it
--  doesn't appear as an output.
-------------------------------------------------------------------------------
-- Copyright (c) 2020-2021 CERN
--
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 0.51 (the "License") (which enables you, at your option,
-- to treat this file as licensed under the Apache License 2.0); you may not
-- use this file except in compliance with the License. You may obtain a copy
-- of the License at http://solderpad.org/licenses/SHL-0.51.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

use work.wishbone_pkg.all;

entity xwb_xc7_fw_update is
  port (
    clk_i           : in std_logic;
    rst_n_i         : in std_logic;

    wb_i                 : in    t_wishbone_slave_in;
    wb_o                 : out   t_wishbone_slave_out;

    flash_cs_n_o         : out  std_logic;
    flash_mosi_o         : out  std_logic;
    flash_miso_i         : in   std_logic
  );
end xwb_xc7_fw_update;

architecture rtl of xwb_xc7_fw_update is
  signal flash_sclk        : std_logic;
begin
  i_inst: entity work.xwb_xc7_fw_update_v2
    port map (
      clk_i  => clk_i,
      rst_n_i => rst_n_i,
      wb_i  => wb_i,
      wb_o  => wb_o,
      flash_cs_n_o => flash_cs_n_o,
      flash_mosi_o => flash_mosi_o,
      flash_miso_i => flash_miso_i,
      flash_sck_o  => flash_sclk);

  STARTUPE2_inst : STARTUPE2
    generic map (
      PROG_USR => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
      SIM_CCLK_FREQ => 0.0  -- Set the Configuration Clock Frequency(ns) for simulation.
    )
    port map (
      CFGCLK => open,   -- 1-bit output: Configuration main clock output
      CFGMCLK => open,  -- 1-bit output: Configuration internal oscillator clock output
      EOS => open,      -- 1-bit output: Active high output signal indicating the End Of Startup.
      PREQ => open,     -- 1-bit output: PROGRAM request to fabric output
      CLK => '0',       -- 1-bit input: User start-up clock input
      GSR => '0',       -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
      GTS => '0',       -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
      KEYCLEARB => '0', -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
      PACK => '0',      -- 1-bit input: PROGRAM acknowledge input
      USRCCLKO => flash_sclk,   -- 1-bit input: User CCLK input
      USRCCLKTS => '0', -- 1-bit input: User CCLK 3-state enable input
      USRDONEO => '0',  -- 1-bit input: User DONE pin output control
      USRDONETS => '1'  -- 1-bit input: User DONE 3-state enable output
    );
end rtl;
