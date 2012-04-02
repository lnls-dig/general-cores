-------------------------------------------------------------------------------
-- Title      : Parametrizable dual-port synchronous RAM (Altera version)
-- Project    : Generics RAMs and FIFOs collection
-------------------------------------------------------------------------------
-- File       : generic_dpram.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2011-01-25
-- Last update: 2012-01-20
-- Platform   : 
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: True dual-port synchronous RAM for Altera FPGAs with:
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
-- 2012-03-13  1.1      wterpstra       Added initial value as array
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.genram_pkg.all;
use work.memory_loader_pkg.all;

entity generic_dpram is

  generic (
    -- standard parameters
    g_data_width               : natural;
    g_size                     : natural;
    g_with_byte_enable         : boolean := false;
    g_addr_conflict_resolution : string := "read_first";
    g_init_file                : string := "";
    g_init_value               : t_generic_ram_init := c_generic_ram_nothing;
    g_dual_clock               : boolean := true;
    g_fail_if_file_not_found : boolean := true
    );

  port (
    rst_n_i : in std_logic := '1';      -- synchronous reset, active LO

    -- Port A
    clka_i : in  std_logic;
    bwea_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
    wea_i  : in  std_logic;
    aa_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    da_i   : in  std_logic_vector(g_data_width-1 downto 0);
    qa_o   : out std_logic_vector(g_data_width-1 downto 0);
    -- Port B

    clkb_i : in  std_logic;
    bweb_i : in  std_logic_vector((g_data_width+7)/8-1 downto 0);
    web_i  : in  std_logic;
    ab_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    db_i   : in  std_logic_vector(g_data_width-1 downto 0);
    qb_o   : out std_logic_vector(g_data_width-1 downto 0)
    );

end generic_dpram;

architecture syn of generic_dpram is

  constant c_num_bytes : integer := g_data_width/8;

  type t_ram_type is array(0 to g_size-1) of std_logic_vector(g_data_width-1 downto 0);
  type t_ram_word_bs is array (0 to 7) of std_logic_vector(7 downto 0);
  type t_ram_type_bs is array (0 to g_size - 1) of t_ram_word_bs;

  function f_memarray_to_ramtype(arr : t_meminit_array) return t_ram_type is
    variable tmp    : t_ram_type;
    variable n, pos : integer;
  begin
    pos := 0;
    while(pos < g_size)loop
      n := 0;
      -- avoid ISE loop iteration limit
      while (pos < g_size and n < 4096) loop
        for i in 0 to g_data_width-1 loop
          tmp(pos)(i) := arr(pos, i);
        end loop;  -- i
        n := n+1;
        pos := pos + 1;
      end loop;
      pos := pos + 1;
    end loop;
    return tmp;
  end f_memarray_to_ramtype;

  function f_memarray_to_ramtype_bs(arr : t_meminit_array) return t_ram_type_bs is
    variable tmp    : t_ram_type_bs;
    variable n, pos : integer;
  begin
    pos := 0;
    while(pos < g_size)loop
      n := 0;
      -- avoid ISE loop iteration limit
      while (pos < g_size and n < 4096) loop
        for i in 0 to g_data_width-1 loop
          tmp(pos)(i/8)(i mod 8) := arr(pos, i);
        end loop;  -- i
        n := n+1;
        pos := pos + 1;
      end loop;
      pos := pos + 1;
    end loop;
    return tmp;
  end f_memarray_to_ramtype_bs;

  function f_file_contents return t_meminit_array is
  begin
    if g_init_value'length > 0 then
      return g_init_value;
    else
      return f_load_mem_from_file(g_init_file, g_size, g_data_width, g_fail_if_file_not_found);
    end if;
  end f_file_contents;
  
  shared variable ram : t_ram_type := f_memarray_to_ramtype(f_file_contents);
  shared variable ram_bs : t_ram_type_bs:=f_memarray_to_ramtype_bs(f_file_contents);
  
  signal q_local_a       : t_ram_word_bs;
  signal q_local_b       : t_ram_word_bs;

  signal bwe_int_a : std_logic_vector(7 downto 0);
  signal bwe_int_b : std_logic_vector(7 downto 0);

  signal clka_int : std_logic;
  signal clkb_int : std_logic;
  
begin
  assert (g_addr_conflict_resolution = "read_first")
    report "generic_dpram: Altera template supports only read-first mode." severity failure;
  assert (((g_data_width / 8) * 8) = g_data_width) or (g_with_byte_enable = false)
    report "generic_dpram: in byte-enabled mode the data width must be a multiple of 8" severity failure;
  assert(g_data_width <= 64 or g_with_byte_enable = false)
    report "generic_dpram: byte-selectable memories can be have 64-bit data width due to synthesis tool limitation" severity failure;



  --gen_single_clock : if(g_dual_clock = false) generate
  --  clka_int <= clka_i  after 1ns;
  --  clkb_int <= clka_i  after 1ns;
  --end generate gen_single_clock;

  --gen_dual_clock : if(g_dual_clock = true) generate
  --  clka_int <= clka_i  after 1ns;
  --  clkb_int <= clkb_i after 1ns;
  --end generate gen_dual_clock;



  gen_with_byte_enable : if(g_with_byte_enable = true) generate
  bwe_int_a <= std_logic_vector(to_unsigned(0, 8-bwea_i'length)) & bwea_i;
  bwe_int_b <= std_logic_vector(to_unsigned(0, 8-bweb_i'length)) & bweb_i;

    unpack : for i in 0 to c_num_bytes - 1 generate
      qa_o(8*(i+1) - 1 downto 8*i) <= q_local_a(i);
      qb_o(8*(i+1) - 1 downto 8*i) <= q_local_b(i);
    end generate unpack;

    process(clka_i)
    begin
      if(rising_edge(clka_i)) then
        if(wea_i = '1') then

-- I know the code below is stupid, but it's the only way to make Quartus
-- recongnize it as a memory block
          if(bwe_int_a(0) = '1' and g_data_width >= 8) then
            ram_bs(to_integer(unsigned(aa_i)))(0) := da_i(7 downto 0);
          end if;
          if(bwe_int_a(1) = '1' and g_data_width >= 16) then
            ram_bs(to_integer(unsigned(aa_i)))(1) := da_i(15 downto 8);
          end if;
          if(bwe_int_a(2) = '1' and g_data_width >= 24) then
            ram_bs(to_integer(unsigned(aa_i)))(2) := da_i(23 downto 16);
          end if;
          if(bwe_int_a(3) = '1' and g_data_width >= 32) then
            ram_bs(to_integer(unsigned(aa_i)))(3) := da_i(31 downto 24);
          end if;
          if(bwe_int_a(4) = '1' and g_data_width >= 40) then
            ram_bs(to_integer(unsigned(aa_i)))(4) := da_i(39 downto 32);
          end if;
          if(bwe_int_a(5) = '1' and g_data_width >= 48) then
            ram_bs(to_integer(unsigned(aa_i)))(5) := da_i(47 downto 40);
          end if;
          if(bwe_int_a(6) = '1' and g_data_width >= 56) then
            ram_bs(to_integer(unsigned(aa_i)))(6) := da_i(55 downto 48);
          end if;
          if(bwe_int_a(7) = '1' and g_data_width = 64) then
            ram_bs(to_integer(unsigned(aa_i)))(7) := da_i(64 downto 57);
          end if;
        end if;
        q_local_a <= ram_bs(to_integer(unsigned(aa_i)));
      end if;
    end process;

    process(clkb_i)
    begin
      if(rising_edge(clkb_i)) then
        if(web_i = '1') then

-- I know the code below is stupid, but it's the only way to make Quartus
-- recongnize it as a memory block
          if(bwe_int_b(0) = '1' and g_data_width >= 8) then
            ram_bs(to_integer(unsigned(ab_i)))(0) := db_i(7 downto 0);
          end if;
          if(bwe_int_b(1) = '1' and g_data_width >= 16) then
            ram_bs(to_integer(unsigned(ab_i)))(1) := db_i(15 downto 8);
          end if;
          if(bwe_int_b(2) = '1' and g_data_width >= 24) then
            ram_bs(to_integer(unsigned(ab_i)))(2) := db_i(23 downto 16);
          end if;
          if(bwe_int_b(3) = '1' and g_data_width >= 32) then
            ram_bs(to_integer(unsigned(ab_i)))(3) := db_i(31 downto 24);
          end if;
          if(bwe_int_b(4) = '1' and g_data_width >= 40) then
            ram_bs(to_integer(unsigned(ab_i)))(4) := db_i(39 downto 32);
          end if;
          if(bwe_int_b(5) = '1' and g_data_width >= 48) then
            ram_bs(to_integer(unsigned(ab_i)))(5) := db_i(47 downto 40);
          end if;
          if(bwe_int_b(6) = '1' and g_data_width >= 56) then
            ram_bs(to_integer(unsigned(ab_i)))(6) := db_i(55 downto 48);
          end if;
          if(bwe_int_b(7) = '1' and g_data_width = 64) then
            ram_bs(to_integer(unsigned(ab_i)))(7) := db_i(64 downto 57);
          end if;
        end if;
        q_local_b <= ram_bs(to_integer(unsigned(ab_i)));
      end if;
    end process;


  end generate gen_with_byte_enable;


  gen_without_byte_enable_readfirst : if(g_with_byte_enable = false) generate
    process(clka_i)
    begin
      if rising_edge(clka_i) then
        if(wea_i = '1') then
          ram(to_integer(unsigned(aa_i))) := da_i;
        end if;
        qa_o <= ram(to_integer(unsigned(aa_i)));
      end if;
    end process;

    process(clkb_i)
    begin
      if rising_edge(clkb_i) then
        if(web_i = '1') then
          ram(to_integer(unsigned(ab_i))) := db_i;
        end if;
        qb_o <= ram(to_integer(unsigned(ab_i)));
      end if;
    end process;
  end generate gen_without_byte_enable_readfirst;
  

end syn;
