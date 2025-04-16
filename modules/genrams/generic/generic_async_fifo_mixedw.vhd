
--------------------------------------------------------------------------------
-- CERN BE-CO-HT
-- General Cores Library
-- https://gitlab.com/ohwr/project/general-cores
--------------------------------------------------------------------------------
--
-- unit name:   generic_async_fifo
--
-- description: Parametrizable asynchronous FIFO (Generic version).
-- Dual-clock asynchronous FIFO.
-- - configurable ports width and size
--
-- In case of different width, the fifo will unpack in little-endian mode
-- (so if the read port is smaller than the write port, the first output
--  will be the least significant bits of the first input).
-- The fifo will pack in little-endian mode (so if the read port is larger
-- than the write port, the first input will appear on the least significant
-- bits of the first output).
--
-- TODO: synchronous reset: add new ports (unused reset will be optimized)
-- TODO: same clock: add a generic to simplify the design.
--------------------------------------------------------------------------------
-- Copyright CERN 2011-2023
--------------------------------------------------------------------------------
-- Copyright and related rights are licensed under the Solderpad Hardware
-- License, Version 2.0 (the "License"); you may not use this file except
-- in compliance with the License. You may obtain a copy of the License at
-- http://solderpad.org/licenses/SHL-2.0.
-- Unless required by applicable law or agreed to in writing, software,
-- hardware and materials distributed under this License is distributed on an
-- "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
-- or implied. See the License for the specific language governing permissions
-- and limitations under the License.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.gencores_pkg.all;
use work.genram_pkg.all;

entity generic_async_fifo_mixedw is
  generic (
    --  Width of the write port.  The ratio between the rd and wr port
    --  width must be a power of two.
    g_wr_width   : natural;
    --  Width of the read port.
    g_rd_width   : natural;
    --  Number of entries (whose width is the max between rd and wr ports)
    g_size       : natural;
    --  If true, the rd port outputs the current valid data (if the fifo is
    --  not empty), and rd_i acts as acknowledge.
    --  If false, rd_i acts as a request.
    g_show_ahead : boolean := false;

    g_memory_implementation_hint : string  := "auto"
  );
  port (
    --  Asynchronous reset
    rst_n_a_i  : in  std_logic := '1';

    -- write port
    clk_wr_i   : in  std_logic;
    d_i        : in  std_logic_vector(g_wr_width-1 downto 0);
    we_i       : in  std_logic;

    wr_full_o  : out std_logic;
    wr_count_o : out std_logic_vector(f_log2_size(g_size * ((g_rd_width + g_wr_width - 1) / g_wr_width)) downto 0);

    -- read port
    clk_rd_i   : in  std_logic;
    q_o        : out std_logic_vector(g_rd_width-1 downto 0);
    rd_i       : in  std_logic;

    rd_empty_o : out std_logic;
    rd_count_o : out std_logic_vector(f_log2_size(g_size * ((g_rd_width + g_wr_width - 1) / g_rd_width)) downto 0)
  );
end generic_async_fifo_mixedw;

architecture syn of generic_async_fifo_mixedw is
  --  Extra number of bits in counters due to the width difference.
  --  The largest port has 0 extra bits.
  constant c_extra_rd_width_bits : natural := f_log2((g_rd_width + g_wr_width - 1) / g_rd_width);
  constant c_extra_wr_width_bits : natural := f_log2((g_rd_width + g_wr_width - 1) / g_wr_width);

  -- We use one more bit to be able to differentiate between an empty FIFO
  -- (where rcb = wcb) and a full FIFO (where rcb = wcb except from the most
  -- significant extra bit).
  -- This extra bit is not used of course for actual addressing of the memory.
  constant c_rd_counter_bits : integer := f_log2_size(g_size) + c_extra_rd_width_bits + 1;
  constant c_wr_counter_bits : integer := f_log2_size(g_size) + c_extra_wr_width_bits + 1;

  subtype t_rd_counter is std_logic_vector(c_rd_counter_bits-1 downto 0);
  subtype t_wr_counter is std_logic_vector(c_wr_counter_bits-1 downto 0);

  -- bin: binary counter
  -- bin_inc: bin + 1
  -- n_bin: combinatorial next value of bin (either bin or bin_inc)
  -- bin_x: cross-clock domain version of bin
  -- gray: gray code of bin
  -- gray_inc: gray code of bin_inc
  -- n_gray: combinatorial next value of gray (either gray or gray_inc)
  -- gray_x: gray code of bin_x
  --
  -- We use gray codes for safe cross-clock domain crossing of counters. Thus,
  -- a binary counter is converted to gray before crossing, and then it is
  -- converted back to binary after crossing.
  type t_rd_counter_block is record
    bin, bin_inc, n_bin   : t_rd_counter;
    gray, gray_inc, n_gray : t_rd_counter;
    bin_x, gray_x   : t_rd_counter;
  end record;

  type t_wr_counter_block is record
    bin, bin_inc, n_bin   : t_wr_counter;
    gray, gray_inc, n_gray : t_wr_counter;
    bin_x, gray_x   : t_wr_counter;
  end record;

  constant c_max_width : natural := f_max(g_rd_width, g_wr_width);

  --  The internal memory
  type t_mem_type is array (0 to g_size-1) of std_logic_vector(c_max_width-1 downto 0);
  signal mem : t_mem_type := (others => (others => '0'));

  attribute ram_type : string;
  attribute ram_type of mem : signal is g_memory_implementation_hint;

  signal rcb : t_rd_counter_block;
  signal wcb : t_wr_counter_block;

  signal full_int, empty_int : std_logic;

  signal rd_count : std_logic_vector(c_rd_counter_bits + c_extra_wr_width_bits - 1 downto 0);
  signal wr_count : std_logic_vector(c_wr_counter_bits + c_extra_rd_width_bits - 1 downto 0);
  signal rd_int, we_int : std_logic;

  signal q_int : std_logic_vector(c_max_width-1 downto 0);

  signal buf_in  : std_logic_vector(c_max_width - 1 downto 0);
  signal rd_addr : unsigned(rcb.bin_inc'LEFT-1 downto 0);

begin
  --  Protect against overflow and underflow.
  rd_int <= rd_i and not empty_int;
  we_int <= we_i and not full_int;

  buf_in (c_max_width - 1 downto c_max_width - g_wr_width) <= d_i;

  p_mem_write : process(clk_wr_i)
  begin
    if rising_edge(clk_wr_i) then
      if we_int = '1' then
        mem(to_integer(unsigned(wcb.bin(wcb.bin'LEFT-1 downto c_extra_wr_width_bits)))) <= buf_in;
      end if;
    end if;
  end process p_mem_write;

  g_write_buf_in: if c_extra_wr_width_bits > 0 generate
    process (clk_wr_i)
    begin
      if rising_edge(clk_wr_i) and we_int = '1' then
        buf_in(c_max_width - g_wr_width - 1 downto 0) <= buf_in(c_max_width - 1 downto g_wr_width);
      end if;
    end process;
  end generate;

  p_read_addr: process (rd_int, rcb)
  begin
    --  In show ahead mode, the output is valid (unless the fifo is empty), and 'rd'
    --  ack the current value.
    --  In no show ahead mode, the output is not valid, and 'rd' will output the value
    --  on the next cycle.
    if(rd_int = '1' and g_show_ahead) then
      --  Read the next value.
      rd_addr <= unsigned(rcb.bin_inc(rcb.bin_inc'LEFT-1 downto 0));
    elsif(rd_int = '1' or g_show_ahead) then
      --  Read the current entry.
      rd_addr <= unsigned(rcb.bin(rcb.bin'LEFT-1 downto 0));
    end if;
  end process;

  p_mem_read : process(clk_rd_i)
  begin
    if rising_edge(clk_rd_i) then
      q_int <= mem(to_integer(rd_addr(rd_addr'left downto c_extra_rd_width_bits)));
    end if;
  end process p_mem_read;

  g_rd_sel: if c_extra_rd_width_bits > 0 generate
    signal rd_sel_in, rd_sel : natural range 0 to 2**c_extra_rd_width_bits-1;
  begin
    rd_sel_in <= to_integer(unsigned(rcb.bin (c_extra_rd_width_bits - 1 downto 0)));
    process(clk_rd_i, rd_sel_in)
    begin
      if g_show_ahead or rising_edge(clk_rd_i) then
        rd_sel <= rd_sel_in;
      end if;
    end process;
    q_o <= q_int(rd_sel * g_rd_width + g_rd_width - 1 downto rd_sel * g_rd_width);
  end generate;

  g_no_rd_sel: if c_extra_rd_width_bits = 0 generate
    q_o <= q_int;
  end generate;

  wcb.bin_inc  <= std_logic_vector(unsigned(wcb.bin) + 1);
  wcb.gray_inc <= f_gray_encode(wcb.bin_inc);

  wcb.n_bin <= wcb.bin_inc when we_int = '1' else wcb.bin;
  wcb.n_gray <= wcb.gray_inc when we_int = '1' else wcb.gray;

  p_write_ptr : process(clk_wr_i, rst_n_a_i)
  begin
    if rst_n_a_i = '0' then
      wcb.bin  <= (others => '0');
      wcb.gray <= (others => '0');
    elsif rising_edge(clk_wr_i) then
      wcb.bin  <= wcb.n_bin;
      wcb.gray <= wcb.n_gray;
    end if;
  end process p_write_ptr;

  rcb.bin_inc  <= std_logic_vector(unsigned(rcb.bin) + 1);
  rcb.gray_inc <= f_gray_encode(rcb.bin_inc);

  rcb.n_bin <= rcb.bin_inc when rd_int = '1' else rcb.bin;
  rcb.n_gray <= rcb.gray_inc when rd_int = '1' else rcb.gray;

  p_read_ptr : process(clk_rd_i, rst_n_a_i)
  begin
    if rst_n_a_i = '0' then
      rcb.bin  <= (others => '0');
      rcb.gray <= (others => '0');
    elsif rising_edge(clk_rd_i) then
      rcb.bin  <= rcb.n_bin;
      rcb.gray <= rcb.n_gray;
    end if;
  end process p_read_ptr;

  U_Sync1 : gc_sync_register
    generic map (
      g_width => c_rd_counter_bits)
    port map (
      clk_i     => clk_wr_i,
      rst_n_a_i => rst_n_a_i,
      d_i       => rcb.gray,
      q_o       => rcb.gray_x);

  U_Sync2 : gc_sync_register
    generic map (
      g_width => c_wr_counter_bits)
    port map (
      clk_i     => clk_rd_i,
      rst_n_a_i => rst_n_a_i,
      d_i       => wcb.gray,
      q_o       => wcb.gray_x);

  wcb.bin_x <= f_gray_decode(wcb.gray_x, 1);
  rcb.bin_x <= f_gray_decode(rcb.gray_x, 1);

  p_gen_empty : process(clk_rd_i, rst_n_a_i)
  begin
    if rst_n_a_i = '0' then
      empty_int <= '1';
    elsif rising_edge (clk_rd_i) then
      if wcb.gray_x(wcb.gray_x'left downto c_extra_wr_width_bits) = rcb.n_gray(rcb.n_gray'left downto c_extra_rd_width_bits) then
        empty_int <= '1';
      else
        empty_int <= '0';
      end if;
    end if;
  end process p_gen_empty;

  rd_empty_o <= empty_int;

  p_register_full : process(clk_wr_i, rst_n_a_i)
  begin
    if rst_n_a_i = '0' then
      full_int <= '0';
    elsif rising_edge (clk_wr_i) then
      if wcb.n_bin (wcb.bin'LEFT-1 downto c_extra_wr_width_bits) = rcb.bin_x(rcb.bin_x'LEFT-1 downto c_extra_rd_width_bits)
        and wcb.n_bin(wcb.bin'LEFT) /= rcb.bin_x(rcb.bin_x'LEFT)
      then
        full_int <= '1';
      else
        full_int <= '0';
      end if;
    end if;
  end process p_register_full;

  wr_full_o <= full_int;

  p_wr_count : process(clk_wr_i, rst_n_a_i)
  begin
    if rst_n_a_i = '0' then
      wr_count <= (others => '0');
    elsif rising_edge(clk_wr_i) then
      wr_count <= std_logic_vector((unsigned(wcb.n_bin) & (c_extra_rd_width_bits - 1 downto 0 => '0'))
        - (unsigned(rcb.bin_x) & (c_extra_wr_width_bits - 1 downto 0 => '0')));
    end if;
  end process;

  p_rd_count : process(clk_rd_i, rst_n_a_i)
  begin
    if rst_n_a_i = '0' then
      rd_count <= (others => '0');
    elsif rising_edge(clk_rd_i) then
      rd_count <= std_logic_vector((unsigned(wcb.bin_x) & (c_extra_rd_width_bits - 1 downto 0 => '0'))
        - (unsigned(rcb.bin) & (c_extra_wr_width_bits - 1 downto 0 => '0')));
    end if;
  end process;

  wr_count_o <= wr_count(wr_count'left downto c_extra_rd_width_bits);
  rd_count_o <= rd_count(rd_count'left downto c_extra_wr_width_bits);

  end syn;
