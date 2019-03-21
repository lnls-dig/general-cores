-------------------------------------------------------------------------------
-- Title      : Parametrizable synchronous ROM (Xilinx version)
-------------------------------------------------------------------------------
-- Author     : Lucas Russo
-- Created    : 2017-01-25
-- Last update: 2017-01-25
-- Platform   : FPGA-generic
-- Standard   : VHDL'93
-------------------------------------------------------------------------------
-- Description: Simple synchronous ROM
-------------------------------------------------------------------------------
-- Copyright (c) 2017 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2017-01-25  1.0      lucas.russo       Created
-------------------------------------------------------------------------------

-- Based on generic_spram.vhd file

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library work;
use work.genram_pkg.all;
use work.memory_loader_pkg.all;

entity generic_rom is
  generic (
    g_data_width : natural := 32;
    g_size       : natural := 16384;

    g_init_file                : string  := "";
    g_fail_if_file_not_found   : boolean := true
  );
  port (
    rst_n_i : in std_logic;             -- synchronous reset, active LO
    clk_i   : in std_logic;             -- clock input

    -- address input
    a_i : in std_logic_vector(f_log2_size(g_size)-1 downto 0);
    -- data output
    q_o : out std_logic_vector(g_data_width-1 downto 0)
  );
end generic_rom;

architecture syn of generic_rom is

  constant c_num_bytes : integer := (g_data_width+7)/8;

  type t_ram_type is array(0 to g_size-1) of std_logic_vector(g_data_width-1 downto 0);

  impure function f_memarray_to_ramtype(mem_size : integer; mem_width : integer) return t_ram_type is
    variable tmp    : t_ram_type;
    variable arr    : t_meminit_array(0 to mem_size-1, mem_width-1 downto 0);
    variable n, pos : integer;
  begin
    if(g_init_file = "" or g_init_file = "none") then
      for i in 0 to g_size-1 loop
        tmp(i)(g_data_width-1 downto 0) := (others =>'0');
      end loop;
    return tmp;
    end if;

    arr := f_load_mem_from_file(g_init_file, mem_size, mem_width, g_fail_if_file_not_found);

    pos := 0;
    while(pos < g_size)loop
      n := 0;
      -- avoid ISE loop iteration limit
      while (pos < g_size and n < 4096) loop
        for i in 0 to g_data_width-1 loop
          tmp(pos)(i) := arr(pos, i);
        end loop;  -- i
        n   := n+1;
        pos := pos + 1;
      end loop;
    end loop;
    return tmp;
  end f_memarray_to_ramtype;

  function f_is_synthesis return boolean is
  begin
    -- synthesis translate_off
    return false;
    -- synthesis translate_on
    return true;
  end f_is_synthesis;

  shared variable ram : t_ram_type := f_memarray_to_ramtype(g_size, g_data_width);
begin

    process(clk_i)
    begin
      if rising_edge(clk_i) then
        if f_is_synthesis then
          q_o <= ram(to_integer(unsigned(a_i)));
        else
          q_o <= ram(to_integer(unsigned(a_i)) mod g_size);
        end if;
      end if;
    end process;

end syn;
