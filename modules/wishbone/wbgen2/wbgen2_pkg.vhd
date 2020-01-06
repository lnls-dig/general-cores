--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://www.ohwr.org/projects/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   wbgen2_pkg
--
-- description: Component declaration for modules used by wbgen2
--
--------------------------------------------------------------------------------
-- Copyright CERN 2011-2018
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

package wbgen2_pkg is

  
  component wbgen2_dpssram
    generic (
      g_data_width : natural;
      g_size       : natural;
      g_addr_width : natural;
      g_dual_clock : boolean;
      g_use_bwsel  : boolean);
    port (
      clk_a_i   : in  std_logic;
      clk_b_i   : in  std_logic;
      addr_a_i  : in  std_logic_vector(g_addr_width-1 downto 0);
      addr_b_i  : in  std_logic_vector(g_addr_width-1 downto 0);
      data_a_i  : in  std_logic_vector(g_data_width-1 downto 0);
      data_b_i  : in  std_logic_vector(g_data_width-1 downto 0);
      data_a_o  : out std_logic_vector(g_data_width-1 downto 0);
      data_b_o  : out std_logic_vector(g_data_width-1 downto 0);
      bwsel_a_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
      bwsel_b_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
      rd_a_i    : in  std_logic;
      rd_b_i    : in  std_logic;
      wr_a_i    : in  std_logic;
      wr_b_i    : in  std_logic);
  end component;


  component wbgen2_eic
    generic (
      g_num_interrupts : natural;
      g_irq00_mode     : integer;
      g_irq01_mode     : integer;
      g_irq02_mode     : integer;
      g_irq03_mode     : integer;
      g_irq04_mode     : integer;
      g_irq05_mode     : integer;
      g_irq06_mode     : integer;
      g_irq07_mode     : integer;
      g_irq08_mode     : integer;
      g_irq09_mode     : integer;
      g_irq0a_mode     : integer;
      g_irq0b_mode     : integer;
      g_irq0c_mode     : integer;
      g_irq0d_mode     : integer;
      g_irq0e_mode     : integer;
      g_irq0f_mode     : integer;
      g_irq10_mode     : integer;
      g_irq11_mode     : integer;
      g_irq12_mode     : integer;
      g_irq13_mode     : integer;
      g_irq14_mode     : integer;
      g_irq15_mode     : integer;
      g_irq16_mode     : integer;
      g_irq17_mode     : integer;
      g_irq18_mode     : integer;
      g_irq19_mode     : integer;
      g_irq1a_mode     : integer;
      g_irq1b_mode     : integer;
      g_irq1c_mode     : integer;
      g_irq1d_mode     : integer;
      g_irq1e_mode     : integer;
      g_irq1f_mode     : integer);
    port (
      rst_n_i          : in  std_logic;
      clk_i            : in  std_logic;
      irq_i            : in  std_logic_vector(g_num_interrupts-1 downto 0);
      irq_ack_o        : out std_logic_vector(g_num_interrupts-1 downto 0);
      reg_imr_o        : out std_logic_vector(g_num_interrupts-1 downto 0);
      reg_ier_i        : in  std_logic_vector(g_num_interrupts-1 downto 0);
      reg_ier_wr_stb_i : in  std_logic;
      reg_idr_i        : in  std_logic_vector(g_num_interrupts-1 downto 0);
      reg_idr_wr_stb_i : in  std_logic;
      reg_isr_o        : out std_logic_vector(g_num_interrupts-1 downto 0);
      reg_isr_i        : in  std_logic_vector(g_num_interrupts-1 downto 0);
      reg_isr_wr_stb_i : in  std_logic;
      wb_irq_o         : out std_logic);
  end component;

  component wbgen2_fifo_async
    generic (
      g_size       : integer;
      g_width      : integer;
      g_usedw_size : integer);
    port (
      rst_n_i    : in  std_logic := '1';
      rd_clk_i   : in  std_logic;
      rd_req_i   : in  std_logic;
      rd_data_o  : out std_logic_vector(g_width-1 downto 0);
      rd_empty_o : out std_logic;
      rd_full_o  : out std_logic;
      rd_usedw_o : out std_logic_vector(g_usedw_size -1 downto 0);
      wr_clk_i   : in  std_logic;
      wr_req_i   : in  std_logic;
      wr_data_i  : in  std_logic_vector(g_width-1 downto 0);
      wr_empty_o : out std_logic;
      wr_full_o  : out std_logic;
      wr_usedw_o : out std_logic_vector(g_usedw_size -1 downto 0));
  end component;


  component wbgen2_fifo_sync
    generic (
      g_width      : integer;
      g_size       : integer;
      g_usedw_size : integer);
    port (
      clk_i      : in  std_logic;
      rst_n_i    : in  std_logic := '1';
      wr_data_i  : in  std_logic_vector(g_width-1 downto 0);
      wr_req_i   : in  std_logic;
      rd_data_o  : out std_logic_vector(g_width-1 downto 0);
      rd_req_i   : in  std_logic;
      wr_empty_o : out std_logic;
      wr_full_o  : out std_logic;
      wr_usedw_o : out std_logic_vector(g_usedw_size -1 downto 0);
      rd_empty_o : out std_logic;
      rd_full_o  : out std_logic;
      rd_usedw_o : out std_logic_vector(g_usedw_size -1 downto 0));
  end component;
  
end wbgen2_pkg;
