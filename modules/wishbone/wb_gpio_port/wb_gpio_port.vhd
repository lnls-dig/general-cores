------------------------------------------------------------------------------
-- Title      : Wishbone GPIO port
-- Project    : White Rabbit Switch
------------------------------------------------------------------------------
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2010-05-18
-- Last update: 2011-06-07
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
    wb_adr_i : in  std_logic_vector(2 downto 0);
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


  signal out_reg, in_reg, dir_reg : std_logic_vector(g_num_pins-1 downto 0);
  signal gpio_in                  : std_logic_vector(g_num_pins-1 downto 0);
  signal gpio_in_synced           : std_logic_vector(g_num_pins-1 downto 0);
  signal ack_int                  : std_logic;

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


  process (clk_sys_i)
  begin
    if rising_edge(clk_sys_i) then
      if rst_n_i = '0' then
        dir_reg                         <= (others => '0');
        out_reg                         <= (others => '0');
        ack_int                         <= '0';
        wb_dat_o(g_num_pins-1 downto 0) <= (others => '0');
      else
        if(ack_int = '1') then
          ack_int <= '0';
        elsif(wb_cyc_i = '1') and (wb_sel_i = '1') and (wb_stb_i = '1') then
          if(wb_we_i = '1') then
            case wb_adr_i(2 downto 0) is
              when c_GPIO_REG_SODR =>
                out_reg <= out_reg or wb_dat_i(g_num_pins-1 downto 0);
                ack_int <= '1';
              when c_GPIO_REG_CODR =>
                out_reg <= out_reg and (not wb_dat_i(g_num_pins-1 downto 0));
                ack_int <= '1';
              when c_GPIO_REG_DDR =>
                dir_reg <= wb_dat_i(g_num_pins-1 downto 0);
                ack_int <= '1';
              when others =>
                ack_int <= '1';
            end case;
          else
            case wb_adr_i(2 downto 0) is
              when c_GPIO_REG_DDR =>
                wb_dat_o(g_num_pins-1 downto 0) <= dir_reg;
                ack_int                         <= '1';
                
              when c_GPIO_REG_PSR =>
                wb_dat_o(g_num_pins-1 downto 0) <= gpio_in_synced;
                ack_int                         <= '1';
              when others =>
                ack_int <= '1';
            end case;
          end if;
        else
          ack_int <= '0';
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
        gpio_out_o <= out_reg;
        gpio_in    <= gpio_in_i;
        gpio_oen_o <= dir_reg;
      end generate gen_without_tristates;

      wb_ack_o <= ack_int;
    end behavioral;


f(ddr_wr(i) = '1') then
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
    gpio_out_o <= out_reg;
    gpio_in    <= gpio_in_i;
    gpio_oen_o <= dir_reg;
  end generate gen_without_tristates;

  wb_ack_o <= ack_int;
end behavioral;


