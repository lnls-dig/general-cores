-------------------------------------------------------------------------------
-- Title      : Testbench for design "inferred_async_fifo"
-- Project    :
-------------------------------------------------------------------------------
-- File       : inferred_async_fifo_tb.vhd
-- Author     : Augusto Fraga Giachero  <augusto.fraga@lnls.br>
-- Company    :
-- Created    : 2024-09-19
-- Last update: 2024-09-19
-- Platform   :
-- Standard   : VHDL 2008
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2024
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2024-09-19  1.0      augusto	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------

entity inferred_async_fifo_tb is

end entity inferred_async_fifo_tb;

-------------------------------------------------------------------------------

architecture sim of inferred_async_fifo_tb is

  -- component generics
  constant g_data_width             : natural := 32;
  constant g_size                   : natural := 4;
  constant g_show_ahead             : boolean := FALSE;
  constant g_with_rd_empty          : boolean := TRUE;
  constant g_with_rd_full           : boolean := FALSE;
  constant g_with_rd_almost_empty   : boolean := FALSE;
  constant g_with_rd_almost_full    : boolean := FALSE;
  constant g_with_rd_count          : boolean := FALSE;
  constant g_with_wr_empty          : boolean := FALSE;
  constant g_with_wr_full           : boolean := TRUE;
  constant g_with_wr_almost_empty   : boolean := FALSE;
  constant g_with_wr_almost_full    : boolean := FALSE;
  constant g_with_wr_count          : boolean := FALSE;
  constant g_almost_empty_threshold : integer := 1;
  constant g_almost_full_threshold  : integer := 3;

  -- component ports
  signal rst_n_i           : std_logic := '0';
  signal clk_wr_i          : std_logic;
  signal d_i               : std_logic_vector(g_data_width-1 downto 0);
  signal we_i              : std_logic := '0';
  signal wr_empty_o        : std_logic;
  signal wr_full_o         : std_logic;
  signal wr_almost_empty_o : std_logic;
  signal wr_almost_full_o  : std_logic;
  signal wr_count_o        : std_logic_vector(1 downto 0);
  signal clk_rd_i          : std_logic;
  signal q_o               : std_logic_vector(g_data_width-1 downto 0);
  signal rd_i              : std_logic;
  signal rd_empty_o        : std_logic;
  signal rd_full_o         : std_logic;
  signal rd_almost_empty_o : std_logic;
  signal rd_almost_full_o  : std_logic;
  signal rd_count_o        : std_logic_vector(1 downto 0);

  -- clock
  signal Clk : std_logic := '0';

begin  -- architecture sim

  -- component instantiation
  DUT: entity work.inferred_async_fifo
    generic map (
      g_data_width             => g_data_width,
      g_size                   => g_size,
      g_show_ahead             => g_show_ahead,
      g_with_rd_empty          => g_with_rd_empty,
      g_with_rd_full           => g_with_rd_full,
      g_with_rd_almost_empty   => g_with_rd_almost_empty,
      g_with_rd_almost_full    => g_with_rd_almost_full,
      g_with_rd_count          => g_with_rd_count,
      g_with_wr_empty          => g_with_wr_empty,
      g_with_wr_full           => g_with_wr_full,
      g_with_wr_almost_empty   => g_with_wr_almost_empty,
      g_with_wr_almost_full    => g_with_wr_almost_full,
      g_with_wr_count          => g_with_wr_count,
      g_almost_empty_threshold => g_almost_empty_threshold,
      g_almost_full_threshold  => g_almost_full_threshold)
    port map (
      rst_n_i           => rst_n_i,
      clk_wr_i          => clk_wr_i,
      d_i               => d_i,
      we_i              => we_i,
      wr_empty_o        => wr_empty_o,
      wr_full_o         => wr_full_o,
      wr_almost_empty_o => wr_almost_empty_o,
      wr_almost_full_o  => wr_almost_full_o,
      wr_count_o        => wr_count_o,
      clk_rd_i          => clk_rd_i,
      q_o               => q_o,
      rd_i              => rd_i,
      rd_empty_o        => rd_empty_o,
      rd_full_o         => rd_full_o,
      rd_almost_empty_o => rd_almost_empty_o,
      rd_almost_full_o  => rd_almost_full_o,
      rd_count_o        => rd_count_o);

  -- clock generation
  Clk <= not Clk after 10 ns;
  clk_wr_i <= Clk;
  clk_rd_i <= Clk;
  -- waveform generation
  WaveGen_Proc: process
  begin
    wait until rising_edge(clk_wr_i);
    wait until rising_edge(clk_wr_i);
    rst_n_i <= '1';
    wait until rising_edge(clk_wr_i);
    wait until rising_edge(clk_wr_i);

    d_i <= x"AAAABBBB";
    we_i <= '1';
    wait until rising_edge(clk_wr_i);
    d_i <= x"11111111";
    we_i <= '0';

    for i in 1 to 5 loop
      wait until rising_edge(clk_wr_i);
    end loop;

    std.env.finish;
  end process WaveGen_Proc;
end architecture sim;

-------------------------------------------------------------------------------

configuration inferred_async_fifo_tb_sim_cfg of inferred_async_fifo_tb is
  for sim
  end for;
end inferred_async_fifo_tb_sim_cfg;

-------------------------------------------------------------------------------
