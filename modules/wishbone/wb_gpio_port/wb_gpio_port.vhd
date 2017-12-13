------------------------------------------------------------------------------
-- Title      : Wishbone GPIO port
-- Project    : General Core Collection (gencores) Library
------------------------------------------------------------------------------
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-05-18
-- Last update: 2017-10-11
-- Platform   : FPGA-generic
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Bidirectional GPIO port of configurable width (1 to 256 bits).
-------------------------------------------------------------------------------
-- Copyright (c) 2010 - 2017 CERN
--
-- This source file is free software; you can redistribute it
-- and/or modify it under the terms of the GNU Lesser General
-- Public License as published by the Free Software Foundation;
-- either version 2.1 of the License, or (at your option) any
-- later version.
--
-- This source is distributed in the hope that it will be
-- useful, but WITHOUT ANY WARRANTY; without even the implied
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
-- PURPOSE.  See the GNU Lesser General Public License for more
-- details.
--
-- You should have received a copy of the GNU Lesser General
-- Public License along with this source; if not, download it
-- from http://www.gnu.org/licenses/lgpl-2.1.html
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2010-05-18  1.0      twlostow        Created
-- 2010-10-04  1.1      twlostow        Added WB slave adapter
-- 2013-09-04  1.2      greg.d          Optimized for g_num_pins up to 32
-------------------------------------------------------------------------------

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

use work.wishbone_pkg.all;
use work.gencores_pkg.all;

entity wb_gpio_port is
  generic(
    g_interface_mode         : t_wishbone_interface_mode      := CLASSIC;
    g_address_granularity    : t_wishbone_address_granularity := WORD;
    g_num_pins               : natural range 1 to 256         := 32;
    g_with_builtin_tristates : boolean                        := false
    );
  port(
-- System reset, active low
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    wb_sel_i   : in  std_logic_vector(c_wishbone_data_width/8-1 downto 0);
    wb_cyc_i   : in  std_logic;
    wb_stb_i   : in  std_logic;
    wb_we_i    : in  std_logic;
    wb_adr_i   : in  std_logic_vector(7 downto 0);
    wb_dat_i   : in  std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_dat_o   : out std_logic_vector(c_wishbone_data_width-1 downto 0);
    wb_ack_o   : out std_logic;
    wb_stall_o : out std_logic;

    gpio_b : inout std_logic_vector(g_num_pins-1 downto 0);

    gpio_out_o : out std_logic_vector(g_num_pins-1 downto 0);
    gpio_in_i  : in  std_logic_vector(g_num_pins-1 downto 0);
    gpio_oen_o : out std_logic_vector(g_num_pins-1 downto 0)


    );
end wb_gpio_port;


architecture behavioral of wb_gpio_port is

  constant c_GPIO_REG_CODR : std_logic_vector(2 downto 0) := "000";  -- *reg* clear output register
  constant c_GPIO_REG_SODR : std_logic_vector(2 downto 0) := "001";  -- *reg* set output register
  constant c_GPIO_REG_DDR  : std_logic_vector(2 downto 0) := "010";  -- *reg* data direction register
  constant c_GPIO_REG_PSR  : std_logic_vector(2 downto 0) := "011";  -- *reg* pin state register

  constant c_NUM_BANKS : integer := (g_num_pins+31) / 32;

  signal out_reg, in_reg, dir_reg : std_logic_vector(32*c_NUM_BANKS-1 downto 0);
  signal gpio_in                  : std_logic_vector(32*c_NUM_BANKS-1 downto 0);
  signal gpio_in_synced           : std_logic_vector(32*c_NUM_BANKS-1 downto 0);
  signal ack_int                  : std_logic;

  signal sor_wr : std_logic_vector(c_NUM_BANKS-1 downto 0);
  signal cor_wr : std_logic_vector(c_NUM_BANKS-1 downto 0);
  signal ddr_wr : std_logic_vector(c_NUM_BANKS-1 downto 0);

  signal write_mask : std_logic_vector(7 downto 0);

  signal wb_in  : t_wishbone_slave_in;
  signal wb_out : t_wishbone_slave_out;

  signal sel          : std_logic;
  signal resized_addr : std_logic_vector(c_wishbone_address_width-1 downto 0);
begin

  resized_addr(7 downto 0) <= wb_adr_i;
  resized_addr(c_wishbone_address_width-1 downto 8) <= (others => '0');

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
      sl_stall_o => wb_stall_o);

  sel <= '1' when (unsigned(not wb_in.sel) = 0) else '0';

  GEN_SYNC_FFS : for i in 0 to g_num_pins-1 generate
    INPUT_SYNC : gc_sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        rst_n_i  => rst_n_i,
        clk_i    => clk_sys_i,
        data_i   => gpio_in(i),
        synced_o => gpio_in_synced(i),
        npulse_o => open
        );
  end generate GEN_SYNC_FFS;

  p_gen_write_mask : process(wb_in.adr)
  begin
    case wb_in.adr(5 downto 3) is
      when "000"  => write_mask <= x"01";
      when "001"  => write_mask <= x"02";
      when "010"  => write_mask <= x"04";
      when "011"  => write_mask <= x"08";
      when "100"  => write_mask <= x"10";
      when "101"  => write_mask <= x"20";
      when "110"  => write_mask <= x"40";
      when "111"  => write_mask <= x"80";
      when others => write_mask <= x"00";
    end case;
  end process;

  p_gen_write_strobes : process(write_mask, wb_in.adr, wb_in.we, wb_in.cyc, wb_in.stb, sel)
  begin

    if(wb_in.we = '1' and wb_in.cyc = '1' and wb_in.stb = '1' and sel = '1') then
      case wb_in.adr(2 downto 0) is
        when c_GPIO_REG_CODR =>
          cor_wr <= write_mask(c_NUM_BANKS-1 downto 0);
          sor_wr <= (others => '0');
          ddr_wr <= (others => '0');
        when c_GPIO_REG_SODR =>
          cor_wr <= (others => '0');
          sor_wr <= write_mask(c_NUM_BANKS-1 downto 0);
          ddr_wr <= (others => '0');
        when c_GPIO_REG_DDR =>
          sor_wr <= (others => '0');
          cor_wr <= (others => '0');
          ddr_wr <= write_mask(c_NUM_BANKS-1 downto 0);
        when others =>
          sor_wr <= (others => '0');
          cor_wr <= (others => '0');
          ddr_wr <= (others => '0');
      end case;
    else
      sor_wr <= (others => '0');
      cor_wr <= (others => '0');
      ddr_wr <= (others => '0');
    end if;
  end process;

  GEN_LARGE: if g_num_pins > 32 generate
    gen_banks_wr : for i in 0 to c_NUM_BANKS-1 generate
      process (clk_sys_i)
      begin
        if rising_edge(clk_sys_i) then
          if rst_n_i = '0' then
            dir_reg(32 * i + 31 downto 32 * i) <= (others => '0');
            out_reg(32 * i + 31 downto 32 * i) <= (others => '0');
          else
            if(sor_wr(i) = '1') then
              out_reg(i * 32 + 31 downto i * 32) <= out_reg(i * 32 + 31 downto i * 32) or wb_in.dat;
            end if;
            if(cor_wr(i) = '1') then
              out_reg(i * 32 + 31 downto i * 32) <= out_reg(i * 32 + 31 downto i * 32) and (not wb_in.dat);
            end if;
            if(ddr_wr(i) = '1') then
              dir_reg(i * 32 + 31 downto i * 32) <= wb_in.dat;
            end if;
          end if;
        end if;
      end process;
    end generate gen_banks_wr;

    p_wb_reads : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          wb_out.dat <= (others => '0');
        else
          wb_out.dat <= (others => 'X');
          case wb_in.adr(2 downto 0) is
            when c_GPIO_REG_DDR =>
              for i in 0 to c_NUM_BANKS-1 loop
                if(to_integer(unsigned(wb_in.adr(5 downto 3))) = i) then
                  wb_out.dat <= dir_reg(32 * i + 31 downto 32 * i);
                end if;
              end loop;  -- i 

            when c_GPIO_REG_PSR =>
              for i in 0 to c_NUM_BANKS-1 loop
                if(to_integer(unsigned(wb_in.adr(5 downto 3))) = i) then
                  wb_out.dat <= gpio_in_synced(32 * i + 31 downto 32 * i);
                end if;
              end loop;  -- i 
            when others => null;
          end case;
        end if;
      end if;
    end process;
  end generate;

  GEN_SMALL: if g_num_pins < 33 generate
    p_wb_write: process (clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          dir_reg(g_num_pins-1 downto 0) <= (others => '0');
          out_reg(g_num_pins-1 downto 0) <= (others => '0');
        else
          if(sor_wr(0) = '1') then
            out_reg(g_num_pins-1 downto 0) <= out_reg(g_num_pins-1 downto 0) or wb_in.dat(g_num_pins-1 downto 0);
          end if;
          if(cor_wr(0) = '1') then
            out_reg(g_num_pins-1 downto 0) <= out_reg(g_num_pins-1 downto 0) and (not wb_in.dat(g_num_pins-1 downto 0));
          end if;
          if(ddr_wr(0) = '1') then
            dir_reg(g_num_pins-1 downto 0) <= wb_in.dat(g_num_pins-1 downto 0);
          end if;
        end if;
      end if;
    end process;

    p_wb_reads : process(clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          wb_out.dat <= (others => '0');
        else
          wb_out.dat <= (others => 'X');
          case wb_in.adr(2 downto 0) is
            when c_GPIO_REG_DDR =>
              wb_out.dat(g_num_pins-1 downto 0) <= dir_reg(g_num_pins-1 downto 0);

            when c_GPIO_REG_PSR =>
              wb_out.dat(g_num_pins-1 downto 0) <= gpio_in_synced(g_num_pins-1 downto 0);

            when others => null;
          end case;
        end if;
      end if;
    end process;

  end generate;


  p_gen_ack : process (clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        ack_int <= '0';
      else
        if(ack_int = '1') then
          ack_int <= '0';
        elsif(wb_in.cyc = '1') and (wb_in.stb = '1') then
          ack_int <= '1';
        end if;
      end if;
    end if;
  end process;

  gen_with_tristates : if(g_with_builtin_tristates) generate
    
    gpio_out_tristate : process (out_reg, dir_reg)
    begin
      for i in 0 to g_num_pins-1 loop
        if(dir_reg(i) = '1') then
          gpio_b(i) <= out_reg(i);
        else
          gpio_b(i) <= 'Z';
        end if;
        
      end loop;
    end process gpio_out_tristate;

    gpio_in(g_num_pins-1 downto 0)          <= gpio_b;
    gpio_in(gpio_in'LEFT downto g_num_pins) <= (others => '0');

  end generate gen_with_tristates;

  gen_without_tristates : if (not g_with_builtin_tristates) generate
    gpio_out_o                     <= out_reg(g_num_pins-1 downto 0);
    gpio_in(g_num_pins-1 downto 0) <= gpio_in_i;
    gpio_in(gpio_in'LEFT downto g_num_pins) <= (others => '0');
    gpio_oen_o                     <= dir_reg(g_num_pins-1 downto 0);
  end generate gen_without_tristates;

  wb_out.ack   <= ack_int;
  wb_out.stall <= '0';
  wb_out.err <= '0';
  wb_out.int <= '0';
  wb_out.rty <='0';
  
end behavioral;


