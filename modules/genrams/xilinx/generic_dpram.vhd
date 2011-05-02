-------------------------------------------------------------------------------
-- Title      : Parametrizable dual-port synchronous RAM (Xilinx version)
-- Project    : Generics RAMs and FIFOs collection
-------------------------------------------------------------------------------
-- File       : generic_dpram.vhd
-- Author     : Tomasz Wlostowski
-- Company    : CERN BE-CO-HT
-- Created    : 2011-01-25
-- Last update: 2011-04-10
-- Platform   : 
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: True dual-port synchronous RAM for Xilinx FPGAs with:
-- - configurable address and data bus width
-- - byte-addressing mode (data bus width restricted to multiple of 8 bits)
-- Todo:
-- - loading initial contents from file
-- - add support for read-first/write-first address conflict resulution (only
--   supported by Xilinx in VHDL templates)
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
use std.textio.all;

library work;
use work.genram_pkg.all;

entity generic_dpram is

  generic (
    -- standard parameters
--G    g_data_width               : natural;
--G    g_size                     : natural;
    g_data_width : natural := 32;
    g_size       : natural := 16384;

    g_with_byte_enable         : boolean := false;
    g_addr_conflict_resolution : string  := "read_first";
    g_init_file                : string  := "/home/grzegorz/tst_sw/hello.ram";
    g_dual_clock               : boolean := true
    );

  port (
    rst_n_i : in std_logic := '1';      -- synchronous reset, active LO

    -- Port A
    clka_i : in  std_logic;
    bwea_i : in  std_logic_vector(g_data_width/8-1 downto 0);
    wea_i  : in  std_logic;
    aa_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    da_i   : in  std_logic_vector(g_data_width-1 downto 0);
    qa_o   : out std_logic_vector(g_data_width-1 downto 0);
    -- Port B

    clkb_i : in  std_logic;
    bweb_i : in  std_logic_vector(g_data_width/8-1 downto 0);
    web_i  : in  std_logic;
    ab_i   : in  std_logic_vector(f_log2_size(g_size)-1 downto 0);
    db_i   : in  std_logic_vector(g_data_width-1 downto 0);
    qb_o   : out std_logic_vector(g_data_width-1 downto 0)
    );

end generic_dpram;



architecture syn of generic_dpram is
  

  constant c_num_bytes : integer := g_data_width/8;

  type t_ram_type is array(0 to g_size-1) of std_logic_vector(g_data_width-1 downto 0);
  type t_string_file_type is file of string;
  type t_bin_file_type is file of integer;

  -- Function reads binary file and place the data in a std_logic_vector
  -- Takes parameters
  --   filename : Name of the file from which to read data

  impure function read_meminit_file(
    filename : string
    ) return t_ram_type is                                                                    
    file meminitfile   : text;
    variable init_line : line;
    variable char      : character;
    variable index     : integer;
    variable word      : integer;
    variable word_temp : std_logic_vector(31 downto 0);
    variable i, j      : integer;
    variable stop      : boolean;
    variable mem       : t_ram_type;

  begin
    if(g_init_file = "") then
      mem := (others => (others => '0'));
      return mem;
    end if;

    file_open(meminitfile, filename, read_mode);
    j    := 0;
    stop := false;
    while(j < 4) loop
      i := 0;
      while(i < 4096) loop
        if(stop = false) then
          
          
          readline(meminitfile, init_line);

          read(init_line, char);
          while(char /= '=') loop
            read(init_line, char);
          end loop;
          read(init_line, char);        -- '>'
          read(init_line, char);        -- ' '
          read(init_line, char);        -- 'x'
          read(init_line, char);        -- '"'


          for index in 7 downto 0 loop
            read(init_line, char);
            report "char: " & char severity warning;

            case char is
              when '0'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "0000";
              when '1'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "0001";
              when '2'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "0010";
              when '3'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "0011";
              when '4'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "0100";
              when '5'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "0101";
              when '6'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "0110";
              when '7'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "0111";
              when '8'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1000";
              when '9'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1001";
              when 'a'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1010";
              when 'A'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1010";
              when 'b'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1011";
              when 'B'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1011";
              when 'c'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1100";
              when 'C'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1100";
              when 'd'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1101";
              when 'D'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1101";
              when 'e'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1110";
              when 'E'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1110";
              when 'f'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1111";
              when 'F'    => mem(j*4096+i)((index+1)*4-1 downto index*4) := "1111";
              when others => mem(j*4096+i)((index+1)*4-1 downto index*4) := "XXXX";
            end case;
          end loop;
        else
          mem(j*4096+i) := (others => '0');
        end if;

        i := i+1;
        if(endfile(meminitfile)) then
          stop := true;
        end if;
      end loop;
      j := j+1;
    end loop;
    file_close(meminitfile);

    return mem;
  end read_meminit_file;

  shared variable ram : t_ram_type := read_meminit_file(g_init_file);

  signal s_we_a     : std_logic_vector(c_num_bytes-1 downto 0);
  signal s_ram_in_a : std_logic_vector(g_data_width-1 downto 0);
  signal s_we_b     : std_logic_vector(c_num_bytes-1 downto 0);
  signal s_ram_in_b : std_logic_vector(g_data_width-1 downto 0);

  signal clka_int : std_logic;
  signal clkb_int : std_logic;

  signal wea_rep, web_rep : std_logic_vector(c_num_bytes-1 downto 0);
  
  
begin

  gen_single_clock : if(g_dual_clock = false) generate
    clka_int <= clka_i after 1ns;
    clkb_int <= clka_i after 1ns;
  end generate gen_single_clock;

  gen_dual_clock : if(g_dual_clock = true) generate
    clka_int <= clka_i after 1ns;
    clkb_int <= clkb_i after 1ns;
  end generate gen_dual_clock;

  wea_rep <= (others => wea_i);
  web_rep <= (others => web_i);

  s_we_a <= bwea_i;
  s_we_b <= bweb_i;

  gen_with_byte_enable_readfirst : if(g_with_byte_enable = true and g_addr_conflict_resolution = "read_first") generate


    process (clka_int)
    begin
      if rising_edge(clka_int) then
        qa_o <= ram(to_integer(unsigned(aa_i)));
        for i in 0 to c_num_bytes-1 loop
          if s_we_a(i) = '1' then
            ram(to_integer(unsigned(aa_i)))((i+1)*8-1 downto i*8) := da_i((i+1)*8-1 downto i*8);
          end if;
        end loop;
      end if;
    end process;


    process (clkb_int)
    begin
      if rising_edge(clkb_int) then
        qb_o <= ram(to_integer(unsigned(ab_i)));
        for i in 0 to c_num_bytes-1 loop
          if s_we_b(i) = '1' then
            ram(to_integer(unsigned(ab_i)))((i+1)*8-1 downto i*8)
              := db_i((i+1)*8-1 downto i*8);
          end if;
        end loop;
      end if;
    end process;
    



  end generate gen_with_byte_enable_readfirst;



  gen_without_byte_enable_readfirst : if(g_with_byte_enable = false and g_addr_conflict_resolution = "read_first") generate

    process(clka_int)
    begin
      if rising_edge(clka_int) then
        qa_o <= ram(to_integer(unsigned(aa_i)));
        if(wea_i = '1') then
          ram(to_integer(unsigned(aa_i))) := da_i;
        end if;
      end if;
    end process;


    process(clkb_int)
    begin
      if rising_edge(clkb_int) then
        qb_o <= ram(to_integer(unsigned(ab_i)));
        if(web_i = '1') then
          ram(to_integer(unsigned(ab_i))) := db_i;
        end if;
      end if;
    end process;

  end generate gen_without_byte_enable_readfirst;


  gen_without_byte_enable_writefirst : if(g_with_byte_enable = false and g_addr_conflict_resolution = "write_first") generate

    process(clka_int)
    begin
      if rising_edge(clka_int) then
        if(wea_i = '1') then
          ram(to_integer(unsigned(aa_i))) := da_i;
          qa_o                            <= da_i;
        else
          qa_o <= ram(to_integer(unsigned(aa_i)));
        end if;
      end if;
    end process;


    process(clkb_int)
    begin
      if rising_edge(clkb_int) then
        if(web_i = '1') then
          ram(to_integer(unsigned(ab_i))) := db_i;
          qb_o                            <= db_i;
        else
          qb_o <= ram(to_integer(unsigned(ab_i)));
        end if;
      end if;
    end process;
  end generate gen_without_byte_enable_writefirst;
  

end syn;
