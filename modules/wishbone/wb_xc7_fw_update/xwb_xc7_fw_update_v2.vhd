-------------------------------------------------------------------------------
-- Title      : XC7 firmware update
-- Project    : General Cores
-------------------------------------------------------------------------------
-- Note: Contrary to V1, this version doesn't include the STARTUPE2 module
--  so the spi clock port is added.
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

use work.wishbone_pkg.all;

entity xwb_xc7_fw_update_v2 is
  port (
    clk_i           : in std_logic;
    rst_n_i         : in std_logic;

    wb_i                 : in    t_wishbone_slave_in;
    wb_o                 : out   t_wishbone_slave_out;

    flash_cs_n_o         : out  std_logic;
    flash_mosi_o         : out  std_logic;
    flash_miso_i         : in   std_logic;
    flash_sck_o : out std_logic
  );
end xwb_xc7_fw_update_v2;

architecture rtl of xwb_xc7_fw_update_v2 is
  signal far_data_in    : std_logic_vector(7 downto 0);
  signal far_data_out   : std_logic_vector(7 downto 0);
  signal far_xfer_out   : std_logic;
  signal far_ready_in   : std_logic;
  signal far_cs_out     : std_logic;
  signal far_wr_out     : std_logic;

  signal flash_spi_cs      : std_logic;
  signal flash_spi_start   : std_logic;
  signal flash_spi_wdata   : std_logic_vector(7 downto 0);
  signal flash_sclk        : std_logic;
begin
  inst_regs: entity work.wb_xc7_fw_update_regs
    port map (
      clk_i => clk_i,
      rst_n_i => rst_n_i,
      wb_i => wb_i,
      wb_o => wb_o,
      far_data_i => far_data_in,
      far_data_o => far_data_out,
      far_xfer_i => '0',
      far_xfer_o => far_xfer_out,
      far_ready_i => far_ready_in,
      far_ready_o => open,
      far_cs_i => '0',
      far_cs_o => far_cs_out,
      far_wr_o => far_wr_out
    );

  --  Need to capture cs and data_out, and need to delay start.
  p_host_spi_registers : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        flash_spi_start <= '0';
        flash_spi_wdata <= (others => '0');
        flash_spi_cs <= '0';
      elsif far_wr_out = '1' then
        flash_spi_wdata <= far_data_out;
        flash_spi_start <= far_xfer_out;
        flash_spi_cs    <= far_cs_out;
      else
        --  Pulse for start.
        flash_spi_start <= '0';
      end if;
    end if;
  end process;

  U_SPI_Master : entity work.gc_simple_spi_master
    generic map (
      g_div_ratio_log2 => 0,
      g_num_data_bits  => 8)
    port map (
      clk_sys_i  => clk_i,
      rst_n_i    => rst_n_i,
      cs_i       => flash_spi_cs,
      start_i    => flash_spi_start,
      cpol_i     => '0',
      data_i     => flash_spi_wdata,
      ready_o    => far_ready_in,
      data_o     => far_data_in,
      spi_cs_n_o => flash_cs_n_o,
      spi_sclk_o => flash_sclk,
      spi_mosi_o => flash_mosi_o,
      spi_miso_i => flash_miso_i);

  flash_sck_o <= flash_sclk;

end rtl;
