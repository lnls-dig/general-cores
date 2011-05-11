-------------------------------------------------------------------------------
-- Title      : WhiteRabbit PTP Core tics
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_tics.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-04-03
-- Last update: 2011-04-07
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- WB_TICS is a simple counter with wishbone interface. Each step of a counter
-- takes 1 usec. It is used by ptp-noposix as a replace of gettimeofday()
-- function.
-------------------------------------------------------------------------------
-- Copyright (c) 2011 Grzegorz Daniluk
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-04-03  1.0      greg.d          Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity wb_tics is

  generic (
    g_period : integer);
  port(
    rst_n_i : in std_logic;

    clk_sys_i : in std_logic;

    wb_addr_i : in  std_logic_vector(1 downto 0);
    wb_data_i : in  std_logic_vector(31 downto 0);
    wb_data_o : out std_logic_vector(31 downto 0);
    wb_cyc_i  : in  std_logic;
    wb_sel_i  : in  std_logic_vector(3 downto 0);
    wb_stb_i  : in  std_logic;
    wb_we_i   : in  std_logic;
    wb_ack_o  : out std_logic
    );
end wb_tics;

architecture behaviour of wb_tics is

  constant c_TICS_REG : std_logic_vector(1 downto 0) := "00";

  signal cntr_div      : unsigned(23 downto 0);
  signal cntr_tics     : unsigned(31 downto 0);
  signal cntr_overflow : std_logic;

begin

  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if(rst_n_i = '0') then
        cntr_div      <= (others => '0');
        cntr_overflow <= '0';
      else
        if(cntr_div = g_period-1) then
          cntr_div      <= (others => '0');
          cntr_overflow <= '1';
        else
          cntr_div      <= cntr_div + 1;
          cntr_overflow <= '0';
        end if;
      end if;
    end if;
  end process;

  --usec counter
  process(clk_sys_i)
  begin
    if(rising_edge(clk_sys_i)) then
      if(rst_n_i = '0') then
        cntr_tics <= (others => '0');
      elsif(cntr_overflow = '1') then
        cntr_tics <= cntr_tics + 1;
      end if;
    end if;
  end process;

  --Wishbone interface
  process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if(rst_n_i = '0') then
        wb_ack_o  <= '0';
        wb_data_o <= (others => '0');
      else
        if(wb_stb_i = '1' and wb_cyc_i = '1' and wb_we_i = '0') then
          case wb_addr_i is
            when c_TICS_REG =>
              wb_data_o <= std_logic_vector(cntr_tics);
            when others =>
              wb_data_o <= (others => '0');
          end case;
          wb_ack_o <= '1';
        else
          wb_data_o <= (others => '0');
          wb_ack_o  <= '0';
        end if;
      end if;
    end if;
  end process;

end behaviour;
