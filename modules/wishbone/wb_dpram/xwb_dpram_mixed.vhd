-------------------------------------------------------------------------------
-- Title      : Dual-port RAM for WR core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : xwb_dpram_mixed.vhd
-- Author     : C.Prados
-- Company    : GSI
-- Created    : 2014-08-25
-- Last update: 2011-08-25
-- Platform   : FPGA-generics
-- Standard   : VHDL '93
-------------------------------------------------------------------------------
-- Description:
--
-- Dual port RAM with mixed width ports with wishbone interface
-------------------------------------------------------------------------------
-- Copyright (c) 2014 GSI
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                   Description
-- 2014-08-25  1.0      c.prados@gsi.de          Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


library work;
use work.genram_pkg.all;
use work.wishbone_pkg.all;

entity xwb_dpram_mixed is
  generic(
    g_size                  : natural := 16384;
    g_init_file             : string  := "";
    g_must_have_init_file   : boolean := true;
    g_swap_word_endianness  : boolean := true;
    g_slave1_interface_mode : t_wishbone_interface_mode;
    g_slave2_interface_mode : t_wishbone_interface_mode;
    g_dpram_port_a_width    : integer := 32;
    g_dpram_port_b_width    : integer := 16;
    g_slave1_granularity    : t_wishbone_address_granularity;
    g_slave2_granularity    : t_wishbone_address_granularity
    );
  port(
    clk_slave1_i  : in std_logic;
    clk_slave2_i  : in std_logic;
    rst_n_i       : in std_logic;

    slave1_i      : in  t_wishbone_slave_in;
    slave1_o      : out t_wishbone_slave_out;
    slave2_i      : in  t_wishbone_slave_in;
    slave2_o      : out t_wishbone_slave_out
    );
end xwb_dpram_mixed;

architecture struct of xwb_dpram_mixed is

  function f_zeros(size : integer)
    return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(0, size));
  end f_zeros;

  function f_swap_word(data : std_logic_vector)
  return std_logic_vector is
  constant c_words2swap : integer :=  g_dpram_port_a_width / g_dpram_port_b_width;
  variable data_swap    : std_logic_vector(data'RANGE);
  variable words2swap   : integer;
  variable v_up_swap    : integer;
  variable v_down_swap  : integer;
  variable v_up_data    : integer;
  variable v_down_data  : integer;
  begin

      for i in 0 to (c_words2swap - 1) loop 
        v_up_swap   := (g_dpram_port_b_width * (i+1)) - 1;
        v_down_swap := i * g_dpram_port_b_width;

        v_up_data   := (g_dpram_port_b_width * (c_words2swap - i)) - 1;
        v_down_data := (g_dpram_port_b_width * (c_words2swap - i - 1));

        data_swap(v_up_swap downto v_down_swap) := data(v_up_data downto v_down_data);
      end loop;
      return data_swap;
  end f_swap_word;

  signal s_wea  : std_logic;
  signal s_web  : std_logic;
  signal s_bwea : std_logic_vector(3 downto 0);
  signal s_bweb : std_logic_vector(3 downto 0);

  signal clk_sys_i   : std_logic;

  signal slave1_in  : t_wishbone_slave_in;
  signal slave1_out : t_wishbone_slave_out;
  signal slave2_in  : t_wishbone_slave_in;
  signal slave2_out : t_wishbone_slave_out;
  signal slave1_out_dat : std_logic_vector(g_dpram_port_a_width-1 downto 0);

  signal s_q  : std_logic_vector(g_dpram_port_b_width-1 downto 0);
  signal s_h_b  : std_logic_vector(15 downto 0);
  signal s_l_b  : std_logic_vector(15 downto 0);
  
begin

  clk_sys_i <= clk_slave1_i;
   
  U_Adapter1 : wb_slave_adapter
    generic map (
      g_master_use_struct  => true,
      g_master_mode        => g_slave1_interface_mode,
      g_master_granularity => WORD,
      g_slave_use_struct   => true,
      g_slave_mode         => g_slave1_interface_mode,
      g_slave_granularity  => g_slave1_granularity)
    port map (
      clk_sys_i => clk_sys_i,
      rst_n_i   => rst_n_i,
      slave_i   => slave1_i,
      slave_o   => slave1_o,
      master_i  => slave1_out,
      master_o  => slave1_in);

  U_Adapter2 : wb_slave_adapter
    generic map (
      g_master_use_struct  => true,
      g_master_mode        => g_slave2_interface_mode,
      g_master_granularity => WORD,
      g_slave_use_struct   => true,
      g_slave_mode         => g_slave2_interface_mode,
      g_slave_granularity  => g_slave2_granularity)
    port map (
      clk_sys_i => clk_slave2_i,
      rst_n_i   => rst_n_i,
      slave_i   => slave2_i,
      slave_o   => slave2_o,
      master_i  => slave2_out,
      master_o  => slave2_in);

  U_DPRAM_MIX : generic_dpram_mixed
    generic map(
       g_data_a_width              => g_dpram_port_a_width,
       g_data_b_width              => g_dpram_port_b_width,
       g_size                      => g_size,
       g_addr_conflict_resolution  => "dont_care",
       g_init_file                 => g_init_file,
       g_dual_clock                => true)
    port map(
       rst_n_i => rst_n_i,
       clka_i  => clk_slave1_i,
       bwea_i  => s_bwea((g_dpram_port_a_width+7)/8-1 downto 0),
       wea_i   => s_wea,
       aa_i    => slave1_in.adr(f_log2_size(g_size)-1 downto 0),
       da_i    => slave1_in.dat(g_dpram_port_a_width-1 downto 0),
       qa_o    => slave1_out_dat(g_dpram_port_a_width-1 downto 0),

       clkb_i  => clk_slave2_i,    
       bweb_i  => s_bweb((g_dpram_port_b_width+7)/8-1 downto 0),
       web_i   => s_web,
       ab_i    => slave2_in.adr(f_log2_size(g_size*g_dpram_port_a_width/g_dpram_port_b_width)-1 downto 0),
       db_i    => slave2_in.dat(g_dpram_port_b_width-1 downto 0),
       qb_o    => slave2_out.dat(g_dpram_port_b_width-1 downto 0));

  swap_word_endianness_y : if g_swap_word_endianness generate
    slave1_out.dat <= f_swap_word(slave1_out_dat);
  end generate;

  swap_word_endianness_n : if not g_swap_word_endianness generate
    slave1_out.dat <= slave1_out_dat;
  end generate;
    
  -- I know this looks weird, but otherwise ISE generates distributed RAM instead of block
  -- RAM
  s_bwea <= slave1_in.sel when s_wea = '1' else f_zeros(c_wishbone_data_width/8);
  s_bweb <= slave2_in.sel when s_web = '1' else f_zeros(c_wishbone_data_width/8);

  s_wea <= slave1_in.we and slave1_in.stb and slave1_in.cyc;
  s_web <= slave2_in.we and slave2_in.stb and slave2_in.cyc;

  process(clk_sys_i)
  begin
    if(rising_edge(clk_sys_i)) then
      if(rst_n_i = '0') then
        slave1_out.ack <= '0';
      else
        if(slave1_out.ack = '1' and g_slave1_interface_mode = CLASSIC) then
          slave1_out.ack <= '0';
        else
          slave1_out.ack <= slave1_in.cyc and slave1_in.stb;
        end if;
       end if;
    end if;
  end process;
 
  process(clk_slave2_i)
  begin
    if(rising_edge(clk_slave2_i)) then
      if(rst_n_i = '0') then
        slave2_out.ack <= '0';
      else
        if(slave2_out.ack = '1' and g_slave2_interface_mode = CLASSIC) then
          slave2_out.ack <= '0';
        else
          slave2_out.ack <= slave2_in.cyc and slave2_in.stb;
        end if;
      end if;
    end if;
  end process;

  slave1_out.stall <= '0';
  slave2_out.stall <= '0';
  slave1_out.err <= '0';
  slave2_out.err <= '0';
  slave1_out.rty <= '0';
  slave2_out.rty <= '0';
  
end struct;

