------------------------------------------------------------------------------
-- Title      : Wishbone GPIO port
-- Project    : White Rabbit Switch
------------------------------------------------------------------------------
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-05-18
-- Last update: 2011-04-06
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
use ieee.std_logic_arith.all;

library work;

use work.wishbone_pkg.all;
use work.common_components.all;

entity wb_gpio_port is
  generic(g_num_pins : natural := 8     -- number of GPIO pins
          );
  port(
-- System reset, active low
    sys_rst_n_i : in std_logic;

-------------------------------------------------------------------------------
-- Wishbone bus
-------------------------------------------------------------------------------

    wb_clk_i  : in  std_logic;
    wb_sel_i  : in  std_logic;
    wb_cyc_i  : in  std_logic;
    wb_stb_i  : in  std_logic;
    wb_we_i   : in  std_logic;
    wb_addr_i : in  std_logic_vector(2 downto 0);
    wb_data_i : in  std_logic_vector(31 downto 0);
    wb_data_o : out std_logic_vector(31 downto 0);
    wb_ack_o  : out std_logic;

-- GPIO pin vector
    gpio_b : inout std_logic_vector(g_num_pins-1 downto 0)
    );
end wb_gpio_port;


architecture behavioral of wb_gpio_port is

  constant c_GPIO_REG_CODR : std_logic_vector(2 downto 0) := "000";  -- *reg* clear output register
  constant c_GPIO_REG_SODR : std_logic_vector(2 downto 0) := "001";  -- *reg* set output register
  constant c_GPIO_REG_DDR  : std_logic_vector(2 downto 0) := "010";  -- *reg* data direction register
  constant c_GPIO_REG_PSR  : std_logic_vector(2 downto 0) := "011";  -- *reg* pin state register


  signal out_reg, in_reg, dir_reg : std_logic_vector(g_num_pins-1 downto 0);
  signal gpio_in_synced           : std_logic_vector(g_num_pins-1 downto 0);
  signal ack_int                  : std_logic;

begin


  GEN_SYNC_FFS : for i in 0 to g_num_pins-1 generate
    INPUT_SYNC : sync_ffs
      generic map (
        g_sync_edge => "positive")
      port map (
        rst_n_i  => sys_rst_n_i,
        clk_i    => wb_clk_i,
        data_i   => gpio_b(i),
        synced_o => gpio_in_synced(i),
        npulse_o => open
        );

  end generate GEN_SYNC_FFS;


  process (wb_clk_i, sys_rst_n_i)
  begin
    if sys_rst_n_i = '0' then
      dir_reg                          <= (others => '0');
      out_reg                          <= (others => '0');
      ack_int                          <= '0';
      wb_data_o(g_num_pins-1 downto 0) <= (others => '0');
    elsif rising_edge(wb_clk_i) then
      if(ack_int = '1') then
        ack_int <= '0';
      elsif(wb_cyc_i = '1') and (wb_sel_i = '1') and (wb_stb_i = '1') then
        if(wb_we_i = '1') then
          case wb_addr_i(2 downto 0) is
            when c_GPIO_REG_SODR =>
              out_reg <= out_reg or wb_data_i(g_num_pins-1 downto 0);
              ack_int <= '1';
            when c_GPIO_REG_CODR =>
              out_reg <= out_reg and (not wb_data_i(g_num_pins-1 downto 0));
              ack_int <= '1';
            when c_GPIO_REG_DDR =>
              dir_reg <= wb_data_i(g_num_pins-1 downto 0);
              ack_int <= '1';
            when others =>
              ack_int <= '1';
          end case;
        else
          case wb_addr_i(2 downto 0) is
            when c_GPIO_REG_DDR =>
              wb_data_o(g_num_pins-1 downto 0) <= dir_reg;
              ack_int                          <= '1';
              
            when c_GPIO_REG_PSR =>
              wb_data_o(g_num_pins-1 downto 0) <= gpio_in_synced;
              ack_int                          <= '1';
            when others =>
              ack_int <= '1';
          end case;
        end if;
      else
        ack_int <= '0';
      end if;
    end if;
  end process;

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

  wb_ack_o <= ack_int;
end behavioral;


