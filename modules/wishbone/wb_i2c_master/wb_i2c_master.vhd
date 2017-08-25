------------------------------------------------------------------------------
-- Title      : Wishbone I2C Master
-- Project    : General Core Collection (gencores) Library
------------------------------------------------------------------------------
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-05-18
-- Last update: 2013-09-09
-- Platform   : FPGA-generic
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: A Wishbone I2C Master core.
-- 
-------------------------------------------------------------------------------
-- wb_i2c_master.vhd Copyright (c) 2010 CERN
--
-- Uses I2C core from: http://www.opencores.org/projects/i2c/   
-- Copyright (C) 2000 Richard Herveille <richard@asics.ws>
-- See i2c_master_top.vhd for the licensing terms.
--
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2010-05-18  1.0      twlostow        Created
-- 2010-10-04  1.1      twlostow        Added WB slave adapter
-- 2013-09-09  1.2      greg.d          Multiplexing multiple i2c interfaces
-- 2016-08-24  1.3      jpospisi        added assignments to (new) unspecified
--                                        WB signals
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.wishbone_pkg.all;

entity wb_i2c_master is
  generic (
    g_interface_mode      : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity : t_wishbone_address_granularity := WORD;
    g_num_interfaces      : integer := 1);
  port (
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    wb_adr_i   : in  std_logic_vector(4 downto 0);
    wb_dat_i   : in  std_logic_vector(31 downto 0);
    wb_dat_o   : out std_logic_vector(31 downto 0);
    wb_sel_i   : in  std_logic_vector(3 downto 0);
    wb_stb_i   : in  std_logic;
    wb_cyc_i   : in  std_logic;
    wb_we_i    : in  std_logic;
    wb_ack_o   : out std_logic;
    wb_int_o   : out std_logic;
    wb_stall_o : out std_logic;

    scl_pad_i    : in  std_logic_vector(g_num_interfaces-1 downto 0);  -- i2c clock line input
    scl_pad_o    : out std_logic_vector(g_num_interfaces-1 downto 0);  -- i2c clock line output
    scl_padoen_o : out std_logic_vector(g_num_interfaces-1 downto 0);  -- i2c clock line output enable, active low
    sda_pad_i    : in  std_logic_vector(g_num_interfaces-1 downto 0);  -- i2c data line input
    sda_pad_o    : out std_logic_vector(g_num_interfaces-1 downto 0);  -- i2c data line output
    sda_padoen_o : out std_logic_vector(g_num_interfaces-1 downto 0)   -- i2c data line output enable, active low
    );
end wb_i2c_master;

architecture rtl of wb_i2c_master is
  component i2c_master_top
    generic (
      ARST_LVL : std_logic;
      g_num_interfaces  : integer := 1);
    port (
      wb_clk_i     : in  std_logic;
      wb_rst_i     : in  std_logic := '0';
      arst_i       : in  std_logic := not ARST_LVL;
      wb_adr_i     : in  std_logic_vector(2 downto 0);
      wb_dat_i     : in  std_logic_vector(7 downto 0);
      wb_dat_o     : out std_logic_vector(7 downto 0);
      wb_we_i      : in  std_logic;
      wb_stb_i     : in  std_logic;
      wb_cyc_i     : in  std_logic;
      wb_ack_o     : out std_logic;
      wb_inta_o    : out std_logic;
      scl_pad_i    : in  std_logic_vector(g_num_interfaces-1 downto 0);
      scl_pad_o    : out std_logic_vector(g_num_interfaces-1 downto 0);
      scl_padoen_o : out std_logic_vector(g_num_interfaces-1 downto 0);
      sda_pad_i    : in  std_logic_vector(g_num_interfaces-1 downto 0);
      sda_pad_o    : out std_logic_vector(g_num_interfaces-1 downto 0);
      sda_padoen_o : out std_logic_vector(g_num_interfaces-1 downto 0));
  end component;

  signal dat_out : std_logic_vector(7 downto 0);
  signal rst     : std_logic;

  signal wb_in  : t_wishbone_slave_in;
  signal wb_out : t_wishbone_slave_out;

  signal resized_addr : std_logic_vector(c_wishbone_address_width-1 downto 0);
begin

  resized_addr(4 downto 0)                          <= wb_adr_i;
  resized_addr(c_wishbone_address_width-1 downto 5) <= (others => '0');

  U_Adapter : wb_slave_adapter
    generic map (
      g_master_use_struct  => true,
      g_master_mode        => CLASSIC,
      g_master_granularity => WORD,
      g_slave_use_struct   => false,
      g_slave_mode         => g_interface_mode,
      g_slave_granularity  => g_address_granularity)
    port map (
      clk_sys_i  => clk_sys_i,
      rst_n_i    => rst_n_i,
      master_i   => wb_out,
      master_o   => wb_in,
      sl_adr_i   => resized_addr,
      sl_dat_i   => wb_dat_i,
      sl_sel_i   => wb_sel_i,
      sl_cyc_i   => wb_cyc_i,
      sl_stb_i   => wb_stb_i,
      sl_we_i    => wb_we_i,
      sl_dat_o   => wb_dat_o,
      sl_ack_o   => wb_ack_o,
      sl_stall_o => wb_stall_o,
      sl_int_o   => wb_int_o);

  rst <= not rst_n_i;

  Wrapped_I2C : i2c_master_top
    generic map (
      ARST_LVL          => '0',
      g_num_interfaces  => g_num_interfaces)
    port map (
      wb_clk_i     => clk_sys_i,
      wb_rst_i     => rst,
      arst_i       => '1',
      wb_adr_i     => wb_in.adr(2 downto 0),
      wb_dat_i     => wb_in.dat(7 downto 0),
      wb_dat_o     => dat_out,
      wb_we_i      => wb_in.we,
      wb_stb_i     => wb_in.stb,
      wb_cyc_i     => wb_in.cyc,
      wb_ack_o     => wb_out.ack,
      wb_inta_o    => wb_out.int,
      scl_pad_i    => scl_pad_i,
      scl_pad_o    => scl_pad_o,
      scl_padoen_o => scl_padoen_o,
      sda_pad_i    => sda_pad_i,
      sda_pad_o    => sda_pad_o,
      sda_padoen_o => sda_padoen_o);

  wb_out.dat(7 downto 0)                <= dat_out;
  wb_out.dat(wb_out.dat'left downto 8) <= (others => '0');

  wb_out.err <= '0';
  wb_out.rty <= '0';
  wb_out.stall <= '0';

end rtl;

