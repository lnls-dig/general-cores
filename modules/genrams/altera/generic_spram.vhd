-------------------------------------------------------------------------------
-- Title      : Parametrizable single-port synchronous RAM (Altera version)
-- Project    : Generics RAMs and FIFOs collection
-------------------------------------------------------------------------------
-- File       : generic_spram.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-Co-HT
-- Created    : 2011-01-25
-- Last update: 2011-01-25
-- Platform   : 
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Single-port synchronous RAM for Altera FPGAs with:
-- - configurable address and data bus width
-- - byte-addressing mode (data bus width restricted to multiple of 8 bits)
-- Todo:
-- - loading initial contents from file
-------------------------------------------------------------------------------
-- Copyright (c) 2011 CERN
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-01-25  1.0      twlostow        Created
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.genram_pkg.all;

entity generic_spram is

  generic (
    -- standard parameters
    g_data_width               : natural := 32;
    g_size                     : natural := 1024;
    g_with_byte_enable         : boolean := false;
    g_addr_conflict_resolution : string  := "read_first";
    g_init_file                : string  := ""
    );

  port (
    rst_n_i : in std_logic := '1';      -- synchronous reset, active LO
    clk_i   : in std_logic;             -- clock input

    -- byte write enable, actiwe when g_with_byte_enable == true
    bwe_i : in std_logic_vector((g_data_width+7)/8-1 downto 0);

    -- global write enable (masked by bwe_i if g_with_byte_enable = true)
    we_i : in std_logic;

    -- address input
    a_i : in std_logic_vector(f_log2_size(g_size)-1 downto 0);

    -- data input
    d_i : in std_logic_vector(g_data_width-1 downto 0);

    -- data output
    q_o : out std_logic_vector(g_data_width-1 downto 0)
    );

end generic_spram;



architecture syn of generic_spram is


  constant c_num_bytes : integer := g_data_width/8;

  type t_ram_type is array(0 to g_size-1) of std_logic_vector(g_data_width-1 downto 0);
  type t_ram_word_bs is array (0 to 7) of std_logic_vector(7 downto 0);
  type t_ram_type_bs is array (0 to g_size - 1) of t_ram_word_bs;

  signal ram     : t_ram_type;
  signal ram_bs  : t_ram_type_bs;
  signal q_local : t_ram_word_bs;

  signal bwe_int : std_logic_vector(7 downto 0);
  
begin
  assert (g_init_file = "") report "generic_spram: Memory initialization files not supported yet. Sorry :(" severity failure;
  assert (g_addr_conflict_resolution = "read_first") report "generic_spram: Altera template supports only read-first mode." severity failure;
  assert (((g_data_width / 8) * 8) = g_data_width) or (g_with_byte_enable = false) report "generic_spram: in byte-enabled mode the data width must be a multiple of 8" severity failure;
  assert(g_data_width <= 64 or g_with_byte_enable = false) report "generic_spram: byte-selectable memories can be have 64-bit data width due to synthesis tool limitation" severity failure;

  bwe_int <= std_logic_vector(to_unsigned(0, 8-bwe_i'length)) & bwe_i;


  gen_with_byte_enable : if(g_with_byte_enable = true) generate

    unpack : for i in 0 to c_num_bytes - 1 generate
      q_o(8*(i+1) - 1 downto 8*i) <= q_local(i);
    end generate unpack;

    process(clk_i)
    begin
      if(rising_edge(clk_i)) then
        if(we_i = '1') then

-- I know the code below is stupid, but it's the only way to make Quartus
-- recongnize it as a memory block
          if(bwe_int(0) = '1' and g_data_width >= 8) then
            ram_bs(to_integer(unsigned(a_i)))(0) <= d_i(7 downto 0);
          end if;
          if(bwe_int(1) = '1' and g_data_width >= 16) then
            ram_bs(to_integer(unsigned(a_i)))(1) <= d_i(15 downto 8);
          end if;
          if(bwe_int(2) = '1' and g_data_width >= 24) then
            ram_bs(to_integer(unsigned(a_i)))(2) <= d_i(23 downto 16);
          end if;
          if(bwe_int(3) = '1' and g_data_width >= 32) then
            ram_bs(to_integer(unsigned(a_i)))(3) <= d_i(31 downto 24);
          end if;
          if(bwe_int(4) = '1' and g_data_width >= 40) then
            ram_bs(to_integer(unsigned(a_i)))(4) <= d_i(39 downto 32);
          end if;
          if(bwe_int(5) = '1' and g_data_width >= 48) then
            ram_bs(to_integer(unsigned(a_i)))(5) <= d_i(47 downto 40);
          end if;
          if(bwe_int(6) = '1' and g_data_width >= 56) then
            ram_bs(to_integer(unsigned(a_i)))(6) <= d_i(55 downto 48);
          end if;
          if(bwe_int(7) = '1' and g_data_width >= 64) then
            ram_bs(to_integer(unsigned(a_i)))(7) <= d_i(64 downto 57);
          end if;


        end if;
        q_local <= ram_bs(to_integer(unsigned(a_i)));
      end if;
    end process;
  end generate gen_with_byte_enable;


  gen_without_byte_enable_readfirst : if(g_with_byte_enable = false) generate
    process(clk_i)
    begin
      if rising_edge(clk_i) then
        if(we_i = '1') then
          ram(to_integer(unsigned(a_i))) <= d_i;
        end if;
        q_o <= ram(to_integer(unsigned(a_i)));
      end if;
    end process;
  end generate gen_without_byte_enable_readfirst;
  

end syn;
