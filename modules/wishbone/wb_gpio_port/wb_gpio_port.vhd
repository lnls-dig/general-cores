------------------------------------------------------------------------------
-- Title      : Wishbone GPIO port
-- Project    : White Rabbit Switch
------------------------------------------------------------------------------
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-05-18
-- Last update: 2011-06-21
-- Platform   : FPGA-generic
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Bidirectional GPIO port of configurable width (1 to 32 bits).
-------------------------------------------------------------------------------
-- Copyright (c) 2010 Tomasz Wlostowski
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2010-05-18  1.0      twlostow        Created
-------------------------------------------------------------------------------

library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

use work.wishbone_pkg.all;
use work.gencores_pkg.all;

entity wb_gpio_port is
  generic(
    g_num_pins               : natural := 8;
    g_with_builtin_tristates : boolean := false
    );
  port(
-- System reset, active low
    clk_sys_i : in std_logic;
    rst_n_i   : in std_logic;

    wb_sel_i : in  std_logic;
    wb_cyc_i : in  std_logic;
    wb_stb_i : in  std_logic;
    wb_we_i  : in  std_logic;
    wb_adr_i : in  std_logic_vector(5 downto 0);
    wb_dat_i : in  std_logic_vector(31 downto 0);
    wb_dat_o : out std_logic_vector(31 downto 0);
    wb_ack_o : out std_logic;

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
  
begin


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

  p_gen_write_mask : process(wb_adr_i)
  begin
    case wb_adr_i(5 downto 3) is
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

  p_gen_write_strobes : process(write_mask, wb_adr_i, wb_we_i, wb_cyc_i, wb_stb_i)
  begin

    if(wb_we_i = '1' and wb_cyc_i = '1' and wb_stb_i = '1')then
      case wb_adr_i(2 downto 0) is
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

  gen_banks_wr : for i in 0 to c_NUM_BANKS-1 generate
    process (clk_sys_i)
    begin
      if rising_edge(clk_sys_i) then
        if rst_n_i = '0' then
          dir_reg(32 * i + 31 downto 32 * i) <= (others => '0');
          out_reg(32 * i + 31 downto 32 * i) <= (others => '0');
        else
          if(sor_wr(i) = '1') then
            out_reg(i * 32 + 31 downto i * 32) <= out_reg(i * 32 + 31 downto i * 32) or wb_dat_i;
          end if;
          if(cor_wr(i) = '1') then
            out_reg(i * 32 + 31 downto i * 32) <= out_reg(i * 32 + 31 downto i * 32) and (not wb_dat_i);
          end if;
          if(ddr_wr(i) = '1') then
            dir_reg(i * 32 + 31 downto i * 32) <= wb_dat_i;
          end if;
        end if;
      end if;
    end process;
  end generate gen_banks_wr;


  p_wb_reads : process(clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        wb_dat_o <= (others => '0');
      else
        wb_dat_o <= (others => 'X');
        case wb_adr_i(2 downto 0) is
          when c_GPIO_REG_DDR =>
            for i in 0 to c_NUM_BANKS-1 loop
              if(to_integer(unsigned(wb_adr_i(5 downto 3))) = i) then
                wb_dat_o <= dir_reg(32 * i + 31 downto 32 * i);
              end if;
            end loop;  -- i 

          when c_GPIO_REG_PSR =>
            for i in 0 to c_NUM_BANKS-1 loop
              if(to_integer(unsigned(wb_adr_i(5 downto 3))) = i) then
                wb_dat_o <= gpio_in_synced(32 * i + 31 downto 32 * i);
              end if;
            end loop;  -- i 
          when others => null;
        end case;
      end if;
    end if;
  end process;

  p_gen_ack : process (clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        ack_int <= '0';
      else
        if(ack_int = '1') then
          ack_int <= '0';
        elsif(wb_cyc_i = '1') and (wb_sel_i = '1') and (wb_stb_i = '1') then
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

    gpio_in <= gpio_b;
    
  end generate gen_with_tristates;

  gen_without_tristates : if (not g_with_builtin_tristates) generate
    gpio_out_o <= out_reg(g_num_pins-1 downto 0);
    gpio_in(g_num_pins-1 downto 0)    <= gpio_in_i;
    gpio_oen_o <= dir_reg(g_num_pins-1 downto 0);
  end generate gen_without_tristates;

  wb_ack_o <= ack_int;
end behavioral;


