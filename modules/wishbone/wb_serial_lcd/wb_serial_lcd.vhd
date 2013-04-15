------------------------------------------------------------------------------
-- Title      : Wishbone Serial LCD controller
-- Project    : General Cores
------------------------------------------------------------------------------
-- File       : wb_serial_lcd.vhd
-- Author     : Wesley W. Terpstra
-- Company    : GSI
-- Created    : 2013-02-22
-- Last update: 2013-02-22
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Frame-buffer for driving an ISO01RGB display
-------------------------------------------------------------------------------
-- Copyright (c) 2013 GSI
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2013-02-22  1.0      terpstra        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.wishbone_pkg.all;
use work.genram_pkg.all;

entity wb_serial_lcd is
  generic(
    g_cols : natural := 40;
    g_rows : natural := 24;
    g_hold : natural := 15; -- How many times to repeat a line  (for sharpness)
    g_wait : natural := 1); -- How many cycles per state change (for 20MHz timing)
  port(
    slave_clk_i  : in  std_logic;
    slave_rstn_i : in  std_logic;
    slave_i      : in  t_wishbone_slave_in;
    slave_o      : out t_wishbone_slave_out;
    
    di_clk_i     : in  std_logic;
    di_scp_o     : out std_logic;
    di_lp_o      : out std_logic;
    di_flm_o     : out std_logic;
    di_dat_o     : out std_logic);
end entity;

architecture rtl of wb_serial_lcd is
  type t_state is (CLK_HIGH, FLM_HIGH, LP_HIGH, SLEEP1,  SLEEP2, 
                   CLK_LOW,  SLEEP3,   LP_LOW,  FLM_LOW, SET_DATA);
  
  constant c_lo : natural := f_ceil_log2((g_cols+31)/32);
  constant c_hi : natural := f_ceil_log2(g_rows);
  constant c_bits : natural := c_lo+c_hi;
  
  constant c_len : natural := g_cols*g_hold;
  
  signal r_state : t_state                     := SET_DATA;
  signal r_row   : integer range 0 to g_rows-1 := 0;
  signal r_col   : integer range 0 to c_len -1 := 0;
  signal r_wait  : integer range 0 to g_wait-1 := 0;
  signal r_lp    : std_logic                   := '0';
  signal r_flm   : std_logic                   := '0';
  signal r_ack   : std_logic                   := '0';
  
  signal s_wea : std_logic;
  signal s_qa  : std_logic_vector(31 downto 0);
  signal s_qb  : std_logic_vector(31 downto 0);
  signal s_ab  : std_logic_vector(c_bits-1 downto 0);
  
begin

  slave_o.rty   <= '0';
  slave_o.err   <= '0';
  slave_o.stall <= '0';
  
  s_wea <= slave_i.cyc and slave_i.stb and slave_i.we;
  s_ab(c_bits-1 downto c_lo) <= std_logic_vector(to_unsigned(r_row, c_hi));
  s_ab(c_lo  -1 downto    0) <= std_logic_vector(to_unsigned(r_col, c_lo+5)(c_lo+4 downto 5));
  
  mem : generic_dpram
    generic map(
      g_data_width       => 32,
      g_size             => 2**c_bits,
      g_with_byte_enable => true,
      g_dual_clock       => true)
    port map(
      clka_i => slave_clk_i,
      bwea_i => slave_i.sel,
      wea_i  => s_wea,
      aa_i   => slave_i.adr(c_bits+1 downto 2),
      da_i   => slave_i.dat,
      qa_o   => s_qa,
      clkb_i => di_clk_i,
      bweb_i => (others => '0'),
      web_i  => '0',
      ab_i   => s_ab,
      db_i   => (others => '0'),
      qb_o   => s_qb);
  
  -- Provide WB access to the frame buffer
  wb : process(slave_clk_i) is
  begin
    if rising_edge(slave_clk_i) then
      r_ack <= slave_i.cyc and slave_i.stb;
      slave_o.ack <= r_ack;
      slave_o.dat <= s_qa;
    end if;
  end process;

  -- Draw the frame buffer to the display
  main : process(di_clk_i) is
  begin
    if rising_edge(di_clk_i) then
      if r_wait /= g_wait-1 then
        r_wait <= r_wait + 1;
      else
        r_wait <= 0;
      
        case r_state is
        
          when CLK_HIGH =>
            di_scp_o <= '1';
            r_state  <= FLM_HIGH;
            
          when FLM_HIGH =>
            di_flm_o <= r_flm;
            r_state <= LP_HIGH;
          
          when LP_HIGH =>
            di_lp_o  <= r_lp;
            r_state  <= SLEEP1;
          
          when SLEEP1 =>
            r_state <= SLEEP2;
            
          when SLEEP2 =>
            r_state <= CLK_LOW;
            
          when CLK_LOW =>
            di_scp_o <= '0';
            r_state <= SLEEP3;
          
          when SLEEP3 =>
            r_state  <= LP_LOW;
          
          when LP_LOW =>
            di_lp_o  <= '0';
            r_state  <= FLM_LOW;
            
          when FLM_LOW =>
            di_flm_o <= '0';
            r_state <= SET_DATA;
          
          when SET_DATA =>
            di_dat_o <= s_qb(to_integer(31 - to_unsigned(r_col, 5)));
            r_state  <= CLK_HIGH;
            
            if r_col /= 0 then
              r_lp  <= '0';
              r_flm <= '0';
              r_col <= r_col-1;
              r_row <= r_row;
            elsif r_row = 0 then
              r_lp  <= '1';
              r_flm <= '1';
              r_col <= c_len-1;
              r_row <= r_row+1;
            elsif r_row /= g_rows-1 then
              r_lp  <= '1';
              r_flm <= '0';
              r_col <= c_len-1;
              r_row <= r_row+1;
            else
              r_lp  <= '1';
              r_flm <= '0';
              r_col <= c_len-1;
              r_row <= 0;
            end if;
          
        end case;
      end if;
    end if;
  end process;
  
end rtl;
